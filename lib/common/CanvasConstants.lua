local PanelState = require("hotswitch-hs/lib/model/PanelState")

local CanvasConstants = {
    FONT_SIZE = 18,

    PANEL_W = 520,
    PANEL_W_APP_NAME_ONLY = 300,

    PADDING = 5,
    KEY_W = 24,
    KEY_LEFT_PADDING = 15,
    ROW_HEIGHT = 28,

    APP_ICON_W = 28,
    APP_NAME_W = 160,

    OUTLINE_RECTANGLE_ALPHA = 0.5,
    INLINE_RECTANGLE_ALPHA = 0.8,
    SELECTED_ROW_ALPHA = 0.3,
    TEXT_ALPHA = 1,

    TEXT_WHITE_VALUE = 0.92,

    TOAST_W = 520,
    TOAST_H = 46,
    TOAST_ALPHA = 0.8,
    TOAST_FONT_SIZE = 22,

    KEY_FONT_NAME = "JetBrains Mono",
    KEY_FONT_SIZE = 16,
    KEY_FONT_COLOR_AUTO_GEN = {
        alpha = 1,
        blue = 0.1,
        green = 0.9,
        red = 0.9
    },
    KEY_FONT_COLOR_CUSTOM_SET = {
        alpha = 1,
        blue = 0.92,
        green = 0.92,
        red = 0.92
    },

    alwaysShowAppName = false,

    customAppTitles = {},
}

function CanvasConstants.setCustomAppTitle(bundleID, title)
    CanvasConstants.customAppTitles[bundleID] = title
end

-- Width actually used while the panel is open (grown to fit titles, see BaseCanvasView).
function CanvasConstants.getEffectivePanelW()
    if PanelState.panelW then return PanelState.panelW end
    return CanvasConstants.getMinPanelW()
end

-- Configured width; the panel never gets narrower than this.
function CanvasConstants.getMinPanelW()
    if CanvasConstants.alwaysShowAppName then
        return CanvasConstants.PANEL_W_APP_NAME_ONLY
    else
        return CanvasConstants.PANEL_W
    end
end

function CanvasConstants.headerRows()
    return PanelState.hasHeader() and 1 or 0
end

-- y of row i (1-based), shifted down when the search/group header row is shown
function CanvasConstants.rowY(i)
    return (i - 1 + CanvasConstants.headerRows()) * CanvasConstants.ROW_HEIGHT + CanvasConstants.PADDING * 2
end

-- for debug
-- local BASE_ALPHA = 0.2
-- canvasConstants.OUTLINE_RECTANGLE_ALPHA = BASE_ALPHA
-- canvasConstants.INLINE_RECTANGLE_ALPHA = BASE_ALPHA
-- canvasConstants.SELECTED_ROW_ALPHA = BASE_ALPHA
-- canvasConstants.TEXT_ALPHA = BASE_ALPHA

return CanvasConstants
