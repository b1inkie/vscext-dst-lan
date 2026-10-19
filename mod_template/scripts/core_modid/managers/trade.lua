-- hide
-- 功能(无需修改,但需要填写其他地方): 添加通用的交易升级功能
-- 必须在 `modmain` 中,启用组件动作 , 即 modimport('scripts/core_'..modid..'/callers/caller_ca.lua')
-- 此处无需做任何更改, 请到 `core_%(modid)s/data/trade.lua` 中进行填表
---@source ../../core_%(modid)s/data/trade.lua:40 
local _______see -- ctrl + 左键 点我快速跳转

local tbl = require('core_%(modid)s/data/trade')

AddReplicableComponent('%(modid)s_trader')

for tar,v in pairs(tbl.map) do
    local itm_num = 0
    for itm,v2 in pairs(v) do
        itm_num = itm_num + 1
        AddPrefabPostInit(itm,function (inst)
            if not TheWorld.ismastersim then
                return inst
            end
            if inst.components.%(modid)s_tradeable == nil then
                inst:AddComponent('%(modid)s_tradeable')
            end
        end)
    end
    AddPrefabPostInit(tar,function (inst)
        if not TheWorld.ismastersim then
            return inst
        end
        if inst.components.%(modid)s_trader == nil then
            inst:AddComponent('%(modid)s_trader')
            local need_encode = {}
            for _i = 1,itm_num do
                table.insert(need_encode,0)
            end
            inst.components.%(modid)s_trader.val = inst.components.%(modid)s_trader:encode(nil,need_encode)
        end
    end)
end

-- 禁止自动装备
AddComponentPostInit('playercontroller',
---@param self component_playercontroller
function (self)
    local old_DoActionAutoEquip = self.DoActionAutoEquip
    function self:DoActionAutoEquip(buffaction,...)
        if buffaction.action == ACTIONS.ACTION_%(modid_upper)s_TRADE then
            return false
        end
        return old_DoActionAutoEquip ~= nil and old_DoActionAutoEquip(self,buffaction,...) or nil
    end
end)