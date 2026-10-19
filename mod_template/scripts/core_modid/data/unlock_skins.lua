---@class data_unlock_skins
---@field list table<string, string[]> # 键为 皮肤 的完整名字, 值为 id
---@field map table<string, table<string, boolean>>|nil

---@type data_unlock_skins
local id_list = {
    list = {
        -- 假设这是一个皮肤
        -- myspear_skin_goldenspear = {
        --     'KU_XXXXXXXX', -- KU开头为在线时的玩家klei id (用这个就行了)
        --     'OU_XXXXXXXXXXXXXXXXXXXXX', -- OU 开头为离线时的玩家steam id (一般调试的时候用, 发布前删掉)
        -- },
    },
}

id_list.map = {}
for skinname, id_tbl in pairs(id_list.list) do
    if id_list.map[skinname] == nil then
        id_list.map[skinname] = {}
    end
    for _, id in ipairs(id_tbl) do
        id_list.map[skinname][id] = true
    end
end

return id_list
