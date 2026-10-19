local trade_data = require('core_%(modid)s/data/trade')

---@class components
---@field %(modid)s_trader component_%(modid)s_trader # 这个组件是为 通用交易 功能服务的 <br> 禁止自己添加这个组件, 方法可以调用

local function on_val(self, value)
    self.inst.replica.%(modid)s_trader.val:set(value)
end

---@class component_%(modid)s_trader
---@field inst ent
---@field val string
---@field _last_decode_res integer[]|nil
local %(modid)s_trader = Class(
---@param self component_%(modid)s_trader
---@param inst ent
function(self, inst)
    self.inst = inst
    self.val = ''
    self._last_decode_res = {}

    local count = 0
    for _,v in pairs(trade_data.map[self.inst.prefab]) do
        count = count + 1
        self._last_decode_res[count] = 0
    end
    self.val = self:encode(nil,self._last_decode_res)
end,
nil,
{
    val = on_val,
})

function %(modid)s_trader:OnSave()
    local data = {}
    data.val = self.val
    return data
end

function %(modid)s_trader:OnLoad(data)
    if data and data.val then
        self.val = data.val
        self._last_decode_res = self:decode(self.val)
        if self._last_decode_res then
            for i,num in ipairs(self._last_decode_res) do
                local fn_load = trade_data.main[self.inst.prefab][i].fn_load
                if fn_load then
                    fn_load(self.inst,num)
                end
            end
        end
    end
end

---通过交易获得了一个物品
---@param item ent
---@param doer ent
---@return boolean
function %(modid)s_trader:AddOne(item,doer)
    local fixed = trade_data.map[self.inst.prefab] and trade_data.map[self.inst.prefab][item.prefab] or nil
    if fixed then
        local i,max = fixed.index,fixed.max
        self._last_decode_res[i] = (self._last_decode_res[i] or 0) + 1
        local fn = fixed.fn
        if fn then fn(item,self.inst,doer,self._last_decode_res[i]) end
        self.val = self:encode(nil,self._last_decode_res)

        SUGAR_%(modid)s:consumeOneItem(item)
    end
    return true
end

---获取某个物品的当前数量
---@param prefab PrefabID
---@return integer
---@nodiscard
function %(modid)s_trader:GetCurrentNum(prefab)
    local index = trade_data.map[self.inst.prefab][prefab].index
    if self._last_decode_res then
        return self._last_decode_res[index] or 0
    else
        return self:decode(self.val)[index] or 0
    end
end

---comment
---@param encoded_str string
---@param separator '|'|nil
---@return integer[]
---@nodiscard
function %(modid)s_trader:decode(encoded_str, separator)
    local parts = {}
    for part in string.gmatch(encoded_str, "[^" .. (separator or '|') .. "]+") do
        table.insert(parts, tonumber(part))
    end
    return parts
end

---comment
---@param separator '|'|nil 
---@param args integer[]
---@return string
---@nodiscard
function %(modid)s_trader:encode(separator, args)
    return table.concat(args, separator or '|')
end

return %(modid)s_trader