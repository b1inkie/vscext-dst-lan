local main = require('core_%(modid)s/data/killability')

---@class replica_components
---@field %(modid)s_killability replica_%(modid)s_killability

---@class replica_%(modid)s_killability
---@field inst ent
local %(modid)s_killability = Class(
---@param self replica_%(modid)s_killability
---@param inst ent
function(self, inst)
    self.inst = inst
    for _,v in ipairs(main.data) do
        local id = v.id
        self[id] = net_bool(inst.GUID,'%(modid)s_killability.'..id)
    end
end)

---@return string
---@nodiscard
function %(modid)s_killability:GetDebugString()
    local str = '--------------------------\n'
    for _,v in pairs(main.data) do
        str = str .. subfmt('{id} | {mob_name} | 解锁: | {unlocked}\n',{id = v.id, mob_name = STRINGS.NAMES[string.upper(v.kill_prefab[1])] or v.kill_prefab[1], unlocked = self:CheckID(v.id) and 'Yes' or 'No'}) .. '\n'
    end
    str = str .. '--------------------------'
    return str
end

---通过ID检查某个能力有没有解锁(需要注意有没有设置网络变量)
---@param id data_%(modid)s_killability_id
---@return boolean
---@nodiscard
function %(modid)s_killability:CheckID(id)
    assert(self[id] ~= nil, '组件 %(modid)s_killability 的属性 '..id..' 没有设置网络变量!')
    return self[id]:value() or false
end

return %(modid)s_killability