local Debugger = require("hotswitch-hs/lib/common/Debugger")
local TimeChecker = require("hotswitch-hs/lib/common/TimeChecker")
local CanvasConstants = require("hotswitch-hs/lib/common/CanvasConstants")
local PanelState = require("hotswitch-hs/lib/model/PanelState")

local doesShowOnMainScreen = true

local MAX_SCREEN_WIDTH_RATIO = 0.7

local function targetScreenFrame()
    if doesShowOnMainScreen then
        return hs.screen.mainScreen():frame()
    end
    return hs.screen.primaryScreen():frame()
end

-- Read once, then re-read only when monitors change (added/removed/resolution).
local cachedMaxPanelW = nil
local screenWatcher = hs.screen.watcher.new(function() cachedMaxPanelW = nil end)
screenWatcher:start()

local function maxPanelW()
    if cachedMaxPanelW == nil then
        cachedMaxPanelW = math.floor(targetScreenFrame().w * MAX_SCREEN_WIDTH_RATIO)
    end
    return cachedMaxPanelW
end

local function calcBaseCanvasFrame(orderedWindows)
    local panelH = (#orderedWindows + CanvasConstants.headerRows()) * CanvasConstants.ROW_HEIGHT + CanvasConstants.PADDING * 4

    local targetScreenFrame = targetScreenFrame()
    local effectivePanelW = CanvasConstants.getEffectivePanelW()
    local panelX = targetScreenFrame.x + targetScreenFrame.w / 2 - effectivePanelW / 2
    -- Keep the top edge fixed while the panel is open, so filtering doesn't make it jump.
    if PanelState.anchorY == nil then
        PanelState.anchorY = targetScreenFrame.y + targetScreenFrame.h / 2 - panelH / 2
    end
    local panelY = PanelState.anchorY

    local baseCanvasFrame = {
        x = panelX,
        y = panelY,
        h = panelH,
        w = effectivePanelW
    }
    return baseCanvasFrame
end

local function setShowingOnMainScreen(flag)
    doesShowOnMainScreen = flag
end

return {
    calcBaseCanvasFrame = calcBaseCanvasFrame,
    setShowingOnMainScreen = setShowingOnMainScreen,
    maxPanelW = maxPanelW,
    _screenWatcher = screenWatcher, -- keep a reference so it isn't garbage-collected
}