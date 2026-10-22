local canvas = require("hs.canvas")

local Debugger = require("hotswitch-hs/lib/common/Debugger")
local TimeChecker = require("hotswitch-hs/lib/common/TimeChecker")
local View = require("hotswitch-hs/lib/view/View")
local BaseCanvasView = require("hotswitch-hs/lib/view/BaseCanvasView")
local SelectedRowCanvasView = require("hotswitch-hs/lib/view/SelectedRowCanvasView")

local PanelState = require("hotswitch-hs/lib/model/PanelState")

local PanelLayoutView = {}
PanelLayoutView.new = function(windowModel, settingModel, keyStatusModel)
    local obj = View.new()

    obj.isOpen = false
    obj.baseCanvasView = BaseCanvasView.new(windowModel, settingModel, keyStatusModel)
    obj.selectedRowCanvasView = SelectedRowCanvasView.new(windowModel, 2)
    obj.windowModel = windowModel
    obj.settingModel = settingModel

    obj.show = function(self)
        if self.isOpen == false then
            self.isOpen = true
            self.selectedRowCanvasView.position = self.windowModel:defaultRowPosition()
        end

        -- local t = TimeChecker.new()
        self.baseCanvasView:show()
        -- t:diff("PanelLayoutView:baseCanvasView:show")
        self.selectedRowCanvasView:createSelectedRow()
        -- t:diff("PanelLayoutView:selectedRowCanvasView:createSelectedRow")

        self.selectedRowCanvasView:replaceSelectedRow()
        -- t:diff("PanelLayoutView:selectedRowCanvasView:replaceSelectedRow")
    end

    obj.hide = function(self)
        self.isOpen = false

        self.baseCanvasView:hide()
        self.selectedRowCanvasView:hide()
        PanelState.reset()
    end

    -- Redraw after the row set changed (search query / app group). Canvases are rebuilt
    -- because their height depends on the row count.
    obj.rerender = function(self, position)
        self.baseCanvasView:hide()
        self.selectedRowCanvasView:hide()
        local rows = #self.windowModel:getCachedOrderedWindowsOrFetch()
        self.selectedRowCanvasView.position = math.max(1, math.min(position or 1, rows))
        self:show()
    end

    obj.getSelectedRowPosition = function(self)
        return self.selectedRowCanvasView.position
    end

    obj.resetSelectedRowPosition = function(self)
        self.selectedRowCanvasView.position = self.windowModel:defaultRowPosition()
    end
    
    obj.selectNextRow = function(self, windowModel)
        self.selectedRowCanvasView:next(windowModel)
    end

    obj.selectPreviousRow = function(self, windowModel)
        self.selectedRowCanvasView:previous(windowModel)
    end

    obj.unemphasisRow = function(self)
        self.selectedRowCanvasView:replaceSelectedRow()
    end

    obj.emphasisRow = function(self)
        self.selectedRowCanvasView:replaceAndEmphasisSelectedRow()
    end

    obj.setClickCallback = function(self, clickCallback)
        self.baseCanvasView:setClickCallback(clickCallback)
    end

    obj.activateHammerspoonWindow = function(self)
        self.baseCanvasView:activateHammerspoonWindow()
    end

    return obj
end

return PanelLayoutView
