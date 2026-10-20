---@diagnostic disable: lowercase-global, undefined-global, trailing-space, undefined-field

local modid = '%(modid)s'

local require_to_env = function(modulename)
    local result = kleiloadlua(env.MODROOT .. "scripts/" .. modulename .. ".lua")
    setfenv(result, env.env)

    return result()
end

API = {}

-- 载入模块到mod环境

---@type api_recipe
API.RECIPE = require_to_env('core_'..modid..'/api/recipe')
---@type api_componentaction
API.CA = require_to_env('core_'..modid..'/api/componentaction')
---@type api_dish
API.DISH = require_to_env('core_'..modid..'/api/dish')
---@type api_stack
API.STACK = require_to_env('core_'..modid..'/api/stack')
---@type api_container
API.CONTAINER = require_to_env('core_'..modid..'/api/container')
---@type api_keyhandler
API.KEYHANDLER = require_to_env('core_'..modid..'/api/keyhandler')
---@type api_badge
API.BADGE = require_to_env('core_'..modid..'/api/badge')
---@type api_changeactionsg
API.CHANGEACTIONSG = require_to_env('core_'..modid..'/api/changeactionsg')