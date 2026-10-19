---@class components
---@field %(modid)s_ent_bind_master component_%(modid)s_ent_bind_master

-- 这个组件我返工好多次了,暂时不碰了,等我有需求了再修改

---@class component_%(modid)s_ent_bind_master: component_base # 实体绑定组件
---@field inst ent
---@field _uid_prefix string # 唯一ID前缀 
---@field _uid string|nil # 唯一ID 必要的时候由prefix+时间戳+随机数生成
---@field _field string # 为实体绑定 提供一个TUNING中的表所在的字段,自动生成
local %(modid)s_ent_bind_master = Class(
---@param self component_%(modid)s_ent_bind_master
---@param inst ent
function(self, inst)
    self.inst = inst

    self._field = 'MOD_%(modid_upper)s'
end)

function %(modid)s_ent_bind_master:OnSave()
    local sav = {}
    sav._uid = self._uid
    return sav
end

function %(modid)s_ent_bind_master:OnLoad(sav)
    if sav then
        self._uid = sav._uid
    end
    self:_makesureTempTableAndPutMeInIt()
end

---必须调用
---@param id string # 填一个唯一id,一般填master的prefabID
function %(modid)s_ent_bind_master:Init(id)
    self._uid_prefix = id
end

---@private
function %(modid)s_ent_bind_master:_genuid()
    if self._uid == nil then
        self._uid = self._uid_prefix..tostring(os.clock())..tostring(math.random(100))
    end
end

---comment
---@param child ent
function %(modid)s_ent_bind_master:AddOneChild(child)
    self:_genuid()

    self:_makesureTempTableAndPutMeInIt()
    if child.components.%(modid)s_ent_bind_child then
        child.components.%(modid)s_ent_bind_child:_addedByMaster(self._uid)
    end
end

---确保临时全局表并把我自己挂到上面
---@private
function %(modid)s_ent_bind_master:_makesureTempTableAndPutMeInIt()
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
    TUNING[self._field].bind[self._uid].master = self.inst
end

---获取所有child
---@param fn_each fun(child:ent,master:ent)|nil
---@return table<ent,true>|nil
function %(modid)s_ent_bind_master:GetAllChilds(fn_each)
    local childs = TUNING[self._field] and TUNING[self._field].bind and TUNING[self._field].bind[self._uid] and TUNING[self._field].bind[self._uid].childs or nil
    if fn_each and childs then
        for child,_ in pairs(childs) do
            fn_each(child,self.inst)
        end
    end
    return childs
end

---移除所有child(仅移除引用),每个孩子都会调用`fn_each`
---@param fn_each fun(child:ent,master:ent)|nil
function %(modid)s_ent_bind_master:RemoveAllChilds(fn_each)
    -- 先从child开始移除
    local childs = self:GetAllChilds()
    if childs then
        for child,_ in pairs(childs) do
            if child and child:IsValid() and child.components.%(modid)s_ent_bind_child then
                child.components.%(modid)s_ent_bind_child:_removedByMaster()
                if fn_each then fn_each(child,self.inst) end
            end
        end
    end
    if TUNING[self._field] and TUNING[self._field].bind and TUNING[self._field].bind[self._uid] then
        TUNING[self._field].bind[self._uid] = nil
    end
end

---移除指定child(仅移除引用),孩子会调用`fn`
---@param child ent
---@param fn fun(child:ent,master:ent)|nil # 孩子会调用
function %(modid)s_ent_bind_master:RemoveChild(child,fn)
    if child.components.%(modid)s_ent_bind_child then
        child.components.%(modid)s_ent_bind_child:_removedByMaster()
    end
end

return %(modid)s_ent_bind_master