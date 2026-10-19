---@diagnostic disable: lowercase-global, undefined-global, trailing-space

local modid = '%(modid)s'

local data,data2 = _require('core_'..modid..'/data/recipes')

API.RECIPE:main(data,data2)

