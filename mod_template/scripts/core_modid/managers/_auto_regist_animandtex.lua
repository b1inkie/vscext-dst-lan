-- show
-- (必须)无需关心: 帮助其他框架载入材质和注册用的

-- 地皮
local data_tiles = require('core_%(modid)s/data/tiles')
for _, data in pairs(data_tiles) do
    table.insert(Assets,Asset("ANIM","anim/"..data.product_bank_build..".zip"))
    table.insert(Assets,Asset("ATLAS",data.dst_lan.atlas))
    RegisterInventoryItemAtlas(data.dst_lan.atlas,data.dst_lan.image)
end

-- 料理
local data_dishes = require('core_%(modid)s/data/dishes')
for _,v in pairs(data_dishes or {}) do
    local cookbook_atlas = v.cookbook_atlas
    if cookbook_atlas then
        table.insert(Assets,Asset("ATLAS",cookbook_atlas))
    end
end