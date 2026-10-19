-- 需要开启: modimport('scripts/core_%(modid)s/managers/participate_kill.lua') -- 功能(无需修改): 联合击杀(参与击杀), 判断生物死亡时, 某个玩家有没有贡献伤害(参与战斗)
-- 请额外查看组件: %(modid)s_killability

---@class data_%(modid)s_killability
---@field id data_%(modid)s_killability_id # 用作字段名的id
---@field kill_prefab PrefabID[] # 击杀的prefab,可以填多个,注意所有表中的 prefab `不可以重复`
---@field testfn_extra nil|(fun(player:ent,victim:ent):boolean) # 额外判断是否满足击杀条件的函数,比如克劳斯会用到 判断二阶段的
---@field fn_both nil|fun(player:ent) # 击杀时 组件加载时 都会触发的函数, 这个函数会先执行
---@field fn nil|fun(player:ent,victim:ent|nil,iskiller:boolean) # 击杀时触发的函数
---@field fn_load nil|fun(player:ent) # 组件加载时触发的函数
---@field set_netvar boolean|nil # 是否设置为网络变量, 默认为否(设置成true时, 可以用于replica组件中的判断

---@alias data_%(modid)s_killability_id data_%(modid)s_killability_id # killability id 枚举
---| 'avoid_firedmg' 


---@type {data:data_%(modid)s_killability[],_dict:table<PrefabID,data_%(modid)s_killability_id>,_data_map:table<data_%(modid)s_killability_id,data_%(modid)s_killability>}
local main = {
    -- 只填这张表
    data = {
        -- {
        --     id = 'avoid_firedmg',
        --     kill_prefab = {'dragonfly'},
        --     fn_both = function (player)
        --         if player and player.components.health then
        --             player.components.health.externalfiredamagemultipliers:SetModifier(player,0,'%(modid)s_kill_ability_dragonfly')
        --         end
        --     end,
        -- }
    },

    _dict = {},
    _data_map = {},
}

for _,v in ipairs(main.data) do
    for _,prefab in ipairs(v.kill_prefab) do
        main._dict[prefab] = v.id
    end
    main._data_map[v.id] = v
end

return main