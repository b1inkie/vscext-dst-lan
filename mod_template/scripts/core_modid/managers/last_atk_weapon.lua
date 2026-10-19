-- hide
-- 功能(无需修改): 获取攻击者上次使用的武器

-- 我记得有时候勾 health.SetVal 会用, 判断是不是某个武器击杀的, 用IsDead判断死没死, 再用 afflicter.last_atk_weapon 来获取击杀的武器

---@class ent
---@field last_atk_weapon ent|nil # 上次攻击使用的武器

AddComponentPostInit("combat",
---comment
---@param self component_combat
function(self)
    local old_GetAttacked = self.GetAttacked
    function self:GetAttacked(attacker,damage,weapon,stimuli,spdamage,...)
        if attacker then
            attacker.last_atk_weapon = weapon
        end
        return old_GetAttacked ~= nil and old_GetAttacked(self,attacker,damage,weapon,stimuli,spdamage,...) or nil
    end
end)