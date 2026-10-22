-- Runtime state of the open panel (reset on every open/close).
local PanelState = {
    groupApp = nil,
    groupAppName = nil,
    searchActive = false,
    query = "",
    haystacks = {},
    anchorY = nil,
    panelW = nil,
    centerOn = nil, -- frame to center the panel on (active window); nil = screen center
}

function PanelState.reset()
    PanelState.groupApp = nil
    PanelState.groupAppName = nil
    PanelState.searchActive = false
    PanelState.query = ""
    PanelState.haystacks = {}
    PanelState.anchorY = nil
    PanelState.panelW = nil
    PanelState.centerOn = nil
end

function PanelState.hasHeader()
    return PanelState.searchActive or PanelState.groupApp ~= nil
end

return PanelState
