local Debugger = require("hotswitch-hs/lib/common/Debugger")
local TimeChecker = require("hotswitch-hs/lib/common/TimeChecker")
local Model = require("hotswitch-hs/lib/model/Model")
local Options = require("hotswitch-hs/lib/common/Options")
local PanelState = require("hotswitch-hs/lib/model/PanelState")

-- local SUBSCRIPTION_TARGET = { hs.window.filter.windowAllowed, hs.window.filter.windowCreated, hs.window.filter.windowsChanged, hs.window.filter.windowTitleChanged }
-- local SUBSCRIPTION_TARGET = { hs.window.filter.hasWindow }
local SUBSCRIPTION_TARGET = { hs.window.filter.windowVisible }

local FINDER_BUNDLE_ID = "com.apple.finder"

local WindowModel = {}

WindowModel.bundleKey = function(window)
    local app = window:application()
    return app:bundleID() or ("unknown:" .. app:name())
end

local function groupByApp(windows)
    local order, groups = {}, {}
    for _, w in ipairs(windows) do
        local b = WindowModel.bundleKey(w)
        if not groups[b] then
            groups[b] = {}
            table.insert(order, b)
        end
        table.insert(groups[b], w)
    end
    local out = {}
    for _, b in ipairs(order) do
        for _, w in ipairs(groups[b]) do table.insert(out, w) end
    end
    return out
end

local function matchesQuery(window, query)
    local id = window:id()
    local haystack = PanelState.haystacks[id]
    if haystack == nil then
        haystack = (window:application():name() .. " " .. window:title()):lower()
        PanelState.haystacks[id] = haystack
    end
    for token in query:lower():gmatch("%S+") do
        if not haystack:find(token, 1, true) then return false end
    end
    return true
end

