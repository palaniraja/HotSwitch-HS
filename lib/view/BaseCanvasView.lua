local canvas = require("hs.canvas")

local Debugger = require("hotswitch-hs/lib/common/Debugger")
local TimeChecker = require("hotswitch-hs/lib/common/TimeChecker")
local View = require("hotswitch-hs/lib/view/View")
local CanvasConstants = require("hotswitch-hs/lib/common/CanvasConstants")
local FrameCulculator = require("hotswitch-hs/lib/common/FrameCulculator")
local Options = require("hotswitch-hs/lib/common/Options")
local PanelState = require("hotswitch-hs/lib/model/PanelState")

local DIM_ALPHA = 0.45
local TAG_FONT_SIZE = 12
local TAG_W = 70

-- application:bundleID() can return nil (e.g. some helper/background apps have no bundle ID),
-- and a nil key would crash a table write (appWindowCount[bundleID] = ...) or silently
-- lump unrelated apps together. Fall back to an "unknown:<appName>" key, which can never
-- collide with a real bundle ID since those are always reverse-DNS formatted without ":".
local getBundleIDOrFallback = function(application)
    return application:bundleID() or ("unknown:" .. application:name())
end

local BaseCanvasView = {}
BaseCanvasView.new = function(windowModel, settingModel, keyStatusModel)
    local obj = View.new()

    obj.windowModel = windowModel
    obj.settingModel = settingModel
    obj.keyStatusModel = keyStatusModel

    obj.clickCallback = nil

    obj.show = function(self)
        -- local t = TimeChecker.new()
        local orderedWindows = self.windowModel:getCachedOrderedWindowsOrFetch()
        -- t:diff("getCachedOrderedWindowsOrFetch")

        self:showRectangle(orderedWindows)
        -- t:diff("showRectangle") -- sometimes, slow
        self:showWindowInfo(orderedWindows)
        -- t:diff("showWindowInfo")
    end

    obj.hide = function(self)
        if self.baseCanvas ~= nil then
            self.baseCanvas:delete()
            self.baseCanvas = nil
        end
    end

    obj.showRectangle = function(self, orderedWindows)
        -- local t = TimeChecker.new()
        if self.baseCanvas == nil then
            local frame = FrameCulculator.calcBaseCanvasFrame(orderedWindows)
            -- t:diff("calcBaseCanvasFrame")
            self.baseCanvas = canvas.new(frame)
            -- t:diff("new")
        end
        -- t:diff("canvas new")

        self:setElements(orderedWindows)
        -- t:diff("setElements")

        -- self:activateHammerspoonWindow()
        -- self.baseCanvas:level("normal") -- don't need
        -- self.baseCanvas:bringToFront()

        self:initializeMouseEvent(orderedWindows)
    end

    obj.initializeMouseEvent = function(self, orderedWindows)
        self.baseCanvas:canvasMouseEvents(false, true, false, false)
        self.baseCanvas:mouseCallback(function(canvas, type, elementId, x, y)
            if self.clickCallback == nil then
                return
            end

            if type == "mouseUp" then
                local position = math.floor((y - CanvasConstants.PADDING * 2) / CanvasConstants.ROW_HEIGHT + 1)
                    - CanvasConstants.headerRows()
                if position < 1 then
                    position = 1
                elseif position > #orderedWindows then
                    position = #orderedWindows
                end

                self.clickCallback(position)
            end
        end)
    end

    -- clickCallback = function(position) end
    obj.setClickCallback = function(self, clickCallback)
        self.clickCallback = clickCallback
    end

    obj.activateHammerspoonWindow = function(self)
        local app = hs.application.get("Hammerspoon")
        app:setFrontmost()
    end

    obj.setElements = function(self, orderedWindows)
        self.baseCanvas:replaceElements({
            action = "fill",
            fillColor = {
                alpha = CanvasConstants.INLINE_RECTANGLE_ALPHA,
                blue = 0.5,
                green = 0.5,
                red = 0.5
            },
            frame = {
                x = "0",
                y = "0",
                h = "1",
                w = "1"
            },
            type = "rectangle",
            withShadow = true
        })

        self.baseCanvas:appendElements({
            action = "fill",
            fillColor = {
                alpha = CanvasConstants.OUTLINE_RECTANGLE_ALPHA,
                blue = 0,
                green = 0,
                red = 0
            },
            frame = {
                x = CanvasConstants.PADDING,
                y = CanvasConstants.PADDING,
                h = (#orderedWindows + CanvasConstants.headerRows()) * CanvasConstants.ROW_HEIGHT + CanvasConstants.PADDING * 2,
                w = CanvasConstants.getEffectivePanelW() - CanvasConstants.PADDING * 2
            },
            type = "rectangle"
        })
    end

    obj.showWindowInfo = function(self, orderedWindows)
        -- local t = TimeChecker.new()
        local appWindowCount = {}
        for _, w in ipairs(self.windowModel.allOrderedWindows or orderedWindows) do
            local bundleID = getBundleIDOrFallback(w:application())
            appWindowCount[bundleID] = (appWindowCount[bundleID] or 0) + 1
        end

        self.screenCount = #hs.screen.allScreens()
        self.keyStatusOfWindow = {}
        for _, keyStatus in ipairs(self.keyStatusModel.registeredAndAutoGeneratedKeyStatuses) do
            self.keyStatusOfWindow[keyStatus.windowId] = keyStatus
        end

        self:showHeader(orderedWindows)

        for i = 1, #orderedWindows do
            local window = orderedWindows[i]
            self.rowIsDim = Options.readableRows and (window:isMinimized() or window:application():isHidden())

            -- t:diff(i)
            self:showEachKeyText(i, window)
            -- t:diff("showEachKeyText")
            self:showEachAppIcon(i, window)
            -- t:diff("showEachAppIcon")
            self:showEachWindowTitle(i, window, appWindowCount)
            -- t:diff("showEachWindowTitle")
        end

        self.baseCanvas:show()
        -- t:diff("show")
    end

    obj.showEachKeyText = function(self, i, window)
        local windowId = window:id()

        local keyText = ""
        local isAutoGeneratedKey

        local keyStatus = self.keyStatusOfWindow[windowId]
        if keyStatus then
            keyText = keyStatus.key
            isAutoGeneratedKey = keyStatus.isAutoGenerated
        end
        if PanelState.searchActive then
            keyText = "" -- letters type into the query while searching
        end

        local textColor
        if isAutoGeneratedKey then
            textColor = CanvasConstants.KEY_FONT_COLOR_AUTO_GEN
        else
            textColor = CanvasConstants.KEY_FONT_COLOR_CUSTOM_SET
        end

        if Options.readableRows and keyText ~= "" then
            self.baseCanvas:appendElements({
                action = "fill",
                fillColor = { white = 1, alpha = 0.15 },
                roundedRectRadii = { xRadius = 4, yRadius = 4 },
                frame = {
                    x = CanvasConstants.PADDING * 2 + CanvasConstants.KEY_LEFT_PADDING - 6,
                    y = CanvasConstants.rowY(i) + 3,
                    h = CanvasConstants.ROW_HEIGHT - 6,
                    w = CanvasConstants.KEY_W
                },
                type = "rectangle",
            })
        end

        self.baseCanvas:appendElements({
            frame = {
                x = CanvasConstants.PADDING * 2 + CanvasConstants.KEY_LEFT_PADDING,
                y = CanvasConstants.rowY(i),
                h = CanvasConstants.ROW_HEIGHT,
                w = CanvasConstants.KEY_W
            },
            text = hs.styledtext.new(keyText, {
                font = {
                    name = CanvasConstants.KEY_FONT_NAME,
                    size = CanvasConstants.KEY_FONT_SIZE
                },
                color = textColor
            }),
            type = "text"
        })

        local appName = window:application():name()
        Debugger.log(keyText .. " : " .. appName)
    end

    obj.showEachAppName = function(self, i, window)
        local appName = window:application():name()
        self.baseCanvas:appendElements({
            frame = {
                x = CanvasConstants.PADDING * 2 + CanvasConstants.KEY_LEFT_PADDING + CanvasConstants.KEY_W,
                y = CanvasConstants.rowY(i),
                h = CanvasConstants.ROW_HEIGHT,
                w = CanvasConstants.APP_NAME_W
            },
            text = hs.styledtext.new(appName, {
                font = {
                    name = ".AppleSystemUIFont",
                    size = CanvasConstants.FONT_SIZE
                },
                color = {
                    alpha = CanvasConstants.TEXT_ALPHA,
                    blue = CanvasConstants.TEXT_WHITE_VALUE,
                    green = CanvasConstants.TEXT_WHITE_VALUE,
                    red = CanvasConstants.TEXT_WHITE_VALUE
                }
            }),
            type = "text"
        })
    end

    obj.showEachAppIcon = function(self, i, window)
        local frame = {
            x = CanvasConstants.PADDING * 2 + CanvasConstants.KEY_LEFT_PADDING + CanvasConstants.KEY_W,
            y = CanvasConstants.rowY(i),
            h = CanvasConstants.ROW_HEIGHT - 3,
            w = CanvasConstants.APP_ICON_W - 3
        }

        local bundleID = window:application():bundleID()
        if bundleID then
            self.baseCanvas:appendElements({
                frame = frame,
                image = hs.image.imageFromAppBundle(bundleID),
                imageAlpha = self.rowIsDim and DIM_ALPHA or 1,
                imageScaling = "scaleToFit",
                type = "image",
            })
        else
            local radius = frame.w / 2

            self.baseCanvas:appendElements({
                center = { x = frame.x + radius, y = frame.y + radius },
                action = "fill",
                fillColor = { alpha = 1, blue = 0.5, green = 0.5, red = 0.5 },
                radius = radius - 1,
                type = "circle",
            })
        end
    end

    obj.showEachWindowTitle = function(self, i, window, appWindowCount)
        -- local t = TimeChecker.new()
        local windowName
        local bundleID = getBundleIDOrFallback(window:application())
        local keyStatus = self.keyStatusOfWindow[window:id()]
        if keyStatus and keyStatus.isGroup and not PanelState.searchActive then
            windowName = window:application():name()
            if keyStatus.count > 1 then
                windowName = windowName .. "  (" .. keyStatus.count .. ")"
            end
        elseif PanelState.searchActive or PanelState.groupApp then
            local title = window:title()
            windowName = (title ~= "" and title) or window:application():name()
            if PanelState.searchActive and title ~= "" and appWindowCount[bundleID] > 1 then
                windowName = window:application():name() .. " – " .. title
            end
        elseif CanvasConstants.customAppTitles[bundleID] then
            windowName = CanvasConstants.customAppTitles[bundleID]
        elseif CanvasConstants.alwaysShowAppName then
            windowName = window:application():name()
        elseif bundleID == "com.apple.finder" then
            windowName = "Finder"
        elseif appWindowCount[bundleID] == 1 then
            windowName = window:application():name()
        else
            windowName = window:title() -- sometimes slow
            if windowName == "" then
                windowName = window:application():name()
            end
        end

        local tag = self:rowTag(window)
        local titleW = CanvasConstants.getEffectivePanelW() - CanvasConstants.KEY_W - CanvasConstants.APP_ICON_W -
            CanvasConstants.PADDING * 6
        if tag then
            titleW = titleW - TAG_W
            self.baseCanvas:appendElements({
                frame = {
                    x = CanvasConstants.getEffectivePanelW() - CanvasConstants.PADDING * 3 - TAG_W,
                    y = CanvasConstants.rowY(i) + 5,
                    h = CanvasConstants.ROW_HEIGHT,
                    w = TAG_W
                },
                text = hs.styledtext.new(tag, {
                    font = { name = ".AppleSystemUIFont", size = TAG_FONT_SIZE },
                    color = { white = 1, alpha = 0.55 },
                    paragraphStyle = { alignment = "right" },
                }),
                type = "text"
            })
        end

        self.baseCanvas:appendElements({
            frame = {
                x = CanvasConstants.PADDING * 3 + CanvasConstants.KEY_W + CanvasConstants.KEY_LEFT_PADDING +
                    CanvasConstants.APP_ICON_W,
                y = CanvasConstants.rowY(i),
                h = CanvasConstants.ROW_HEIGHT,
                w = titleW
            },
            text = hs.styledtext.new(windowName, {
                font = {
                    name = ".AppleSystemUIFont",
                    size = CanvasConstants.FONT_SIZE
                },
                paragraphStyle = { lineBreak = "truncateTail" },
                color = {
                    alpha = self.rowIsDim and DIM_ALPHA or CanvasConstants.TEXT_ALPHA,
                    blue = CanvasConstants.TEXT_WHITE_VALUE,
                    green = CanvasConstants.TEXT_WHITE_VALUE,
                    red = CanvasConstants.TEXT_WHITE_VALUE
                }
            }),
            type = "text"
        })
    end

    -- readableRows: "min" / "hidden" for dimmed windows, screen number when >1 screen.
    obj.rowTag = function(self, window)
        if not Options.readableRows then return nil end
        local parts = {}
        if window:isMinimized() then
            table.insert(parts, "min")
        elseif window:application():isHidden() then
            table.insert(parts, "hidden")
        end
        if self.screenCount > 1 and window:screen() then
            for n, screen in ipairs(hs.screen.allScreens()) do
                if screen:id() == window:screen():id() then
                    table.insert(parts, "⧉" .. n)
                    break
                end
            end
        end
        if #parts == 0 then return nil end
        return table.concat(parts, " ")
    end

    -- Header row: search query, or the app whose windows are being picked.
    obj.showHeader = function(self, orderedWindows)
        if not PanelState.hasHeader() then return end
        local text
        if PanelState.searchActive then
            text = "/ " .. PanelState.query .. "▏"
            if #orderedWindows == 0 then text = text .. "   no matches" end
        else
            text = "‹ " .. (PanelState.groupAppName or "") .. "   (esc: back)"
        end
        self.baseCanvas:appendElements({
            frame = {
                x = CanvasConstants.PADDING * 2 + CanvasConstants.KEY_LEFT_PADDING,
                y = CanvasConstants.PADDING * 2,
                h = CanvasConstants.ROW_HEIGHT,
                w = CanvasConstants.getEffectivePanelW() - CanvasConstants.PADDING * 6
            },
            text = hs.styledtext.new(text, {
                font = { name = ".AppleSystemUIFont", size = CanvasConstants.FONT_SIZE },
                color = CanvasConstants.KEY_FONT_COLOR_AUTO_GEN,
            }),
            type = "text"
        })
    end

    return obj
end
return BaseCanvasView
