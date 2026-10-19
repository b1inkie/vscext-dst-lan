-- 这个是给玩家的组件 用于修饰 伤害 , 包括简单增伤,暴击等
-- 暴击对物理位面都有效
-- 这个在combat组件中添加

-- 网游常见伤害加成参考:
-- 暴击率: 一般是加算,例如有2个暴击率加成分别为 0.2,0.4 的物品, 最终加成为 0.6
-- 固定伤害加成(基伤): 加算,并且最先计算,没什么好说的
-- 伤害倍率加成: 一般是乘算,并且在加算之后计算,例如有2个伤害倍率加成分别为 1.2,1.4 的物品, 最终加成为 1.68
-- 攻速加成: 一般是加算

---@type SourceModifierList
local SourceModifierList = require("util/sourcemodifierlist")


---@class components
---@field %(modid)s_dmg_modifier component_%(modid)s_dmg_modifier

---@class component_%(modid)s_dmg_modifier
---@field inst ent
---@field cc number # 暴击几率
---@field cd number # 爆伤倍率
---@field modifier_add_cc SourceModifierList
---@field modifier_add_cd SourceModifierList
---@field modifier_mult_cc SourceModifierList
---@field modifier_mult_cd SourceModifierList
---@field on_critical_hit_fn table<PrefabID,fun(victim:ent)> # 暴击回调函数
---@field on_hit_fn_always table<PrefabID,fun(victim:ent)> # 无论如何都会再击中时触发的函数 最后执行
---@field physical SourceModifierList
---@field spdamage table<spdamage_type,SourceModifierList>
---@field mult_physical SourceModifierList
---@field mult_spdamage table<spdamage_type,SourceModifierList>
local %(modid)s_dmg_modifier = Class(
---@param self component_%(modid)s_dmg_modifier
---@param inst ent
function(self, inst)
    self.inst = inst
    -- self.val = 0

    self.cc = 0
    self.cd = 1

    self.modifier_add_cc = SourceModifierList(self.inst, 0, SourceModifierList.additive)
    self.modifier_add_cd = SourceModifierList(self.inst, 0, SourceModifierList.additive)

    self.modifier_mult_cc = SourceModifierList(self.inst, 1, SourceModifierList.multiply)
    self.modifier_mult_cd = SourceModifierList(self.inst, 1, SourceModifierList.multiply)

    self.on_critical_hit_fn = {}

    self.on_hit_fn_always = {}

    self.physical = SourceModifierList(self.inst, 0, SourceModifierList.additive)
    self.spdamage = {}

    self.mult_physical = SourceModifierList(self.inst, 1, SourceModifierList.multiply)
    self.mult_spdamage = {}
end,
nil,
{
    -- val = on_val,
})

-- function %(modid)s_dmg_modifier:OnSave()
--     return {
--         -- val = self.val
--     }
-- end

-- function %(modid)s_dmg_modifier:OnLoad(data)
--     -- self.val = data.val or 0
-- end

---修饰 暴击相关
---@param attri 'CriticalChance'|'CriticalDamage' # 暴击几率/暴击伤害
---@param modifier_type 'add'|'mult'
---@param source ent|string # 来源: 如果是实体,那么实体被移除时, 该修饰也会被移除
---@param m number
---@param key string
function %(modid)s_dmg_modifier:ModifierCritical(attri,modifier_type,source,m,key)
    if attri == 'CriticalChance' then
        if modifier_type == 'add' then
            self.modifier_add_cc:SetModifier(source,m,key)
        elseif modifier_type == 'mult' then
            self.modifier_mult_cc:SetModifier(source,m,key)
        end
    elseif attri == 'CriticalDamage' then
        if modifier_type == 'add' then
            self.modifier_add_cd:SetModifier(source,m,key)
        elseif modifier_type == 'mult' then
            self.modifier_mult_cd:SetModifier(source,m,key)
        end
    end
end

---移除修饰 暴击相关
---@param attri 'CriticalChance'|'CriticalDamage' # 暴击几率/暴击伤害
---@param modifier_type 'add'|'mult'
---@param source ent|string # 来源: 如果是实体,那么实体被移除时, 该修饰也会被移除
---@param key string
function %(modid)s_dmg_modifier:RemoveModifierCritical(attri,modifier_type,source,key)
    if attri == 'CriticalChance' then
        if modifier_type == 'add' then
            self.modifier_add_cc:RemoveModifier(source,key)
        elseif modifier_type == 'mult' then
            self.modifier_mult_cc:RemoveModifier(source,key)
        end
    elseif attri == 'CriticalDamage' then
        if modifier_type == 'add' then
            self.modifier_add_cd:RemoveModifier(source,key)
        elseif modifier_type == 'mult' then
            self.modifier_mult_cd:RemoveModifier(source,key)
        end
    end
