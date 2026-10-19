---@diagnostic disable: undefined-global

---@class component_combat
---@field SetAttackPeriod fun(self, val: number)
---@field SetAtkPeriodModifier fun(self, source: any, mult: number, key: string)
---@field RemoveAtkPeriodModifier fun(self, source: any, key: string)

local PREFIX_MODIFIER = 'dstlan_atkperiod_'

local GLOBAL_DST_LAN_API_ATK_PERIOD = 'DST_LAN_API_ATK_PERIOD'

---@class api_attackperiod
local dst_lan = {}

---@private
function dst_lan:_hookCombatReplica()
    AddClassPostConstruct("components/combat_replica", function(self)
        self.dstlan_atkperiodmult = net_float(self.inst.GUID, "dstlan_atkperiodmult","onatkspeeddirty")
        self.dstlan_atkperiodmult:set(1)
    end)
end

---@private
function dst_lan:_hookCombat()
    AddComponentPostInit("combat", function(self)
        self.dstlan_atkperiodmodifiers = SourceModifierList(self.inst)
        self.dstlan_orig_min_attack_period = self.min_attack_period
        local p = rawget(self, "_")["min_attack_period"]
        local old_on_map = p[2]
        p[2] = function(self, map)
            if old_on_map ~= nil then
                old_on_map(self, map)
            end
            if self.inst.replica.combat and self.inst.replica.combat.dstlan_atkperiodmult then
                self.inst.replica.combat.dstlan_atkperiodmult:set(self.dstlan_atkperiodmodifiers:Get())
            end
        end

        function self:SetAttackPeriod(val)
            self.dstlan_orig_min_attack_period = val
            self.min_attack_period = self.dstlan_orig_min_attack_period / self.dstlan_atkperiodmodifiers:Get()
        end

        function self:SetAtkPeriodModifier(source, mult, key)
            self.dstlan_atkperiodmodifiers:SetModifier(source, mult, key)
            self.min_attack_period = self.dstlan_orig_min_attack_period / self.dstlan_atkperiodmodifiers:Get()
        end

        function self:RemoveAtkPeriodModifier(source, key)
            self.dstlan_atkperiodmodifiers:RemoveModifier(source, key)
            self.min_attack_period = self.dstlan_orig_min_attack_period / self.dstlan_atkperiodmodifiers:Get()
        end
    end)
end

---@private
function dst_lan:_hookSG()
    AddStategraphPostInit("wilson", function(sg)
        local old_onenter = sg.states["attack"].onenter
        sg.states["attack"].onenter = function (inst,...)
            local res = old_onenter ~= nil and {old_onenter(inst,...)} or {}
            local combat = inst.components.combat
            local timeout = (math.floor(13/(combat.dstlan_atkperiodmodifiers:Get())))*FRAMES
            inst.sg:SetTimeout(timeout)
            inst.AnimState:SetDeltaTimeMultiplier(combat.dstlan_atkperiodmodifiers:Get())
            return unpack(res)
        end

        local old_ontimeout = sg.states["attack"].ontimeout
        sg.states["attack"].ontimeout = function (inst,...)
            inst:PerformBufferedAction()
            inst.sg:RemoveStateTag('abouttoattack')
            return old_ontimeout(inst,...)
        end

        local old_onexit = sg.states["attack"].onexit
        sg.states["attack"].onexit = function (inst,...)
            inst.AnimState:SetDeltaTimeMultiplier(1)
            return old_onexit(inst,...)
        end

    end)
end

---@private
function dst_lan:_hookSGClient()
    AddStategraphPostInit("wilson_client", function(sg)
        local old_onenter = sg.states["attack"].onenter
        sg.states["attack"].onenter = function (inst,...)
            local res = old_onenter ~= nil and {old_onenter(inst,...)} or {}
            local timeout = (math.floor(13/inst.replica.combat.dstlan_atkperiodmult:value()))*FRAMES
            inst.sg:SetTimeout(timeout)
            inst.AnimState:SetDeltaTimeMultiplier(inst.replica.combat.dstlan_atkperiodmult:value())
            return unpack(res)
        end

        local old_ontimeout = sg.states["attack"].ontimeout
        sg.states["attack"].ontimeout = function (inst,...)
            inst:PerformPreviewBufferedAction()
            inst.sg:RemoveStateTag('abouttoattack')
            return old_ontimeout(inst,...)
        end

        local old_onexit = sg.states["attack"].onexit
        sg.states["attack"].onexit = function (inst,...)
            inst.AnimState:SetDeltaTimeMultiplier(1)
            return old_onexit(inst,...)
        end

    end)
end

---装备攻击速度buff
---@param tbl table<string, number> # 装备: 攻速 的键值对
---@private
function dst_lan:SetEquipAtkPeriod(tbl)
    for  k,v in pairs(tbl) do
        AddPrefabPostInit(k, function(inst)
            if not TheWorld.ismastersim then
                return inst
            end
            if inst.components.equippable then
                local old_onequipfn = inst.components.equippable.onequipfn
                inst.components.equippable.onequipfn = function(inst, owner, from_ground, ...)
                    if owner:HasTag("player") and owner.components.combat and owner.components.combat.SetAtkPeriodModifier then
                        owner.components.combat:SetAtkPeriodModifier(inst, v, PREFIX_MODIFIER..k)
                    end
                    return old_onequipfn ~= nil and old_onequipfn(inst, owner, from_ground, ...)
                end
                local old_onunequipfn = inst.components.equippable.onunequipfn
                inst.components.equippable.onunequipfn = function(inst, owner, ...)
                    if owner:HasTag("player") and owner.components.combat and owner.components.combat.SetAtkPeriodModifier then
                        owner.components.combat:RemoveAtkPeriodModifier(inst, PREFIX_MODIFIER..k)
                    end
                    return old_onunequipfn ~= nil and old_onunequipfn(inst, owner, ...)
                end
            end
        end)
    end
end

---角色初始化攻击速度buff
---@param tbl table<string, number> # 角色: 攻速 的键值对
---@private
function dst_lan:SetPlayerAtkPeriod(tbl)
    for k, v in pairs(tbl) do
        AddPrefabPostInit(k, function(inst)
            if not TheWorld.ismastersim then
                return inst
            end
            if inst.components.combat and inst.components.combat.SetAtkPeriodModifier then
                inst.components.combat:SetAtkPeriodModifier(inst, v, PREFIX_MODIFIER..k)
            end
        end)
    end
end

---应用攻击速度数据表
---@param data_tbl data_attackperiod # 攻击速度数据表
---@private
function dst_lan:ApplyAtkPeriodData(data_tbl)
    local tbl_avatar = data_tbl.avatar
    if tbl_avatar then
        self:SetPlayerAtkPeriod(tbl_avatar)
    end
    local tbl_equip = data_tbl.equippment
    if tbl_equip then
        self:SetEquipAtkPeriod(tbl_equip)
    end
end

---一定要初始化的函数
---@param data_tbl data_attackperiod # 攻击速度数据表
function dst_lan:main(data_tbl)
    if rawget(GLOBAL,GLOBAL_DST_LAN_API_ATK_PERIOD) == nil then
        rawset(GLOBAL,GLOBAL_DST_LAN_API_ATK_PERIOD,true)

        self:_hookCombatReplica()
        self:_hookCombat()
        self:_hookSG()
        self:_hookSGClient()

    end

    self:ApplyAtkPeriodData(data_tbl)
end



return dst_lan