-- hide
-- 功能(无需修改): 本文件用来管理,装备耐久用尽时的逻辑
-- 还需要启用 modmain 中的 `modimport('scripts/core_'..modid..'/callers/caller_ca.lua')`
-- 例如 耐久用尽自动卸下, 不允许装备等, 数据填写在 `TUNING.MOD_%(modid_upper)s.REPAIR_COMMON` 中,本文件不需要做任何修改

local db = TUNING.MOD_%(modid_upper)s.REPAIR_COMMON

for k,v in pairs(db) do
    if v.autounequip_whennodurability or v.cantequip_whennodurability then
        if v.type == 'finiteuses' then
            AddPrefabPostInit(k,function (inst)
                if not TheWorld.ismastersim then
                    return inst
                end
                if inst.components.finiteuses then
                    local old_onfinished = inst.components.finiteuses.onfinished
                    function inst.components.finiteuses.onfinished(this,...)
                        if v.autounequip_whennodurability then
                            SUGAR_%(modid)s:unequipItem(this)
                        end
                        if v.cantequip_whennodurability then
                            inst:AddOrRemoveTag(k..'_nodurability',true)
                        end
                        return old_onfinished ~= nil and old_onfinished(this,...) or nil
                    end
                end
            end)
        elseif v.type == 'armor' then
            AddPrefabPostInit(k,function (inst)
                if not TheWorld.ismastersim then
                    return inst
                end
                if inst.components.armor then
                    local old_onfinished = inst.components.armor.onfinished
                    function inst.components.armor.onfinished(this,...)
                        if v.autounequip_whennodurability then
                            SUGAR_%(modid)s:unequipItem(this)
                        end
                        if v.cantequip_whennodurability then
                            inst:AddOrRemoveTag(k..'_nodurability',true)
                        end
                        return old_onfinished ~= nil and old_onfinished(this,...) or nil
                    end
                end
            end)
        elseif v.type == 'fueled' then
            AddPrefabPostInit(k,function (inst)
                if not TheWorld.ismastersim then
                    return inst
                end
                if inst.components.fueled then
                    local old_depleted = inst.components.fueled.depleted
                    function inst.components.fueled.depleted(this,...)
                        if v.autounequip_whennodurability then
                            SUGAR_%(modid)s:unequipItem(this)
                        end
                        if v.cantequip_whennodurability then
                            inst:AddOrRemoveTag(k..'_nodurability',true)
                        end
                        return old_depleted ~= nil and old_depleted(this,...) or nil
                    end
                end
            end)
        end
    end

end

AddComponentPostInit('equippable',
---comment
---@param self component_equippable
function (self)
    local old_IsRestricted = self.IsRestricted
    function self:IsRestricted(target,...)
        local prefab = self.inst.prefab
        if prefab and db[prefab] and db[prefab].cantequip_whennodurability then
            if self.inst:HasTag(prefab..'_nodurability') then
                return true
            end
        end
        return old_IsRestricted(self,target,...)
    end
end)

AddClassPostConstruct("components/equippable_replica",
---comment
---@param self replica_equippable
function(self)
    local old_IsRestricted = self.IsRestricted
    function self:IsRestricted(target,...)
        local prefab = self.inst.prefab
        if prefab and db[prefab] and db[prefab].cantequip_whennodurability then
            if self.inst:HasTag(prefab..'_nodurability') then
                return true
            end
        end
        return old_IsRestricted(self,target,...)
    end
end)