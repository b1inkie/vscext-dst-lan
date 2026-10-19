---@diagnostic disable
local modid = '%(modid)s'

---@class api_container # 容器API
local dst_lan = {}

---@private
function dst_lan:MakeContainerUI(params)
    local containers = require 'containers'

    for k, v in pairs(params) do
        containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
        v.widget.dst_lan_from_whichmod = modid
    end

    local old_widgetsetup = containers.widgetsetup

    ---@diagnostic disable-next-line: assign-type-mismatch
    function containers.widgetsetup(container, prefab, data)
        local t = data or params[prefab or container.inst.prefab]
        if t ~= nil then
            for k, v in pairs(t) do
                container[k] = v
            end
            container:SetNumSlots(container.widget.slotpos ~= nil and #container.widget.slotpos or 0)
        else
            return old_widgetsetup(container, prefab, data)
        end
    end
end

---
---@param params table 容器参数
---@param tips_when_drag string|nil 拖拽提示,不填则不设置拖拽
---@private
function dst_lan:SetDrag(params,tips_when_drag)
    -- GLOBAL.MakedragDragableUI=MakedragDragableUI
    local uiloot_drag = {} --UI列表，方便重置
    --拖拽坐标，局部变量存储，减少io操作
    local dragpos_drag = {}
    --更新同步拖拽坐标(如果容器没打开过，那么存储的坐标信息就没被赋值到dragpos里，这时候直接去存储就会导致之前存储的数据缺失，所以要主动取一下数据存到dragpos里)
    local function loadDragPos_drag()
        TheSim:GetPersistentString("drag_drag_pos", function(load_success, data)
            if load_success and data ~= nil then
                local success, allpos = RunInSandbox(data)
                if success and allpos then
                    for k, v in pairs(allpos) do
                        if dragpos_drag[k] == nil then
                            dragpos_drag[k] = Vector3(v.x or 0, v.y or 0, v.z or 0)
                        end
                    end
                end
            end
        end)
    end
    --存储拖拽后坐标
    local function saveDragPos_drag(dragtype_drag, pos)
        if next(dragpos_drag) then
            local str = DataDumper(dragpos_drag, nil, true)
            TheSim:SetPersistentString("drag_drag_pos", str, false)
        end
    end
    --获取拖拽坐标
    function GetdragDragPos(dragtype_drag)
        if dragpos_drag[dragtype_drag] == nil then
            loadDragPos_drag()
        end
        return dragpos_drag[dragtype_drag]
    end

    --设置UI可拖拽(self,拖拽目标,拖拽标签,拖拽信息)
    local function MakedragDragableUI(self, dragtarget, dragtype_drag, dragdata)
        self.candrag_drag = true         --可拖拽标识(防止重复添加拖拽功能)
        uiloot_drag[self] = self:GetPosition() --存储UI默认坐标
        --给拖拽目标添加拖拽提示
        if dragtarget then
            dragtarget:SetTooltip(tips_when_drag)
            local oldOnControl = dragtarget.OnControl
            dragtarget.OnControl = function(self, control, down)
                local parentwidget = self:GetParent() --控制它爹的坐标,而不是它自己
                --按下右键可拖动
                if parentwidget and parentwidget.Passive_OnControl then
                    parentwidget:Passive_OnControl(control, down)
                end
                return oldOnControl and oldOnControl(self, control, down)
            end
        end

        --被控制(控制状态，是否按下)
        function self:Passive_OnControl(control, down)
            if self.focus and control == CONTROL_SECONDARY then
                if down then
                    self:StartDrag()
                else
                    self:EndDrag()
                end
            end
        end

        --设置拖拽坐标
        function self:SetDragPosition(x, y, z)
            local pos
            if type(x) == "number" then
                pos = Vector3(x, y, z)
            else
                pos = x
            end

            local self_scale = self:GetScale()
            local offset = dragdata and dragdata.drag_offset or 1                --偏移修正(容器是0.6)
            local newpos = self.p_startpos + (pos - self.m_startpos) / (self_scale.x / offset) --修正偏移值
            self:SetPosition(newpos)                                             --设定新坐标
        end

        --开始拖动
        function self:StartDrag()
            if not self.followhandler then
                local mousepos = TheInput:GetScreenPosition()
                self.m_startpos = mousepos       --鼠标初始坐标
                self.p_startpos = self:GetPosition() --面板初始坐标
                self.followhandler = TheInput:AddMoveHandler(function(x, y)
                    self:SetDragPosition(x, y, 0)
                    if not Input:IsMouseDown(MOUSEBUTTON_RIGHT) then
                        self:EndDrag()
                    end
                end)
                self:SetDragPosition(mousepos)
            end
        end

        --停止拖动
        function self:EndDrag()
            if self.followhandler then
                self.followhandler:Remove()
            end
            self.followhandler = nil
            self.m_startpos = nil
            self.p_startpos = nil
            local newpos = self:GetPosition()
            if dragtype_drag then
                dragpos_drag[dragtype_drag] = newpos --记录记录拖拽后坐标
            end
            saveDragPos_drag()                    --存储坐标
        end
    end

    --重置拖拽坐标
    function ResetdragUIPos()
        dragpos_drag = {}
        TheSim:SetPersistentString("drag_drag_pos", "", false)
        for k, v in pairs(uiloot_drag) do
            if k.inst and k.inst:IsValid() then
                k:SetPosition(v)  --重置坐标
            else
                uiloot_drag[k] = nil --失效了的就清掉吧
            end
        end
    end

    -------------------------------

    AddClassPostConstruct("widgets/containerwidget", function(self)

        ---用唯一标签找对应的容器ui
        ---@param unique_tag string
        ---@return class|boolean
        ---@nodiscard
        local function clientwidget(unique_tag)
            if self.container and self.container.replica.container then
                local widget = self.container.replica.container:GetWidget()
                local unique = widget and widget.unique
                if unique and unique == unique_tag then
                    return widget
                end
            end
            return false
        end

        local oldOpen = self.Open
        function self:Open(...)
            oldOpen(self, ...)

            if self.container and self.container.replica.container then
                local widget = self.container.replica.container:GetWidget()
                if widget then
                    --拖拽坐标标签，有则用标签，无则用容器名
                    local dragname = widget.dst_lan_from_whichmod and widget.dst_lan_from_whichmod == modid and widget.dragtype_drag or nil --or (self.container and self.container.prefab)
                    
                    if dragname then
                        --设置可拖拽
                        if not self.candrag_drag then
                            MakedragDragableUI(self, self.bganim, dragname, { drag_offset = 0.6 })
                        end
                        --设置容器坐标(可装备的容器第一次打开做个延迟，不然加载游戏进来位置读不到)
                        local newpos = GetdragDragPos(dragname) or (params[dragname] and params[dragname].widget.pos)
                        if newpos then
                            if self.container:HasTag("_equippable") and not self.container.isopended then
                                self.container:DoTaskInTime(0, function()
                                    self:SetPosition(newpos)
                                end)
                                self.container.isopended = true
                            else
                                self:SetPosition(newpos)
                            end
                        end
                    end
                end
            end
        end
    end)
end


---
---main
---@param params table 容器参数
---@param tips_when_drag string|nil 拖拽提示,不填则不设置拖拽
function dst_lan:main(params,tips_when_drag)
    self:MakeContainerUI(params)
    self:SetDrag(params,(STRINGS.MOD_%(modid_upper)s and STRINGS.MOD_%(modid_upper)s.DRAG_INFO) or 'right-click to drag')
end

return dst_lan
