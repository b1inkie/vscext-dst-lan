---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---require module in my own mod
---@param path string path to module
---@return any
---@nodiscard
_require = function(path)
    return kleiloadlua(env.MODROOT .. "scripts/" .. path .. ".lua")()
end
setfenv(_require, env.env)
