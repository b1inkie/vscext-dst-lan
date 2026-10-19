---@diagnostic disable: undefined-global
local prefab_id = 'myspear' -- prefab (前缀)
local mid = '_skin_' -- 中间名

-- 这一行设置默认皮肤的库存图片
%(modid_upper)s_API.MakeItemSkinDefaultImage(prefab_id, "images/inventoryimages/"..prefab_id..".xml", prefab_id)

-- 一份带注释的模板
-- local suffix = 'goldenspear' -- 后缀
-- myspear_skin_goldenspear -- 前缀 + 中间名 + 后缀 = 完整皮肤名
-- %(modid_upper)s_API.MakeItemSkin(prefab_id,prefab_id..mid..suffix,{
--     name = STRINGS.MOD_%(modid_upper)s.SKIN_API.SKINS[prefab_id][suffix], -- 皮肤译名
--     rarity = STRINGS.MOD_%(modid_upper)s.SKIN_API.rare.elegent, -- 珍惜度 
--     raritycorlor = TUNING.MOD_%(modid_upper)s.SKIN_API.rare.elegent, -- 珍惜度颜色{R,G,B,A}
--     atlas = "images/inventoryimages/"..prefab_id..mid..suffix..".xml", -- 库存图片xml
--     image = prefab_id..mid..suffix, -- 库存 tex
--     build = prefab_id..mid..suffix, -- 皮肤build
--     bank =  prefab_id..mid..suffix, -- 皮肤bank
--     anim = "idle", -- 皮肤动画
--     animcircle = true, -- 动画循环
--     basebuild = prefab_id, -- 默认build
--     basebank =  prefab_id, -- 默认bank
--     baseanim = "idle", -- 默认动画
--     baseanimcircle = true, -- 默认动画循环
--     -- dst_lan = { -- 本插件添加的功能,以后会放在这个表里
--     --     whitelist = true, -- 是否设置白名单解锁, 如果这里设置为 true, 你还需要去 scripts/core_%(modid)s/data/unlock_skins.lua 中添加该皮肤的玩家白名单
--     -- }
-- })

-- 一份不带注释的模板
-- local suffix = 'goldenspear'
-- %(modid_upper)s_API.MakeItemSkin(prefab_id,prefab_id..mid..suffix,{
--     name = STRINGS.MOD_%(modid_upper)s.SKIN_API.SKINS[prefab_id][suffix],
--     rarity = STRINGS.MOD_%(modid_upper)s.SKIN_API.rare.elegent,
--     raritycorlor = TUNING.MOD_%(modid_upper)s.SKIN_API.rare.elegent,
--     atlas = "images/inventoryimages/"..prefab_id..mid..suffix..".xml",
--     image = prefab_id..mid..suffix,
--     build = prefab_id..mid..suffix,
--     bank =  prefab_id..mid..suffix,
--     anim = "idle",
--     animcircle = true,
--     basebuild = prefab_id,
--     basebank =  prefab_id,
--     baseanim = "idle",
--     baseanimcircle = true,
--     -- dst_lan = {
--     --     whitelist = true,
--     -- }
-- })

