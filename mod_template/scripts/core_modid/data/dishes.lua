---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---@type data_dish
local dishes = {} -- 键为料理名的料理定义表

-- 我只是一个例子,请把我注释掉
-- dishes.lan_m_chips = {
--     test = function(cooker, names, tags) -- 料理的测试函数，条件进行数值比较前必须判空
--         return ((names.potato or 0) + (names.potato_cooked or 0)) == 3 and (names.butter or 0) == 1
--     end,
--     weight = 10, -- 食谱权重
--     priority = 99, -- @Runar: 料理优先级，严格的测试函数配合设定合理的料理优先级才能铸就好的料理。无端99还条件简单的无疑是给自己和其他模组添麻烦
--     foodtype = FOODTYPE.VEGGIE, -- 食物类型
--     perishtime = 7, --腐烂时间/天
--     hunger = 20,
--     sanity = 1,
--     health = 1,
--     cooktime = 5, -- 烹饪时间/s
--     floater = {'med', nil, 0.55}, -- 设置料理漂浮水面的数据
--     potlevel = "low", -- 动画在烹饪锅的位置高低,建议一个mod中所有料理固定一个值
--     -- prefabs = {}, -- 该料理被注册为预制物之前需要先加载的预制物
--     -- tags = { "honeyed" }, -- 将被添加到预制物的tags
--     -- oneat_desc = "juice!", -- 烹饪指南中会显示的描述语
--     oneatenfn = function(inst, eater) -- 食用后执行的函数，在此实现buff
--         -- eater:AddDebuff("buff_electricattack", "buff_electricattack")
--     end,
--     -- card_def = {ingredient = {{ "potato", 3 }, { "butter", 1 }}}, -- 将生成对应的食谱卡
--     -- imagename = "lan_m_chips", -- 贴图,不写则用prefab名
--     -- atlasname = "images/inventoryimages/lan_m_chips.xml", -- 图集,不写则用inventoryimages
--     -- cookbook_tex = "lan_m_chips_cookbook", -- 烹饪指南中显示的图片名,不写则用prefab名
--     -- cookbook_atlas = "images/inventoryimages/lan_m_chips_cookbook.xml", -- 烹饪指南中显示的图片图集,不写则用inventoryimages

--     lan = {
--         -- noedible = true,
--         -- nostackable = true,
--         -- nospiced = true,
--     },
    

--     -- isMasterfood = true, -- 是否大厨料理
--     -- maxstacksize = 40, -- 最大堆叠数量 不清楚的童鞋不要填这一项
--     -- onperishreplacement = nil, -- 腐烂产物，默认为腐烂物
--     -- perishfn = nil, -- 腐烂时的回调函数

-- }

for k, v in pairs(dishes) do
    v.name = k -- 设置料理名
    v.basename = k -- 设置调味料理基础名
    v.weight = v.weight or 1 -- 设置料理权重
    v.priority = v.priority or 0 -- 设置料理优先级
    v.perishtime = (v.perishtime or 3)*TUNING.TOTAL_DAY_TIME
    v.cooktime = (v.cooktime or 15)/TUNING.BASE_COOK_TIME
    v.potlevel = v.potlevel or 'low' -- 贴图相对位置 
    v.overridebuild = v.overridebuild or k -- 设置料理锅上动画（贴图）所在的build压缩包（有时build名不一定为压缩包名）
    v.floater = v.floater or { "small", .05, .7 } -- 设置料理漂浮数据
    v.mod_%(modid)s = true -- 确定为模组料理便于本模组内进行调味处理，换个名也可
    v.cookbook_tex = (v.cookbook_tex or k) .. '.tex' -- 烹饪指南tex名，不设置则为prefab名
    v.cookbook_atlas = v.cookbook_atlas or ("images/inventoryimages/" .. k .. ".xml") -- 烹饪指南图集
    -- v.cookbook_catogory = "mod" -- 料理在烹饪指南中所处的目录。后续定义中被确认为模组料理，写了大概率不生效
    v.imagename = v.imagename or k -- 用于prefab中设置贴图名
    v.atlasname = v.atlasname or ("images/inventoryimages/" .. k .. ".xml") -- 用于指定库存贴图图集
    v.oneat_desc = v.oneat_desc or STRINGS.NAMES[string.upper(k)] or k -- 添加描述

    
    v.lan = v.lan or {}
    v.lan.noedible = v.lan.noedible or false
    v.lan.nostackable = v.lan.nostackable or false
    v.lan.noperishable = v.lan.noperishable or false
    v.lan.nospiced = v.lan.nospiced or false
end

return dishes