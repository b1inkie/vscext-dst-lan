-- 这个组件我返工好多次了,暂时不碰了,等我有需求了再修改

---@class components
---@field %(modid)s_ent_bind_child component_%(modid)s_ent_bind_child # 实体绑定组件

---@class component_%(modid)s_ent_bind_child: component_base
---@field inst ent
---@field _uid string|nil # 唯一ID 由master生成的时候传入
---@field _field string # 为实体绑定 提供一个TUNING中的表所在的字段
local %(modid)s_ent_bind_child = Class(

---@param self component_%(modid)s_ent_bind_child
---@param inst ent
function(self, inst)
    self.inst = inst

    self._field = 'MOD_%(modid_upper)s'
end)

function %(modid)s_ent_bind_child:OnSave()
    local sav = {}
    sav._uid = self._uid
    return sav
end

function %(modid)s_ent_bind_child:OnLoad(sav)
    if sav then
        self._uid = sav._uid
    end
    self:_makesureTempTableAndPutMeInIt()
end


---comment
---@param _uid string
function %(modid)s_ent_bind_child:_addedByMaster(_uid)
    self._uid = _uid
    self:_makesureTempTableAndPutMeInIt()
end

---comment
function %(modid)s_ent_bind_child:_removedByMaster()
    if TUNING[self._field] and TUNING[self._field].bind and TUNING[self._field].bind[self._uid] and TUNING[self._field].bind[self._uid].childs then
        TUNING[self._field].bind[self._uid].childs[self.inst] = nil
    end
end

---确保临时全局表并把我自己挂到上面
---@private
function %(modid)s_ent_bind_child:_makesureTempTableAndPutMeInIt()
    if TUNING[self._field] == nil then
        TUNING[self._field] = {}
    end
    if TUNING[self._field].bind == nil then
        TUNING[self._field].bind = {}
    end
    if TUNING[self._field].bind[self._uid] == nil then
        TUNING[self._field].bind[self._uid] = {}
    end
    if TUNING[self._field].bind[self._uid].childs == nil then
        TUNING[self._field].bind[self._uid].childs = {}
    end
    TUNING[self._field].bind[self._uid].childs[self.inst] = true
end

---comment
---@return ent|nil
---@nodiscard
function %(modid)s_ent_bind_child:GetMaster()
return TUNING[self._field] and TUNING[self._field].bind and TUNING[self._field].bind[self._uid] and TUNING[self._field].bind[self._uid].master or nil
end

return %(modid)s_ent_bind_child