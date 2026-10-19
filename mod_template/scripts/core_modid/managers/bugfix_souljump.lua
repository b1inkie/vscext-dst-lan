-- hide
-- 当你使用官方组件来写武器技能时, 会导致和 小恶魔的灵魂跳跃 冲突, 具体我忘了, 总之这个文件就是用来修复这个bug的
-- 将武器prefab id 填进这个表即可

---@type table<PrefabID,boolean>
local WEAPONS_NOT_ALLOW_SOUL_JUMP = {
	-- my_weapon = true,
}

AddPlayerPostInit(function(inst)
	inst:DoTaskInTime(0,function()
		if inst.prefab == "wortox" then
			if inst.components.playeractionpicker ~= nil then
				local old_fn = inst.components.playeractionpicker.pointspecialactionsfn
				inst.components.playeractionpicker.pointspecialactionsfn = function(_inst, pos, useitem, right,...)
					local wp = inst.replica.inventory and inst.replica.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
					local wp_prefab = wp and wp.prefab
					if WEAPONS_NOT_ALLOW_SOUL_JUMP[wp_prefab] then
						return {}
					end
					local res = old_fn ~= nil and {old_fn(_inst, pos, useitem, right,...)} or {}
					return  unpack(res)
				end
			end
		end
	end)
end)