end

---修饰 普通伤害修饰
---@param dmg_type 'physical'|spdamage_type
---@param modifier_type 'add'|'mult'
---@param source ent|string # 来源: 如果是实体,那么实体被移除时, 该修饰也会被移除
---@param m number
---@param key string
function %(modid)s_dmg_modifier:ModifierNormal(dmg_type,modifier_type,source,m,key)
    if modifier_type == 'add' then
        if dmg_type == 'physical' then
            self.physical:SetModifier(source,m,key)
        else
            if self.spdamage[dmg_type] == nil then
                self.spdamage[dmg_type] = SourceModifierList(self.inst, 0, SourceModifierList.additive)
            end
            self.spdamage[dmg_type]:SetModifier(source,m,key)
        end
    elseif modifier_type == 'mult' then
        if dmg_type == 'physical' then
            self.mult_physical:SetModifier(source,m,key)
        else
            if self.mult_spdamage[dmg_type] == nil then
                self.mult_spdamage[dmg_type] = SourceModifierList(self.inst, 1, SourceModifierList.multiply)
            end
            self.mult_spdamage[dmg_type]:SetModifier(source,m,key)
        end
    end
end

---移除修饰 普通伤害修饰
---@param dmg_type 'physical'|spdamage_type
---@param modifier_type 'add'|'mult'
---@param source ent|string # 来源: 如果是实体,那么实体被移除时, 该修饰也会被移除
---@param key string
function %(modid)s_dmg_modifier:RemoveModifierNormal(dmg_type,modifier_type,source,key)
    if modifier_type == 'add' then
        if dmg_type == 'physical' then
            self.physical:RemoveModifier(source,key)
        else
            if self.spdamage[dmg_type] then
                self.spdamage[dmg_type]:RemoveModifier(source,key)
                if self.spdamage[dmg_type]:IsEmpty() then
                    self.spdamage[dmg_type] = nil
                end
            end
        end
    elseif modifier_type == 'mult' then
        if dmg_type == 'physical' then
            self.mult_physical:RemoveModifier(source,key)
        else
            if self.mult_spdamage[dmg_type] then
                self.mult_spdamage[dmg_type]:RemoveModifier(source,key)
                if self.mult_spdamage[dmg_type]:IsEmpty() then
                    self.mult_spdamage[dmg_type] = nil
                end
            end
        end
    end
end

---获取修饰后的暴击几率
---@return number
---@nodiscard
function %(modid)s_dmg_modifier:_GetCriticalChanceWithModifier()
    return ( self.cc + self.modifier_add_cc:Get() ) * self.modifier_mult_cc:Get()
end

---获取修饰后的爆伤倍率
---@return number
---@nodiscard
function %(modid)s_dmg_modifier:_GetCriticalDamageWithModifier()
    return ( self.cd + self.modifier_add_cd:Get() ) * self.modifier_mult_cd:Get()
end

---设置暴击触发函数
---@param id string
---@param fn fun(victim:ent)
function %(modid)s_dmg_modifier:SetOnCriticalHit(id,fn)
    self.on_critical_hit_fn[id] = fn
end

---移除暴击触发函数
---@param id string
function %(modid)s_dmg_modifier:RemoveOnCriticalHit(id)
    self.on_critical_hit_fn[id] = nil
end

---运行所有暴击触发函数
---@param victim ent
function %(modid)s_dmg_modifier:_RunOnCriticalHit(victim)
    for _,v in pairs(self.on_critical_hit_fn) do
        v(victim)
    end
end

---设置 无论如何都会再击中时触发 函数
---@param id string
---@param fn fun(victim:ent)
function %(modid)s_dmg_modifier:SetOnHitAlways(id,fn)
    self.on_hit_fn_always[id] = fn
end

---移除 无论如何都会再击中时触发 的函数
---@param id string
function %(modid)s_dmg_modifier:RemoveOnHitAlways(id)
    self.on_hit_fn_always[id] = nil
end

---运行所有 无论如何都会再击中时触发 函数
---@param victim ent
function %(modid)s_dmg_modifier:_RunOnHitAlways(victim)
    for _,v in pairs(self.on_hit_fn_always) do
        v(victim)
    end
end

return %(modid)s_dmg_modifier