-- hide
-- 功能(无需修改): alt写的修改攻速模块 修正版

-- ---@type SourceModifierList
-- local SourceModifierList = require("util/sourcemodifierlist")

-- ---@class ent
-- ---@field %(modid)s_atkspeedmodifier_val netvar
-- ---@field %(modid)s_atkspeedmodifier_modifier SourceModifierList
-- ---@field Modifier_%(modid)s_atkspeedmodifier fun(self,src:ent,m:number,key:string) # 直接在服务器调用这个实体的方法,来增加攻速,注意是 加算修饰
-- ---@field RemoveModifier_%(modid)s_atkspeedmodifier fun(self,src:ent,key:string) # 在服务器调用这个实体的方法,来移除攻速修饰

-- AddPlayerPostInit(function (inst)
--     inst.%(modid)s_atkspeedmodifier_val = net_float(inst.GUID, "%(modid)s_atkspeedmodifier")
--     if not TheWorld.ismastersim then
--         return inst
--     end
--     inst.%(modid)s_atkspeedmodifier_modifier = SourceModifierList(inst,0,SourceModifierList.additive)
--     function inst:Modifier_%(modid)s_atkspeedmodifier(src,m,key)
--         inst.%(modid)s_atkspeedmodifier_modifier:SetModifier(src,m,key)
--         local res = inst.%(modid)s_atkspeedmodifier_modifier:Get()
--         inst.%(modid)s_atkspeedmodifier_val:set(res)
--     end
--     function inst:RemoveModifier_%(modid)s_atkspeedmodifier(src,key)
--         inst.%(modid)s_atkspeedmodifier_modifier:RemoveModifier(src,key)
--         local res = inst.%(modid)s_atkspeedmodifier_modifier:Get()
--         inst.%(modid)s_atkspeedmodifier_val:set(res)
--     end
-- end)


-- AddComponentPostInit("playervision", function(self)
--     local player = self.inst
--     local doer = player
--     local orangeperiod
--     local function isAttackingSG(inst, statename)
--         return statename == "attack" or inst.sg and inst.sg:HasStateTag("attack")
--             and inst.sg:HasStateTag("abouttoattack")
--     end
--     doer:ListenForEvent("newstate",
--     ---comment
--     ---@param inst ent
--     ---@param data any
--     function(inst, data)
--         if not inst.sg then return end
--         local statename = data and data.statename
--         if inst.%(modid)s_remove_sgtag_task then
--             inst.%(modid)s_remove_sgtag_task:Cancel()
--             inst.AnimState:SetDeltaTimeMultiplier(1)
--             if orangeperiod then
--                 local combat = inst.components.combat or inst.replica.combat
--                 combat.min_attack_period = orangeperiod
--             end
--         end
--         if isAttackingSG(inst, statename) then
--             local timeout = inst.sg.timeout or 0.5 --防止某些模组没写timeout
--             local combat = inst.components.combat or inst.replica.combat
--             orangeperiod = orangeperiod or combat.min_attack_period or TUNING.WILSON_ATTACK_PERIOD
--             local orange_attackspeed = 1 / timeout -- 2.5
--             -- local new_attackspeed = orange_attackspeed * (inst.MOD_LOL_WP_ATKSPEED or 1)
--             local res = (inst.%(modid)s_atkspeedmodifier_modifier and inst.%(modid)s_atkspeedmodifier_modifier:Get()) or (inst.%(modid)s_atkspeedmodifier_val and inst.%(modid)s_atkspeedmodifier_val:value()) or 0
--             res = res + 1
--             local new_attackspeed = orange_attackspeed * res
--             local newperiod = 1 / new_attackspeed
--             combat.min_attack_period = newperiod
--             inst.AnimState:SetDeltaTimeMultiplier(math.min(2.5, (new_attackspeed / orange_attackspeed)))
--             inst.%(modid)s_remove_sgtag_task = inst:DoTaskInTime(newperiod,
--                 function()
--                     inst.sg:RemoveStateTag("attack")
--                     inst.sg:AddStateTag("idle")
--                     if TheWorld.ismastersim then
--                         inst:PerformBufferedAction()
--                     end
--                     inst.sg:RemoveStateTag("abouttoattack")
--                 end)
--         end
--     end)
-- end)




