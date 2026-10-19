-- hide
-- 功能(无需修改): 联合击杀(参与击杀), 判断生物死亡时, 某个玩家有没有贡献伤害(参与战斗)

-- 亲手或参与击杀的人会推 `killed_%(modid)s_participate` 事件, data.iskiller 用于判断是否是击杀者

---@class ent
---@field _%(modid)s_participate_kill_tbl table<ent, boolean> # 联合击杀贡献表

---@class event_data_killed_%(modid)s_participate
---@field victim ent
---@field attacker ent
---@field iskiller boolean # 是: 击杀者, 否: 协助击杀

AddComponentPostInit('combat',
---comment
---@param self component_combat
function (self)
    local old_GetAttacked = self.GetAttacked
    function self:GetAttacked(attacker,damage,weapon,stimuli,spdamage,...)
        local victim = self.inst
        if attacker and attacker:IsValid() then
            if victim then
                if victim._%(modid)s_participate_kill_tbl == nil then
                    victim._%(modid)s_participate_kill_tbl = {}
                end
                victim._%(modid)s_participate_kill_tbl[attacker] = true
            end
        end
        return old_GetAttacked ~= nil and old_GetAttacked(self,attacker,damage,weapon,stimuli,spdamage,...) or nil
    end
end)

AddComponentPostInit("health",
---comment
---@param self component_health
function(self)
    local old_SetVal = self.SetVal
    function self:SetVal(val,cause,afflicter,...)
        local res = old_SetVal ~= nil and {old_SetVal(self,val,cause,afflicter,...)} or {}
        local victim = self.inst
        local max_health = self:GetMaxWithPenalty()
        local min_health = math.min(self.minhealth or 0, max_health)
        if self:IsDead() or self.currenthealth <= min_health then
            if victim and victim._%(modid)s_participate_kill_tbl then
                for attacker,_ in pairs(victim._%(modid)s_participate_kill_tbl) do
                    if attacker and attacker:IsValid() then
                        attacker:PushEvent('killed_%(modid)s_participate', { victim = self.inst, attacker = attacker, iskiller = afflicter ~= nil and afflicter == attacker or false })
                    end
                end
            end
        end
        return unpack(res)
    end
end)