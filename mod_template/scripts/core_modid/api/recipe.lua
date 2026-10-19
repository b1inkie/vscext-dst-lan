---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---@class api_recipe # 配方API
local dst_lan = {}

-- Ingredient = Class(function(self, ingredienttype, amount, atlas, deconstruct, imageoverride)

---给MOD物品添加一个分类(过滤器),注意本函数必须放在main函数之前调用,否则无法将新物品添加到此过滤器中
---@param id string 全大写的filers名称
---@param atlas_path string XML路径
---@param image_path string TEX名字
---@param description string 描述,注意中英文译名
function dst_lan:addRecipeFilter(id, atlas_path, image_path, description)
	AddRecipeFilter({ name = string.upper(id), atlas = atlas_path, image = image_path })
	STRINGS.UI.CRAFTING_FILTERS[string.upper(id)] = description
end

---将a配方参照b配方位置重排
---@param a string 被排配方名
---@param b string 参照配方名
---@param filter_name string 配方分类名
---@param offset number 偏移量
function dst_lan:sortRecipe(a, b, filter_name, offset)
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

---将a配方放到b配方之后
---@param a string 被排配方名
---@param b string 参照配方名
---@param filter_name string 配方分类名
function dst_lan:sortAfter(a, b, filter_name)
	self:sortRecipe(a, b, filter_name, 1)
end

---按表内配方顺序重排
---@param tbl string[] 配方表
---@param filter_name string 过滤器
function dst_lan:sortRecipeArray(tbl, filter_name)
	for i = 1, #tbl - 1 do
		self:sortAfter(tbl[i + 1], tbl[i], filter_name)
	end
end

---总是显示配方
---@param tbl string[] 配方表
---@private
function dst_lan:alwaysShowRecipes(tbl)
	local alwaysShowRecipe = {}
	for i, v in pairs(tbl) do
		alwaysShowRecipe[i] = v
	end
	AddClassPostConstruct("widgets/redux/craftingmenu_hud", function(self)
		local old_RebuildRecipes = self.RebuildRecipes
		function self:RebuildRecipes(...)
			local res = { old_RebuildRecipes(self, ...) }
			if self.owner ~= nil and self.owner.replica.builder ~= nil then
				for _, v in pairs(AllRecipes) do
					if IsRecipeValid(v.name) then
						if alwaysShowRecipe[v.name] and self.owner and self.owner:IsValid() and self.owner:HasTag(alwaysShowRecipe[v.name]) and self.valid_recipes[v.name] then
							local meta = self.valid_recipes[v.name].meta
							if meta.build_state == "hide" then
								meta.build_state = "hint"
							end
						end
					end
				end
			end
			return unpack(res)
		end
	end)
end

function dst_lan:makeDestructionRecipes(destruction_recipes)
	for _, data in pairs(destruction_recipes) do
		AddDeconstructRecipe(data.name, data.ingredients)
	end
end

function dst_lan:main(tbl_recipe_all, destruction_recipes)
	local alwaysshow = {}

	for _, r in ipairs(tbl_recipe_all) do
		if not r.isHidden then
			-- 保证有config
			if r.config == nil then
				r.config = {}
			end
			-- 如果是原版物品
			if r.isOriginalItem then
			else -- 非原版物品
				-- 没有product,则用配方名,确保有product
				if r.config.product == nil then
					r.config.product = r.recipe_name
				end
				-- 没有图集路径,则用product路径
				if r.config.atlas == nil then
					r.config.atlas = 'images/inventoryimages/' .. r.config.product .. '.xml'
				end
				if r.config.image == nil then
					r.config.image = r.config.product .. '.tex'
				end
				-- 数量
				if r.config.numtogive == nil then
					r.config.numtogive = 1
				end
			end
			-- 如果需要常显
			if r.isAlwaysShown then
				alwaysshow[r.recipe_name] = r.config.builder_tag
			end

			AddRecipe2(r.recipe_name, r.ingredients, r.tech, r.config, r.filters)
		end
	end

	self:alwaysShowRecipes(alwaysshow)

	self:makeDestructionRecipes(destruction_recipes)
end

return dst_lan
