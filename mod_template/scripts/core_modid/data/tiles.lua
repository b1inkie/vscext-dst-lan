-- 美工部分:
-- 1. 地皮图片(不用手动加载): levels/texture/键.png
-- 2. 地皮掉落物库存图片xml和tex(不用手动加载和注册,框架有自动加载和注册): images/inventoryimages/turf_键.xml , turf_键.tex
-- 3. 地皮掉落物动画(不用手动加载,框架有自动加载): anim/turf_键.zip

-- 代码部分:
-- 预制物id为: `turf_键`
-- 地皮掉落物预制物不用手动制作
-- 写好配方和本地化即可

local tiles = { -- 键 为地皮id, `turf_键` 为地皮掉落物prefab, 如果你的动画和库存图片命名都是按照下述规则并且没有其他特殊要求的话, 这张表留空即可
    -- webbert_tile_purplesky = {},
}

local fixed_tiles = {}


for k, v in pairs(tiles) do
    v.key = v.key or k -- 自定义名称 这个不需要关心 当作数据表的标记吧
    v.title_name = v.title_name or string.upper(k) --地皮名称
    v.land = v.land or "LAND"
    v.texture = v.texture or "carpet" -- 边缘纹理 没有 就用原版 牛毛地毯 carpet 棋盘 blocky 岩石 rocky
    v.noise_texture = v.noise_texture or k -- 地皮纹理 levels/texture 的tex名称
    v.runsound = v.runsound or "dontstarve/movement/run_marble"
    v.walksound = v.walksound or "dontstarve/movement/walk_marble"
    v.snowsound = v.snowsound or "dontstarve/movement/run_ice"
    v.mudsound = v.mudsound or "dontstarve/movement/run_mud"
    v.no_fire_spread = v.no_fire_spread == true and true or false -- 阻止火焰蔓延
    v.flooring = v.flooring == true and true or false -- 标记为true则上面不能生长植物
    v.hard = v.hard == true and true or false -- 标记为true则上面不可种植植物
    v.roadways = v.roadways == true and true or false -- 标记为true则玩家在上面可以加速，类似于卵石路
    v.cannotbedug = v.cannotbedug == true and true or false -- 标记为true则不能挖掉
    v.mini_name = v.mini_name or "map_edge" -- 懒得管就这里默认
    v.mini_noise_texture = v.mini_noise_texture or k -- 小地图图片 地图上面显示的区块颜色
    v.product = v.product or k -- 掉落物的代码为 `turf_`..k , 预制物自动生成的不用自己写
    v.product_anim = v.product_anim or "idle" -- idle状态的动画名称
    v.product_bank_build = v.product_bank_build or ("turf_"..k) -- 动画包的build和bank
    -- v.product_pickupsound = v.product_pickupsound or "vegetation_grassy" -- 地皮被捡起来的声音 或许
    if v.dst_lan == nil then
        v.dst_lan = {}
    end
    v.dst_lan.atlas = v.dst_lan.atlas or ('images/inventoryimages/turf_'..k..'.xml') -- 库存图片xml
    v.dst_lan.image = v.dst_lan.image or ('turf_'..k..'.tex') -- 库存图片tex

    table.insert(fixed_tiles, v)
end

return fixed_tiles
