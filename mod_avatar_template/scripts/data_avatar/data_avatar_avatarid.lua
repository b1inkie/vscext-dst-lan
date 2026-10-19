---@diagnostic disable: inject-field

local avatar_name = '%(avatarid)s'

local modid = '%(modid)s'

table.insert(PrefabFiles, 'avatar_'..avatar_name)

local assets_avatar = {
    Asset('ATLAS', 'images/saveslot_portraits/'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/selectscreen_portraits/'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/selectscreen_portraits/'..avatar_name..'_silho.xml'),

	Asset('ATLAS', 'bigportraits/'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/map_icons/'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/avatars/avatar_'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/avatars/avatar_ghost_'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/avatars/self_inspect_'..avatar_name..'.xml'),

	Asset('ATLAS', 'images/names_'..avatar_name..'.xml'),
	
    Asset( 'ATLAS', 'bigportraits/'..avatar_name..'_none.xml' ),
}

for _,v in pairs(assets_avatar) do
    table.insert(Assets, v)
end

--[[---注意事项
1. 目前官方自从熔炉之后人物的界面显示用的都是那个椭圆的图
2. 官方人物目前的图片跟名字是分开的 
3. 用打包工具生成好tex后
	bigportraits/xxx_none.xml 中 Element name 加上后缀 _oval
    images/names_xxx.xml 中 Element name 去掉前缀 names_
]]


-- 初始物品
TUNING.%(avatarid_upper)s_CUSTOM_START_INV = {
	-- ['goldnugget'] = {
	-- 	num = 4, -- 数量
	-- 	moditem = false, -- 是否为mod物品
	-- 	-- img = {atlas = 'images/inventoryimages/goldnugget.xml', image = 'goldnugget.tex'},
	-- },
	-- ['flint'] = {
	-- 	num = 3,
	-- 	moditem = false,
	-- },
}

TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.%(avatarid_upper)s = {}
for k,v in pairs(TUNING.%(avatarid_upper)s_CUSTOM_START_INV) do
	table.insert(TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.%(avatarid_upper)s, k)
	if v.moditem then
		TUNING.STARTING_ITEM_IMAGE_OVERRIDE[k] = {
			atlas = v.img and v.img.atlas or "images/inventoryimages/"..k..".xml",
			image = v.img and v.img.image or k..".tex",
		}
	end
end


-- 角色注册
AddMinimapAtlas("images/map_icons/"..avatar_name..".xml")
AddModCharacter(avatar_name, "FEMALE") 

-- 三维
TUNING.%(avatarid_upper)s_HEALTH = 120
TUNING.%(avatarid_upper)s_HUNGER = 120
TUNING.%(avatarid_upper)s_SANITY = 220


local avatar_info = {
	['cn'] = {
		-- 选人界面的描述
		titles = "你是多手的怪物",
		names = "蜘蛛子",
		descriptions = "*指挥小蜘蛛\n*淑女",
		quotes = "\'驯蛛师\'",
		survivability = "轻松",
		-- 描述
		myname = '蜘蛛子', -- 角色名
		others_desc_me = '姐妹你真是一个好人物啊', -- 其他人描述我
		me_desc_another_me = '%s,你是世界上的另一个我嘛?', -- 自己描述自己
	},
	['en'] = {
		-- select screen desc
		titles = "Kumoko",
		names = "Kumoko",
		descriptions = "*Lead Spiders\n*Lady",
		quotes = "\'Spider Trainer\'",
		survivability = "Easy",
		-- desc
		myname = 'Kumoko', -- avatar name
		others_desc_me = 'You are a good character', -- other people describe me
		me_desc_another_me = '%s, are you another me?', -- describe another me
	},
}

STRINGS.CHARACTER_TITLES[avatar_name] = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].titles
STRINGS.CHARACTER_NAMES[avatar_name] = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].names
STRINGS.CHARACTER_DESCRIPTIONS[avatar_name] = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].descriptions
STRINGS.CHARACTER_QUOTES[avatar_name] = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].quotes
STRINGS.CHARACTER_SURVIVABILITY[avatar_name] = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].survivability

if STRINGS.CHARACTERS.%(avatarid_upper)s == nil then
    STRINGS.CHARACTERS.%(avatarid_upper)s = {}
end

if STRINGS.CHARACTERS.%(avatarid_upper)s.DESCRIBE == nil then
    STRINGS.CHARACTERS.%(avatarid_upper)s.DESCRIBE = {}
end

STRINGS.NAMES.%(avatarid_upper)s = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].myname
STRINGS.CHARACTERS.GENERIC.DESCRIBE.%(avatarid_upper)s = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].others_desc_me
STRINGS.CHARACTERS.%(avatarid_upper)s.DESCRIBE.%(avatarid_upper)s = avatar_info[TUNING[string.upper('CONFIG_'..modid..'_LANG')]].me_desc_another_me
