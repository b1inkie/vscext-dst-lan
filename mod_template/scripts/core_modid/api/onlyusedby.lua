---@diagnostic disable: lowercase-global, undefined-global, trailing-space

local GLOBAL_DST_LAN_API_ONLY_USED_BY = 'DST_LAN_API_ONLY_USED_BY'

---@class api_onlyusedby
local dst_lan = {
    ---@type string[]
    official_avatars = {
        "wilson","willow","wolfgang","wendy","wx78","wickerbottom","woodie","wes","waxwell","wathgrithr","webber","winona","warly","walter","wanda"
    }
}

---@private
function dst_lan:TraceWithStack(character, root, tab, path)
    local stack = {{tab, path}}
    
    while #stack > 0 do
        local curtbl, curpath = unpack(table.remove(stack))
        
        for k, v in pairs(curtbl) do
            if type(v) == "table" then
                table.insert(curpath, k)
                table.insert(stack, {v, {unpack(curpath)}})
                table.remove(curpath)
            else
                for k2, v2 in pairs(root) do
                    if k2 ~= curpath[1] then
                        local data = v2
                        for i = 2, #curpath do
                            data = data[curpath[i]]
                            if not data then break end
                        end
                        if type(data) == "table" then
                            -- if data[k] == "only_used_by_" .. string.lower(character) then
                            if data[k] and string.find(data[k],'only_used_by_') then
                                data[k] = v
                            end
                        end
                    end
                end
            end
        end
    end
end

---@private
function dst_lan:DFSWithStack(character, tab)
    local stack = {{tab}}
    while #stack > 0 do
        local curtbl = table.remove(stack)
        for k, v in pairs(curtbl) do
            if type(v) == "table" then
                if v[character] and type(v[character]) == "table" then
                    self:TraceWithStack(character, v, v[character], { character })
                else
                    table.insert(stack, v)
                end
            end
        end
    end
end

---@private
function dst_lan:ReplaceCharacterLines(character)
    self:DFSWithStack(string.upper(character), STRINGS)
end

function dst_lan:main()
    if rawget(GLOBAL,GLOBAL_DST_LAN_API_ONLY_USED_BY) == nil then
        rawset(GLOBAL,GLOBAL_DST_LAN_API_ONLY_USED_BY,true)
        AddGamePostInit(function()
            for _, p in ipairs(self.official_avatars) do
                self:ReplaceCharacterLines(p)
            end
        end)
    end
end

return dst_lan


