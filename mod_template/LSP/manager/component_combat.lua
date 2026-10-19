---@meta

---@class component_combat
---@field atk_speed_from_alt_modifier SourceModifierList # alt攻速,乘算修饰
local main = {}

---
---@param source ent|string
---@param m number
---@param key string
function main:ModifierAltAtkSpeed(source,m,key)
end

---
---@return number
---@nodiscard
function main:GetAltAtkSpeedModifier()
end

---
---@param source ent|string
---@param key string
function main:RemoveModifierAltAtkSpeed(source,key)
end