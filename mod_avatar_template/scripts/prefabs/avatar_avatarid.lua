---@diagnostic disable: undefined-global, inject-field

local MakePlayerCharacter = require 'prefabs/player_common'

local avatar_name = '%(avatarid)s'
local assets = {
	Asset('SCRIPT', 'scripts/prefabs/player_common.lua'),
	Asset('ANIM', 'anim/'..avatar_name..'.zip'),
	Asset('ANIM', 'anim/ghost_'..avatar_name..'_build.zip'),
}

local prefabs = {}

local start_inv = {}
-- for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
-- 	start_inv[string.lower(k)] = v[string.upper(avatar_name)]
-- end
start_inv['default'] = {}
for k,v in pairs(TUNING.%(avatarid_upper)s_CUSTOM_START_INV) do
	for i = 1, v.num do
		table.insert(start_inv['default'], k)
	end
end

prefabs = FlattenTree({ prefabs, start_inv }, true)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
local function onbecamehuman(inst, data, isloading)
	inst.components.locomotor:SetExternalSpeedMultiplier(inst, avatar_name..'_speed_mod', 1)
end

local function onbecameghost(inst, data)
	inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, avatar_name..'_speed_mod')
end
---------------------------------------------------------------------------
---------------------------------------------------------------------------
local function onload(inst,data)
	inst:ListenForEvent('ms_respawnedfromghost', onbecamehuman)
	inst:ListenForEvent('ms_becameghost', onbecameghost)

	if inst:HasTag('playerghost') then
		onbecameghost(inst)
	else
		onbecamehuman(inst)
	end
end
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- 主/客机
local common_postinit = function(inst)
	inst:AddTag(avatar_name)
	
	inst.MiniMapEntity:SetIcon(avatar_name..'.tex')
end
-- 主机
local master_postinit = function(inst)	
	inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default
	inst.soundsname = 'wendy'
	
	inst.components.health:SetMaxHealth(TUNING[string.upper(avatar_name)..'_HEALTH'])
	inst.components.hunger:SetMax(TUNING[string.upper(avatar_name)..'_HUNGER'])
	inst.components.sanity:SetMax(TUNING[string.upper(avatar_name)..'_SANITY'])
	
	inst.OnLoad = onload
	inst.OnNewSpawn = onload
end
-- 人物皮肤
local function Make%(avatarid_upper)sSkin(name, data, notemp, free)
	local d = {}
	d.rarity = '典藏'
	d.rarityorder = 2
	d.raritycorlor = { 0 / 255, 255 / 255, 249 / 255, 1 }
	d.release_group = -1001
	d.skin_tags = { 'BASE', avatar_name, 'CHARACTER' }
	d.skins = {
		normal_skin = name,
		ghost_skin = 'ghost_'..avatar_name..'_build'
	}
	if not free then -- 这两个暂时没写,可以参考物品的皮肤解锁来做
		d.checkfn = %(modid_upper)s_API.%(avatarid_upper)sSkinCheckFn
		d.checkclientfn = %(modid_upper)s_API.%(avatarid_upper)sSkinCheckFn
	end
	d.share_bigportrait_name = avatar_name
	d.FrameSymbol = 'Reward'
	for k, v in pairs(data) do
		d[k] = v
	end
	%(modid_upper)s_API.MakeCharacterSkin(avatar_name, name, d)
	if not notemp then
		local d2 = shallowcopy(d)
		d2.rarity = '限时体验'
		d2.rarityorder = 80
		d2.raritycorlor = { 0.957, 0.769, 0.188, 1 }
		d2.FrameSymbol = 'heirloom'
		d2.name = data.name .. '(限时)'
		%(modid_upper)s_API.MakeCharacterSkin(avatar_name, name .. '_tmp', d2)
	end
end

---comment
---@param name any
---@param data data_api_avatar_skins
function Make%(avatarid_upper)sFreeSkin(name, data)
	Make%(avatarid_upper)sSkin(name, data, true, true)
end

Make%(avatarid_upper)sFreeSkin(avatar_name..'_none', {
	name = '原版', -- 皮肤的名称
	des = '*原版', -- 皮肤界面的描述
	quotes = '\'护肝款\'', -- 选人界面的描述
	rarity = '经典', -- 珍惜度 官方不存在的珍惜度则直接覆盖字符串
	rarityorder = 2, -- 珍惜度的排序 用于按优先级排序 基本没啥用
	raritycorlor = { 189 / 255, 73 / 255, 73 / 255, 1 }, -- {R,G,B,A}
	skins = { normal_skin = avatar_name, ghost_skin = 'ghost_'..avatar_name..'_build' },
	build_name_override = avatar_name,
	share_bigportrait_name = avatar_name..'_none',
})


return MakePlayerCharacter(avatar_name, prefabs, assets, common_postinit, master_postinit, prefabs)


