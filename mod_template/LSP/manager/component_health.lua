---@meta

---@class component_health
---@field _dst_lan_invincible_modifier SourceModifierList # alt攻速,bool修饰
local main = {}

---添加无敌
---@param source ent|string
---@param m boolean
---@param key string
function main:ModifierLanInvincible(source,m,key)
end

---移除无敌
---@param source ent|string
---@param key string
function main:RemoveModifierLanInvincible(source,key)
end

---是否无敌
---@return boolean
---@nodiscard
function main:CheckIsLanInvincible()
end