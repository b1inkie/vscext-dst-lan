GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

------------------------------------------------
--------------------动态布局(生成矿物植物等-------
------------------------------------------------

-- ---@type table<PrefabID,table<string,number|(fun(area,prefab,scratchpad):number)>>
-- local map_rooms = {
-- 	my_ore = {
-- 		DragonflyArena = function (area, prefab, scratchpad)
-- 			return 1
-- 		end
-- 	},
-- 	my_plant = {
-- 		LightningBluffOasis = 3,
-- 	}
-- }

-- for obj, tbl in pairs(map_rooms) do
-- 	for room, gen in pairs(tbl) do
-- 		AddRoomPreInit(room, function(self)
-- 			if self.contents.countprefabs == nil then
-- 				self.contents.countprefabs = {}
-- 			end
-- 			self.contents.countprefabs[obj] = gen
-- 		end)
-- 	end
-- end


------------------------------------------------
--------------------地皮(不用修改)---------------
------------------------------------------------

local tiles = require('core_%(modid)s/data/tiles')
-- 地皮纹理文件夹 和 scripts同级  目录固定为： levels/texture
for i, data in pairs(tiles) do
    AddTile(
        data.title_name,            -- 地皮名称
        data.land,                  -- 地皮类型
        {
            ground_name = data.key, -- 自定义名字
        },
        {
            name = data.texture,                -- 边缘样式
            noise_texture = data.noise_texture, -- 地皮图片

            -- 定义在地皮上行走的声音
            runsound = data.runsound,
            walksound = data.walksound,
            snowsound = data.snowsound,
            mudsound = data.mudsound,

            flooring = data.flooring,       -- 标记为true则上面不能生长植物
            hard = data.hard,               -- 标记为true则上面不可种植植物
            roadways = data.roadways,       -- 标记为true则玩家在上面可以加速
            cannotbedug = data.cannotbedug, -- 标记为true则不能挖掉
        },
        {
            name = data.mini_name,
            noise_texture = data.mini_noise_texture, -- 地区区块图片
        },
        -- 挖掉的定义
        {
            name = data.product, -- 掉落物的代码 这里填了之后 会自动生成prefab 并且前面加 truf_ 所以我们还需要去添加它的配方 以及注册贴图
            anim = data.product_anim,
            bank_build = data.product_bank_build,
            -- pickupsound = data.product_pickupsound, -- 如果需要，取消注释
        }
    )
    ChangeTileRenderOrder(WORLD_TILES[data.title_name], WORLD_TILES.FARMING_SOIL)
end
