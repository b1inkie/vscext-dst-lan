---@class components
---@field %(modid)s_tradeable component_%(modid)s_tradeable # 不用管我(这个组件是为 通用交易 功能服务的 )

---@class component_%(modid)s_tradeable
---@field inst ent
local %(modid)s_tradeable = Class(
---@param self component_%(modid)s_tradeable
---@param inst ent
function(self, inst)
    self.inst = inst
end,
nil,
{
})

return %(modid)s_tradeable