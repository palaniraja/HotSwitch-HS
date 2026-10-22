-- Panel feature toggles. Set from init.lua via hotswitchHs.setOptions({...}).
local Options = {
    search = false,       -- "/" opens type-to-filter search
    groupByApp = false,   -- rows grouped by app; 1st key picks app, 2nd key picks window
    readableRows = false, -- key badges, dimmed minimized/hidden windows, screen tag
    maxRows = nil,        -- cap visible rows (nil = no cap)
}

function Options.apply(values)
    for k, v in pairs(values or {}) do
        Options[k] = v
    end
end

return Options
