---@type {main:table<PrefabID,data_trade_item[]>,map:table<PrefabID,table<PrefabID,data_trade_item_fixed>>}
local tradedata = {}

---只填此表
tradedata.main = {
    -- sword_lunarplant = {
    --     { -- 1. 这是一个给`亮茄剑`金子加1点伤害的简单升级,最大值不填则无限升级
    --         prefab = 'goldnugget',
    --         max = 5,
    --         str = '增加物理伤害',
    --         state = 'dolongaction',
    --         fn = function(item,trader,doer,after_num)
    --             if trader.components.weapon then
    --                 trader.components.weapon.damage = trader.components.weapon.damage + 1
    --             end
    --         end,
    --         fn_load = function (trader, total_num)
    --             if trader.components.weapon then
    --                 trader.components.weapon.damage = trader.components.weapon.damage + total_num
    --             end
    --         end
    --     },
    --     { -- 2. 这是一个给`亮茄剑`1个燧石增加1点位面伤害的升级, 由于没填最大值, 因此可以无限升级
    --         prefab = 'flint',
    --         str = '增加位面伤害',
    --         fn = function(item,trader,doer,after_num)
    --             if doer.components.talker then
    --                 doer.components.talker:Say('你的武器增加了1点位面伤害')
    --             end
    --             if trader.components.planardamage then
    --                 trader.components.planardamage:AddBonus(trader,after_num,'upgrade_by_myself')
    --             end
    --         end,
    --         fn_load = function (trader, total_num)
    --             if trader.components.planardamage then
    --                 trader.components.planardamage:AddBonus(trader,total_num,'upgrade_by_myself')
    --             end
    --         end
    --     }
    -- },
}

tradedata.map = {}
for target,tbl in pairs(tradedata.main) do
    tradedata.map[target] = {}
    ---@cast tbl data_trade_item_fixed
    for i,v in ipairs(tbl) do
        tradedata.map[target][v.prefab] = v
        v.index = i
    end
end

return tradedata