WindowModel.new = function()
    local obj = Model.new()

    obj.bundleKey = WindowModel.bundleKey
    obj.cachedOrderedWindows = nil -- rows shown in the panel (after grouping/search/maxRows)
    obj.allOrderedWindows = nil    -- all windows, most-recently-focused first
    obj.groupedWindows = nil       -- all windows after grouping, before search/maxRows
    obj.previousWindow = nil

    obj.windowFilter = nil
    obj.useAllSpaces = false
    obj.subscriptionCallback = function()
    end

    -- Subscribe once, to the right filter. Deferred to after init.lua finishes so
    -- enableAllSpaceWindows() can pick the filter first (avoids building and
    -- scanning the unused defaultCurrentSpace filter).
    obj.ensureSubscribed = function(self)
        if self.windowFilter ~= nil then return end
        self.windowFilter = self.useAllSpaces and hs.window.filter.default or hs.window.filter.defaultCurrentSpace
        if Options.showMinimized then
            -- The default filters only allow visible windows ({visible=true}), which drops
            -- minimized windows and hidden apps. Copy keeps their app rules; the app scan is
            -- shared between filters, so this costs no extra startup time.
            self.windowFilter = hs.window.filter.copy(self.windowFilter):setDefaultFilter({})
        end
        -- Workaround:
        -- This is necessaary to make it faster to get all windows.
        -- If the `subscribe` is not set, the getting windows is slow.
        self.windowFilter:subscribe(SUBSCRIPTION_TARGET, self.subscriptionCallback)
    end

    obj.init = function(self)
        self.initTimer = hs.timer.doAfter(0, function() self:ensureSubscribed() end)
    end

    obj.enableAllSpaceWindows = function(self)
        self.useAllSpaces = true
        if self.windowFilter == nil then return end
        self.windowFilter:unsubscribe(SUBSCRIPTION_TARGET, self.subscriptionCallback)
        self.windowFilter = nil
        self:ensureSubscribed()
    end

    obj.getCachedOrderedWindowsOrFetch = function(self)
        if self.cachedOrderedWindows == nil then
            self:refreshOrderedWindows()
        end
        return self.cachedOrderedWindows
    end

    obj.copyCachedOrderedWindows = function(self)
        if self.cachedOrderedWindows == nil then
            self:refreshOrderedWindows()
        end

        local copiedCachedOrderedWindows = {}
        for i = 1, #self.cachedOrderedWindows do
            table.insert(copiedCachedOrderedWindows, self.cachedOrderedWindows[i])
        end
        return copiedCachedOrderedWindows
    end

    obj.getCreatedOrderedWindows = function(self)
        self:ensureSubscribed()
        local windows = self.windowFilter:getWindows(hs.window.filter.sortByCreated)
        windows = self.removeInvalidWindows(windows)
        windows = self:removeUnusableFinderWindowsForCreatedOrderedWindows(windows)
        return windows

        -- Another way: sorting by window id
        -- local windowIdBasedOrderedWindows = self:copyCachedOrderedWindows()
        -- table.sort(windowIdBasedOrderedWindows, function(a, b)
        --     return (a:id() < b:id())
        -- end)
        -- return windowIdBasedOrderedWindows
    end

    -- Note: "hs.window.orderedWindows()" cannot get "Hammerspoon Console" window. I don't know why that.
    obj.refreshOrderedWindows = function(self)
        -- Sometimes, getting window is failed.
        self:ensureSubscribed()
        local orderedWindows = self.windowFilter:getWindows(hs.window.filter.sortByFocusedLast)

        -- Here is another way, but it's slow.
        -- local orderedWindows = hs.window.orderedWindows()

        orderedWindows = self.removeInvalidWindows(orderedWindows)
        orderedWindows = self:removeUnusableFinderWindows(orderedWindows)

        self.allOrderedWindows = orderedWindows
        self:applyView()
        return orderedWindows
    end

    -- Rebuilds the displayed rows from allOrderedWindows using the current options/panel state.
    obj.applyView = function(self)
        local windows = self.allOrderedWindows or {}
        if Options.groupByApp then
            windows = groupByApp(windows)
        end
        self.groupedWindows = windows

        -- groupByApp top level (no search): one row per app, its most recent window.
        local onePerApp = Options.groupByApp and PanelState.groupApp == nil and not PanelState.searchActive
        local seenApp = {}
        local filtered = {}
        for _, w in ipairs(windows) do
            local app = WindowModel.bundleKey(w)
            if (PanelState.groupApp == nil or app == PanelState.groupApp)
                and (not PanelState.searchActive or matchesQuery(w, PanelState.query))
                and not (onePerApp and seenApp[app]) then
                seenApp[app] = true
                table.insert(filtered, w)
            end
            if Options.maxRows and #filtered >= Options.maxRows then break end
        end
        self.cachedOrderedWindows = filtered
    end

    -- Row of the previously focused window (the quick-switch target), clamped to the list.
    obj.defaultRowPosition = function(self)
        local target = self.allOrderedWindows and self.allOrderedWindows[2]
        local rows = self.cachedOrderedWindows or {}
        if target then
            for i, w in ipairs(rows) do
                if w:id() == target:id() then return i end
            end
            local targetApp = WindowModel.bundleKey(target)
            for i, w in ipairs(rows) do
                if i > 1 and WindowModel.bundleKey(w) == targetApp then return i end
            end
        end
        return math.max(1, math.min(2, #rows))
    end

    obj.removeInvalidWindows = function(orderedWindows)
        local cleanedOrderedWindows = {}
        for i = 1, #orderedWindows do
            local window = orderedWindows[i]
            local subrole = window:subrole()
            -- AXDialog windows are never "standard" (hs.window:isStandard() is false for any
            -- non-AXStandardWindow subrole by definition), so isStandard() can't distinguish a
            -- floating tool palette (e.g. Clip Studio Paint docked panels) from a real dialog
            -- (e.g. iTerm2 Settings). Use title instead: tool palettes are typically untitled,
            -- while real dialogs/settings windows have a title.
            local isFloatingToolPanel = subrole == "AXDialog" and window:title() == ""
            if subrole ~= "AXUnknown" and subrole ~= "AXSystemDialog" and subrole ~= "" and subrole ~= "AXFloatingWindow" and not isFloatingToolPanel then
                table.insert(cleanedOrderedWindows, window)
            end
        end
        return cleanedOrderedWindows
    end

    -- windowFilter's windowVisible-subscription cache can retain stale/phantom Finder
    -- window entries (Finder doesn't always fire proper AX notifications on tab merges).
    -- A tab group itself is a single real AXWindow (its tabs are children of an internal
    -- AXTabGroup, not separate windows), so a fresh accessibility query of the app's
    -- windows gives the true, currently-correct window list. Use that instead of trying
    -- to dedup whatever the filter cache handed us.
    --
    -- Deliberately not cached: caching this (tried and verified) reintroduces the same
    -- staleness problem at a different layer. This query is scoped to a single already-
    -- identified app (not a system-wide enumeration across all apps, which is why
    -- windowFilter itself needs the subscribe() workaround), so re-querying every call
    -- is cheap enough.
    obj.getFreshFinderWindows = function()
        local app = hs.application.get(FINDER_BUNDLE_ID)
        if app == nil then
            return {}
        end

        local freshWindows = {}
        for _, window in ipairs(app:allWindows()) do
            if window:subrole() == "AXStandardWindow" then
                table.insert(freshWindows, window)
            end
        end

        -- Sort by id, not by focus/AXMain: auto-generated keys are assigned by array
        -- position (see KeyStatusModel), so this order must stay stable regardless of
        -- which Finder window currently has focus, or the same key would end up
        -- pointing at a different window every time focus changes.
        table.sort(freshWindows, function(a, b)
            return a:id() < b:id()
        end)

        return freshWindows
    end

    obj.removeUnusableFinderWindows = function(self, orderedWindows)
        local cleanedOrderedWindows = {}
        local insertedFreshFinderWindows = false
        for i = 1, #orderedWindows do
            local window = orderedWindows[i]
            local bundleID = window:application():bundleID()
            if bundleID == FINDER_BUNDLE_ID then
                if not insertedFreshFinderWindows then
                    insertedFreshFinderWindows = true
                    for _, freshWindow in ipairs(self.getFreshFinderWindows()) do
                        table.insert(cleanedOrderedWindows, freshWindow)
                    end
                end
            else
                table.insert(cleanedOrderedWindows, window)
            end
        end
        return cleanedOrderedWindows
    end

    obj.removeUnusableFinderWindowsForCreatedOrderedWindows = function(self, orderedWindows)
        return self:removeUnusableFinderWindows(orderedWindows)
    end

    obj.focusPreviousWindowForCancel = function(self)
        if self.previousWindow ~= nil then
            self:focusWindow(self.previousWindow)
        else
            self:focusWindow(self.getCachedOrderedWindowsOrFetch(self)[1])
        end
    end

    obj.focusNextWindow = function(self)
        self:focusWindow(self:refreshOrderedWindows()[2])
    end

    obj.focusPreviousWindow = function(self)
        local orderedWindows = self:refreshOrderedWindows()
        self:focusWindow(orderedWindows[#orderedWindows])
    end

    -- TODO: window:focus() don't work correctly, when a application has 2 windows and each windows are on different screen.
    obj.focusWindow = function(self, targetWindow)
        if targetWindow:isMinimized() then
            targetWindow:unminimize()
        end
        if targetWindow:application():isHidden() then
            targetWindow:application():unhide()
        end

        -- Finder: use raise() + activate(true) instead of focus(). focus() calls becomeMain()
        -- internally, which makes Finder jump to the first tab of the window's tab group
        -- instead of preserving the tab the user actually selected.
        if targetWindow:application():bundleID() == FINDER_BUNDLE_ID then
            targetWindow:raise()
            targetWindow:application():activate(true)
            return
        end

        local targetAppliation = targetWindow:application()
        local applicationMainWindow = targetAppliation:mainWindow()
        if applicationMainWindow == nil then
            -- Some windows never become AXMain, so application:mainWindow() returns nil
            -- for them. Fall back to a direct raise() + activate() instead of silently
            -- doing nothing.
            targetWindow:raise()
            targetAppliation:activate(true)
            return
        end

        local applicationVisibleWindows = targetAppliation:visibleWindows()
        if #applicationVisibleWindows == 1 then
            targetWindow:focus()
        else
            -- Workaround for Hammerspoon bug:
            -- Hammerspoon bug: window:focus() don't work correctly, when a application has 2 windows and each windows are on different screen.
            -- Issue: https://github.com/Hammerspoon/hammerspoon/issues/370
            -- Other similar window switch apps solve this problem by using a private API.
            -- Hammerspoon does not use the private API and therefore cannot solve this problem.

            -- At the point when raising a window is necessary,
            -- there can be a cachedWindows-like difference from the actual window alignment,
            -- which can lead to unnecessary raising a window when refocusing a window in multi-window applications on multi-screens.
            -- This cannot be prevented as long as it raised a window.
            -- However, this situation is very limited, so it is acceptable.

            -- Non-standard windows (e.g. Settings/Preferences panels with subrole AXDialog or AXFloating)
            -- don't respond correctly to focus() because becomeMain() causes the app to redirect focus
            -- to its main window. Use raise() + activate(true) instead to avoid this side-effect.
            -- This must be checked before the same-app/cross-app branching below: it applies
            -- regardless of which app currently has focus, not just when switching within the
            -- same app (previously this check only ran in that one branch, so focusing a dialog
            -- directly from a different app fell through to the buggy focus() path below).
            if targetWindow:subrole() ~= "AXStandardWindow" then
                targetWindow:raise()
                targetAppliation:activate(true)
                return
            end

            local cachedWindows = self.allOrderedWindows or self:getCachedOrderedWindowsOrFetch()
            local previousWindow = cachedWindows[1]

            if previousWindow:application():pid() == targetAppliation:pid() then
                if previousWindow:id() ~= targetWindow:id() then
                    -- First focus another window of the same application, then focus the target window
                    targetWindow:focus()
                    hs.timer.doAfter(0.01, function()
                        targetWindow:focus()
                    end)
                else
                    -- Find the first window on a different screen to raise
                    local targetWindowScreenId = targetWindow:screen():id()
                    local windowToRaise = nil
                    for i = 1, #cachedWindows do
                        local window = cachedWindows[i]
                        if targetAppliation:pid() ~= window:application():pid() and window:screen():id() ~= targetWindowScreenId then
                            windowToRaise = window
                            break
                        end
                    end
                
                    -- First focus another window of the same application, then focus the target window
                    targetWindow:focus()
                    hs.timer.doAfter(0.01, function()
                        targetWindow:focus()

                        -- Raise the first window on a different screen
                        if windowToRaise then
                            hs.timer.doAfter(0.01, function()
                                windowToRaise:raise()
                            end)
                        end
                    end)
                end
            else
                if previousWindow:screen():id() == targetWindow:screen():id() then
                    -- Find the first window on a different screen to raise
                    local targetWindowScreenId = targetWindow:screen():id()
                    local windowToRaise = nil
                    for i = 1, #cachedWindows do
                        local window = cachedWindows[i]
                        if targetAppliation:pid() ~= window:application():pid() and window:screen():id() ~= targetWindowScreenId then
                            windowToRaise = window
                            break
                        end
                    end
                
                    -- First focus another window of the same application, then focus the target window
                    targetWindow:focus()
                    hs.timer.doAfter(0.01, function()
                        targetWindow:focus()

                        -- Raise the first window on a different screen
                        if windowToRaise then
                            hs.timer.doAfter(0.01, function()
                                windowToRaise:raise()
                            end)
                        end
                    end)
                else
                    -- First focus another window of the same application, then focus the target window
                    targetWindow:focus()
                    hs.timer.doAfter(0.01, function()
                        targetWindow:focus()

                        -- Raise the previous window
                        hs.timer.doAfter(0.01, function()
                            previousWindow:raise()
                        end)
                    end)
                end
            end
        end
    end

    return obj
end
return WindowModel
