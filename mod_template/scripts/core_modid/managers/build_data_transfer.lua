-- hide
-- 功能(需要填写): 制作物品过程涉及数据传输 (只能传输1件原材料的数据)
-- 注意 测试时 开着 `c_freecrafting()` 是无效的

---@class data_builder_transfer
---@field source string # 原材料prefab
---@field prod string # 成品的prefab
---@field fetch_fn fun(source:ent,recname:string):table<string,any> # 获取数据 返回键值对
---@field apply_fn fun(prod:ent,data:table<string,any>,recname:string) # 应用数据

local modid = '%(modid)s'

---@type table<string,data_builder_transfer> # 键为recname(配方名)
local map = {
    -- lol_wp_s11_darkseal = {
    --     source = 'lol_wp_s11_darkseal',
    --     prod = 'lol_wp_s11_mejaisoulstealer',
    --     fetch_fn = function(source)
    --         local num = 0
    --         if source.components.lol_wp_s11_darkseal_num then
    --             num = source.components.lol_wp_s11_darkseal_num:GetVal()
    --         end
    --         return {num = num}
    --     end,
    --     apply_fn = function(prod,data)
    --         local num = data and data.num
    --         if prod.components.lol_wp_s11_mejaisoulstealer_num then
    --             prod.components.lol_wp_s11_mejaisoulstealer_num:DoDelta(num)
    --         end
    --     end
    -- },
}

AddComponentPostInit('builder',
---comment
---@param self component_builder
function (self)
    local old_RemoveIngredients = self.RemoveIngredients
    function self:RemoveIngredients(ingredients,recname,discounted,...)
        local player = self.inst
        local data = map[recname]
        if player and data then
            for _,ents in pairs(ingredients or {}) do
                for v,_ in pairs(ents) do
                    local prefab = v.prefab
                    if prefab and prefab == data.source and data.fetch_fn then
                        local prod = data.prod
                        player[modid..'_data_transfer_source'..prefab] = data.fetch_fn(v,recname)
                        player[modid..'_data_transfer_prod'..prod] = prefab
                        player[modid..'_data_transfer_recname'] = recname
                    end
                end
            end
        end

        return old_RemoveIngredients(self,ingredients,recname,discounted,...)
    end
end)


AddPlayerPostInit(function(inst)
    if not TheWorld.ismastersim then
        return inst
    end

    inst:ListenForEvent('builditem',function (_,data)
        ---@type ent|nil
        local prod = data and data.item
        local ingredient_prefab = prod ~= nil and prod.prefab ~= nil and inst[modid..'_data_transfer_prod'..prod.prefab]
        if prod and ingredient_prefab then
            local recname = inst[modid..'_data_transfer_recname']
            if recname then
                local fn = map[recname] and map[recname].apply_fn
                local fetch_data = inst[modid..'_data_transfer_source'..ingredient_prefab]
                if fn and fetch_data then
                    fn(prod,fetch_data,recname)
                    inst[modid..'_data_transfer_prod'..prod.prefab] = nil
                    inst[modid..'_data_transfer_source'..ingredient_prefab] = nil
                    inst[modid..'_data_transfer_recname'] = nil
                end
            end
        end
    end)
end)