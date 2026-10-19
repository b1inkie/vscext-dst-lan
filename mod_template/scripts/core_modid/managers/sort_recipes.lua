-- hide
-- 功能(需要填写): 给配方排序


---键为过滤器ID,值为配方顺序表
---@type table<recipe_filter,string[]>
local RECIPES_ORDER = {
    -- TOOLS = {
    --     "pickaxe",
    --     "axe",
    -- }
}

local function SortRecipe(a, b, filter_name, offset)
    local filter = CRAFTING_FILTERS[filter_name]
    if filter and filter.recipes then
        for sortvalue, product in ipairs(filter.recipes) do
            if product == a then
                table.remove(filter.recipes, sortvalue)
                break
            end
        end

        local target_position = #filter.recipes + 1
        for sortvalue, product in ipairs(filter.recipes) do
            if product == b then
                target_position = sortvalue + offset
                break
            end
        end
        table.insert(filter.recipes, target_position, a)
    end
end

local function sortAfter(a, b, filter_name) SortRecipe(a, b, filter_name, 1) end

for k,v in pairs(RECIPES_ORDER) do
    if #v >= 2 then
        for i=1,#v-1 do
            sortAfter(v[i+1], v[i], k)
        end
    end
end
