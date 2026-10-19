-- hide
-- 管理: 用这个文件管理伤害处理吧

AddComponentPostInit('combat',
---comment
---@param self component_combat
function (self)
    if self.inst.components.%(modid)s_dmg_modifier == nil then
       self.inst:AddComponent('%(modid)s_dmg_modifier')
    end


    local old_GetAttacked = self.GetAttacked
    function self:GetAttacked(attacker,damage,weapon,stimuli,spdamage,...)
        local victim = self.inst
        if spdamage == nil then
            spdamage = {}
        end
        if damage == nil then
            damage = 0
        end
        -- 如果无敌,则不继续执行, 需要加载 invincible.lua 文件
        if victim and victim.components.health and victim.components.health.CheckIsLanInvincible then
            if victim.components.health:CheckIsLanInvincible() then
                victim:PushEvent("blocked", { attacker = attacker })
                return false
            end
        end
        -- 筛选一些情况,不用继续计算加成等
        local allow_to_continue = true
        if allow_to_continue then
            if attacker then
                if attacker.components.%(modid)s_dmg_modifier then
                    -- 先执行回调函数
                    attacker.components.%(modid)s_dmg_modifier:_RunOnHitAlways(victim)
                    -- 允许物理伤害加算加成
                    local physical_add = attacker.components.%(modid)s_dmg_modifier.physical:Get()
                    damage = damage + physical_add
                    -- 允许特殊伤害加算加成
                    for k,v in pairs(attacker.components.%(modid)s_dmg_modifier.spdamage) do
                        local spd_add = v:Get()
                        spdamage[k] = (spdamage[k] or 0) + spd_add
                    end
                    -- 允许物理伤害乘算加成
                    local physical_mult = attacker.components.%(modid)s_dmg_modifier.mult_physical:Get()
                    damage = damage * physical_mult
                    -- 允许特殊伤害乘算加成
                    for k,v in pairs(attacker.components.%(modid)s_dmg_modifier.mult_spdamage) do
                        local spd_mult = v:Get()
                        spdamage[k] = (spdamage[k] or 0) * spd_mult
                    end

                    -- 暴击最后处理
                    if math.random() < attacker.components.%(modid)s_dmg_modifier:_GetCriticalChanceWithModifier() then
                        local dmgmult = attacker.components.%(modid)s_dmg_modifier:_GetCriticalDamageWithModifier()
                        damage = damage * dmgmult
                        for k,_ in pairs(spdamage) do
                            spdamage[k] = (spdamage[k] or 0) * dmgmult
                        end
                        -- 执行暴击回调函数
                        attacker.components.%(modid)s_dmg_modifier:_RunOnCriticalHit(victim)
                    end
                end
            end
        end
        return old_GetAttacked(self,attacker,damage,weapon,stimuli,spdamage,...)
    end
end)


AddComponentPostInit('health',
---comment
---@param self component_health
function (self)
    local old_DoDelta = self.DoDelta
    function self:DoDelta(amount,overtime,cause,ignore_invincible,afflicter,ignore_absorb,...)
        if self.CheckIsLanInvincible ~= nil and self:CheckIsLanInvincible() then
            if amount and amount < 0 then
                return 0
            end
        end
        return old_DoDelta(self,amount,overtime,cause,ignore_invincible,afflicter,ignore_absorb,...)
    end

    local old_SetVal = self.SetVal
    function self:SetVal(val,cause,afflicter,...)
        local old_health = self.currenthealth
        if self.CheckIsLanInvincible ~= nil and self:CheckIsLanInvincible() then
            if val and val < old_health then
                return 0
            end
        end
        return old_SetVal(self,val,cause,afflicter,...)
    end
end)