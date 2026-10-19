---@diagnostic disable: lowercase-global, undefined-global, trailing-space

GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

---@type string
local modid = '%(modid)s' -- 定义唯一modid

GLOBAL.%(modid_upper)s_API = env

---@type LAN_TOOL_COORDS
COORDS_%(modid)s = require('core_'..modid..'/utils/coords')
---@type LAN_TOOL_SUGARS
SUGAR_%(modid)s = require('core_'..modid..'/utils/sugar')

rawset(GLOBAL,'COORDS_%(modid)s',COORDS_%(modid)s)
rawset(GLOBAL,'SUGAR_%(modid)s',SUGAR_%(modid)s)

PrefabFiles = {
%(prefabs)s
}

---@type asset[]
Assets = {

}

----------------------------------------
----------------------------------------
------由于导入文件较多,请务必注意顺序------
------例如钩子文件的顺序------------------
------由于导入文件较多,请务必注意顺序------
----------------------------------------
----------------------------------------

-- 导入mod配置
for _,v in ipairs({
	'_lang',

}) do TUNING[string.upper('CONFIG_'..modid..v)] = GetModConfigData(modid..v) end


-- 导入常量表
modimport('scripts/core_'..modid..'/data/tuning.lua')

-- 导入工具
modimport('scripts/core_'..modid..'/utils/_register.lua')

-- 导入功能API
modimport('scripts/core_'..modid..'/api/_register.lua')

-- 导入语言文件
modimport('scripts/core_'..modid..'/languages/'..TUNING[string.upper('CONFIG_'..modid..'_LANG')]..'.lua')

-- 皮肤API
modimport('scripts/api_skins/'..modid..'_skins') -- 皮肤api

-- 导入人物
-- modimport('scripts/data_avatar/data_avatar_xxx.lua')

-- 导入调用器
%(callers)s

-- 导入零散功能模块 (自用 可以无视) (如果你要启用某个模块, 先看该manager文件里面的置顶注释)
%(managers)s

-- 导入UI
-- modimport('scripts/core_'..modid..'/ui/template.lua')

-- 注册客机组件
-- AddReplicableComponent('xxx')

-- 导入 skins
---@type string[]
local skin_files = {
	-- 'myspear',
}
for _,v in ipairs(skin_files) do
	modimport('scripts/core_'..modid..'/skins/'..v..'.lua')
end

-- 导入 sg
---@type string[]
local sg_files = {
	-- blanksg,
}
for _,v in ipairs(sg_files) do
	modimport('scripts/core_'..modid..'/sg/'..v..'.lua')
end

-- 导入钩子 It's my勾
---@type string[]
local files_hook = {

}
for _,v in ipairs(files_hook) do
	modimport('scripts/core_'..modid..'/hooks/'..v..'.lua')
end
