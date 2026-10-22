-- Runtime state of the open panel (reset on every open/close).
local PanelState = {
    groupApp = nil,
    groupAppName = nil,
    searchActive = false,
    query = "",
    haystacks = {},
    anchorY = nil,
}

function PanelState.reset()
    PanelState.groupApp = nil
    PanelState.groupAppName = nil
    PanelState.searchActive = false
    PanelState.query = ""
    PanelState.haystacks = {}
    PanelState.anchorY = nil
end

function PanelState.hasHeader()
    return PanelState.searchActive or PanelState.groupApp ~= nil
end

return PanelState
