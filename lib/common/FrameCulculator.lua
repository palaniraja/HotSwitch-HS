local Debugger = require("hotswitch-hs/lib/common/Debugger")
local TimeChecker = require("hotswitch-hs/lib/common/TimeChecker")
local CanvasConstants = require("hotswitch-hs/lib/common/CanvasConstants")
local PanelState = require("hotswitch-hs/lib/model/PanelState")

local doesShowOnMainScreen = true

local function calcBaseCanvasFrame(orderedWindows)
    local panelH = (#orderedWindows + CanvasConstants.headerRows()) * CanvasConstants.ROW_HEIGHT + CanvasConstants.PADDING * 4

    local targetScreenFrame
    if doesShowOnMainScreen then
        targetScreenFrame = hs.screen.mainScreen():frame()
    else
        targetScreenFrame = hs.screen.primaryScreen():frame()
    end
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
}