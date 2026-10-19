---@diagnostic disable: lowercase-global, undefined-global, trailing-space

local modid = '%(modid)s'

local data = _require('core_'..modid..'/data/keyhandlers')

API.KEYHANDLER:main(data)