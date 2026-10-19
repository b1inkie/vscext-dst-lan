-- 这个组件是为 物品栏数字cd 服务的

---@class components
---@field %(modid)s_cd_in_itemtile component_%(modid)s_cd_in_itemtile

---comment
---@param self replica_%(modid)s_cd_in_itemtile
---@param value any
local function on_cur_cd(self, value)
    self.inst.replica.%(modid)s_cd_in_itemtile:SetCurCD(value)
end

---comment
---@param self replica_%(modid)s_cd_in_itemtile
---@param value any
local function on__show_itemtile(self, value)
    self.inst.replica.%(modid)s_cd_in_itemtile._show_itemtile:set(value)
end

---@class component_%(modid)s_cd_in_itemtile
---@field inst ent
---@field cd integer # 总cd
---@field cur_cd integer # 剩余cd
---@field _show_itemtile boolean # 是否显示在itemtile, 不设置则默认为显示
---@field _task Periodic|nil
---@field onstartcdfn fun(this:ent,...):... # 开始cd时调用
---@field onfinishcdfn fun(this:ent,...):... # cd转好时调用
local %(modid)s_cd_in_itemtile = Class(
---@param self component_%(modid)s_cd_in_itemtile
---@param inst ent
function(self, inst)
    self.inst = inst
    self.cd = 10
    self.cur_cd = 0

    self._show_itemtile = true
end,
nil,
{
    cur_cd = on_cur_cd,
    _show_itemtile = on__show_itemtile,
})

function %(modid)s_cd_in_itemtile:OnSave()
    return {
        cd = self.cd,
        cur_cd = self.cur_cd,
    }
end

function %(modid)s_cd_in_itemtile:OnLoad(data)
    self.cd = data.cd or 10
    self.cur_cd = data.cur_cd or 0

    if self.cur_cd > 0 then
        self:_StartCD(self.cd,true)
    end
end

---初始化,添加组件后需要进行设置
---@param cd integer # 设置默认cd
---@param shown_on_itemtile boolean|nil # 是否显示在itemtile上,不设置默认显示
function %(modid)s_cd_in_itemtile:Init(cd,shown_on_itemtile)
    self.cd = cd
    if shown_on_itemtile ~= nil and shown_on_itemtile == false then
        self:ShowItemTile(shown_on_itemtile)
    end
end

---更改默认cd
---@param cd integer
function %(modid)s_cd_in_itemtile:ChangeDefaultCD(cd)
    self.cd = cd
end

---开始cd
---@param cd integer|nil # 不填用默认cd,填了则会更新默认cd
---@param start_without_onstartcdfn boolean # 不调用onstartcdfn
---@protected
function %(modid)s_cd_in_itemtile:_StartCD(cd,start_without_onstartcdfn)
    -- 更新默认cd
    if cd then
        self.cd = cd
    end
    -- 停止之前的cd
    if self._task ~= nil then self._task:Cancel() self._task = nil end
    -- 开始新的cd
    if self.onstartcdfn then self.onstartcdfn(self.inst) end
    self.cur_cd = self.cd
    self._task = self.inst:DoPeriodicTask(1, function()
        self.cur_cd = math.max(0,self.cur_cd - 1)
        if self.cur_cd <= 0 then
            if self.onfinishcdfn then self.onfinishcdfn(self.inst) end
            if self._task ~= nil then self._task:Cancel() self._task = nil end
            return
        end
    end)
end

---开始cd
---@param cd integer|nil # 不填用默认cd,填了则会更新默认cd
function %(modid)s_cd_in_itemtile:StartCD(cd)
    self:_StartCD(cd,false)
end

---是否在cd中
---@return boolean
---@nodiscard
function %(modid)s_cd_in_itemtile:IsCD()
    return self.cur_cd > 0
end

---当在cd中时修改剩余cd
---@param val integer
function %(modid)s_cd_in_itemtile:SetCurCD(val)
    if self:IsCD() then
        self.cur_cd = val
    end
end

---设置开始cd时调用的函数
---@param fn fun(this:ent,...):...
function %(modid)s_cd_in_itemtile:SetOnStartCD(fn)
    self.onstartcdfn = fn
end

---设置cd转好时调用的函数
---@param fn fun(this:ent,...):...
function %(modid)s_cd_in_itemtile:SetOnFinishCD(fn)
    self.onfinishcdfn = fn
end

---是否显示在itemtile上,不设置默认显示
---@param shown boolean
function %(modid)s_cd_in_itemtile:ShowItemTile(shown)
    self._show_itemtile = shown
end

return %(modid)s_cd_in_itemtile