---@type SourceModifierList
local SourceModifierList = require("util/sourcemodifierlist")

---@class ent
---@field common_atkspeedmodifier_val netvar
---@field common_atkspeedmodifier_modifier SourceModifierList
---@field Modifier_common_atkspeedmodifier fun(self,src:ent,m:number,key:string) # 直接在服务器调用这个实体的方法,来增加攻速,注意是 加算修饰
---@field RemoveModifier_common_atkspeedmodifier fun(self,src:ent,key:string) # 在服务器调用这个实体的方法,来移除攻速修饰

if TUNING.DST_LAN_FLAG == nil then
    TUNING.DST_LAN_FLAG = {}
end

if not TUNING.DST_LAN_FLAG.alt_atkspeed then
    TUNING.DST_LAN_FLAG.alt_atkspeed = true

    AddPlayerPostInit(function (inst)
        inst.common_atkspeedmodifier_val = net_float(inst.GUID, "common_atkspeedmodifier")
        if not TheWorld.ismastersim then
            return inst
        end
        inst.common_atkspeedmodifier_modifier = SourceModifierList(inst,0,SourceModifierList.additive)
        function inst:Modifier_common_atkspeedmodifier(src,m,key)
            inst.common_atkspeedmodifier_modifier:SetModifier(src,m,key)
            local res = inst.common_atkspeedmodifier_modifier:Get()
            inst.common_atkspeedmodifier_val:set(res)
        end
        function inst:RemoveModifier_common_atkspeedmodifier(src,key)
            inst.common_atkspeedmodifier_modifier:RemoveModifier(src,key)
            local res = inst.common_atkspeedmodifier_modifier:Get()
            inst.common_atkspeedmodifier_val:set(res)
        end
    end)


    AddComponentPostInit("playervision", function(self)
        local player = self.inst
        local doer = player
        local orangeperiod
        local function isAttackingSG(inst, statename)
            return statename == "attack" or inst.sg and inst.sg:HasStateTag("attack")
                and inst.sg:HasStateTag("abouttoattack")
        end
        doer:ListenForEvent("newstate",
        ---comment
        ---@param inst ent
        ---@param data any
        function(inst, data)
            if not inst.sg then return end
            local statename = data and data.statename
            if inst.common_remove_sgtag_task then
                inst.common_remove_sgtag_task:Cancel()
                inst.AnimState:SetDeltaTimeMultiplier(1)
                if orangeperiod then
                    local combat = inst.components.combat or inst.replica.combat
                    combat.min_attack_period = orangeperiod
                end
            end
            if isAttackingSG(inst, statename) then
                ---@diagnostic disable-next-line: undefined-field
                local timeout = inst.sg.timeout or 0.5 --防止某些模组没写timeout
                local combat = inst.components.combat or inst.replica.combat
                orangeperiod = orangeperiod or combat.min_attack_period or TUNING.WILSON_ATTACK_PERIOD
                local orange_attackspeed = 1 / timeout -- 2.5
                -- local new_attackspeed = orange_attackspeed * (inst.MOD_LOL_WP_ATKSPEED or 1)
                local res = (inst.common_atkspeedmodifier_modifier and inst.common_atkspeedmodifier_modifier:Get()) or (inst.common_atkspeedmodifier_val and inst.common_atkspeedmodifier_val:value()) or 0
                res = res + 1
                local new_attackspeed = orange_attackspeed * res
                local newperiod = 1 / new_attackspeed
                combat.min_attack_period = newperiod
                inst.AnimState:SetDeltaTimeMultiplier(math.min(2.5, (new_attackspeed / orange_attackspeed)))
                ---@diagnostic disable-next-line: inject-field
                inst.common_remove_sgtag_task = inst:DoTaskInTime(newperiod,
                    function()
                        if inst.sg then
                            inst.sg:RemoveStateTag("attack")
                            inst.sg:AddStateTag("idle")
                        end
                        if TheWorld.ismastersim then
                            inst:PerformBufferedAction()
                        end
                        if inst.sg then inst.sg:RemoveStateTag("abouttoattack") end
                    end)
            end
        end)
    end)
end
