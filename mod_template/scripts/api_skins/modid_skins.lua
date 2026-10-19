---@diagnostic disable: redundant-parameter, undefined-global, undefined-field, inject-field, need-check-nil, lowercase-global, trailing-space, param-type-mismatch
local unlock_skins_map = require('core_%(modid)s/data/unlock_skins').map
---@cast unlock_skins_map table<string, table<string, boolean>>
-------------------------------------------------------------------------
--------------------- 感谢风铃大佬的奉献！！！---------------------------
-------------------------------------------------------------------------
local CreatePrefabSkin -- 重新定义一下自己的 试图绕过Modded API的截取 在文件结尾有重新定义
local recipe_help = true
local thank_help = true
-- 人物皮肤API
local characterskins = {}
--[[格式 skinname = {
            打*的为必填项 反之不必须
                            base_prefab = base,
                            
                            *name = string or skinname   --皮肤的名称
                            des = string or "",         --皮肤界面的描述
                            quotes = string or nil      --选人界面的描述
                            rarity = string or "Loyal", --珍惜度 官方不存在的珍惜度则直接覆盖字符串
                            rarityorder = int or -1 --  --珍惜度的排序 用于按优先级排序 基本没啥用
                            raritycorlor = {R,G,B,A} or { 0.635, 0.769, 0.435, 1 }
                            
                            checkfn = function or nil,  检查是否拥有的 主要是客机自己执行 为空则默认拥有
                            checkclientfn = function or nil, 检查客户端是否拥有的 主要是主机执行 
                            init_fn = function or nil,   
                            clear_fn = function or nil,
                            share_bigportrait_name = string or nil,  --人物皮肤的背景图 大图
                            FrameSymbol = string or nil ,            --人物base皮肤的背景
                            *skins = {
                                normal_skin  = string or name,
                                ghost_skin   = string or name_ghost,
                            } or nil
                            
                            
                            --所有参数会顺传给返回的prefab
                                skintags = {} or nil, 皮肤的tag 用于过滤
                                assets = {} or nil,   皮肤用到的资源
                            --其他参数暂时用不到，需要的自己带进来吧，会自动传递官方的
                          }]]

                          
---@class data_api_avatar_skins
---@field name string
---@field des string|nil
---@field rarity string
---@field rarityorder integer|nil
---@field raritycorlor RGBA
---@field checkfn function|nil
---@field checkclientfn function|nil
---@field initfn function|nil
---@field clearfn function|nil
---@field share_bigportrait_name string|nil
---@field FrameSymbol string|nil
---@field skins {normal_skin:string, ghost_skin:string}
---@field skintags string[]|nil
---@field assets table|nil
---@field dst_lan data_api_skins_dst_lan|nil # dst-lan插件提供的额外功能

local FrameSymbol = {}
local skincharacters = {}
-- 人物过滤
local SKIN_AFFINITY_INFO = require("skin_affinity_info")

---comment
---@param base any
---@param skinname any
---@param data data_api_avatar_skins
---@return table
function MakeCharacterSkin(base, skinname, data)
    -- 基于哪个人物的  皮肤名称 额外数据
    data.type = nil

    -- 标记一下是拥有皮肤的人物
    if not skincharacters[base] then skincharacters[base] = true end
    characterskins[skinname] = data
    data.base_prefab = base
    data.rarity = data.rarity or "Loyal" -- 默认珍惜度
    data.build_name_override = data.build_name_override or skinname
    -- 不存在的珍惜度 自动注册字符串
    if not STRINGS.UI.RARITY[data.rarity] then
        STRINGS.UI.RARITY[data.rarity] = data.rarity
        SKIN_RARITY_COLORS[data.rarity] = data.raritycorlor or {0.635, 0.769, 0.435, 1}
        RARITY_ORDER[data.rarity] = data.rarityorder or -1
        if data.FrameSymbol then FrameSymbol[data.rarity] = data.FrameSymbol end
    end
    -- 注册到字符串
    STRINGS.SKIN_NAMES[skinname] = data.name or skinname
    STRINGS.SKIN_DESCRIPTIONS[skinname] = data.des or ""
    STRINGS.SKIN_QUOTES[skinname] = data.quotes or ""
    -- 注册到皮肤列表
    if not PREFAB_SKINS[base] then PREFAB_SKINS[base] = {} end
    table.insert(PREFAB_SKINS[base], skinname)
    if not SKIN_AFFINITY_INFO[base] then SKIN_AFFINITY_INFO[base] = {} end
    table.insert(SKIN_AFFINITY_INFO[base], skinname)
    -- 白名单皮肤
    local haswhitelist = data.dst_lan and data.dst_lan.whitelist or false
    local old_checkfn = data.checkfn
    if (old_checkfn ~= nil or haswhitelist) then
        data.checkfn = function(checkfn_i, checkfn_name, ...)
            local check_whitelist = true
            if haswhitelist then
                if unlock_skins_map[checkfn_name] == nil then
                    assert(false,'你为'..checkfn_name..'皮肤设置了白名单模式,但是没有设置白名单列表!')
                elseif not unlock_skins_map[checkfn_name][TheNet:GetUserID()] then
                    check_whitelist = false
                end
            end
            local check_old_checkfn = true
            if old_checkfn ~= nil then
                check_old_checkfn = old_checkfn(checkfn_i, checkfn_name, ...)
            end
            return check_whitelist and check_old_checkfn
        end
    end
    local old_checkclientfn = data.checkclientfn
    if (old_checkclientfn ~= nil or haswhitelist) then 
        data.checkclientfn = function(checkclientfn_i, checkclientfn_userid, checkclientfn_name, ...)
            local check_whitelist = true
            if haswhitelist then
                if unlock_skins_map[checkclientfn_name] == nil then
                    assert(false,'你为'..checkclientfn_name..'皮肤设置了白名单模式,但是没有设置白名单列表!')
                elseif not unlock_skins_map[checkclientfn_name][checkclientfn_userid] then
                    check_whitelist = false
                end
            end
            local check_old_checkclientfn = true
            if old_checkclientfn ~= nil then
                check_old_checkclientfn = old_checkclientfn(checkclientfn_i, checkclientfn_userid, checkclientfn_name, ...)
            end
            return check_whitelist and check_old_checkclientfn
        end
    end
    -- 创建皮肤预制物
    local prefab_skin = CreatePrefabSkin(skinname, data)
    if data.clear_fn then prefab_skin.clear_fn = data.clear_fn end
    prefab_skin.type = "base"
    RegisterPrefabs(prefab_skin) -- 注册并加载皮肤的prefab
    TheSim:LoadPrefabs({skinname})
    return prefab_skin
end
-- 物品皮肤
local itemskins = {}
--[[格式 skinname = {
            打*的为必填项 反之不必须
                        base = "",
                            *name = string or skinname   --皮肤的名称
                            des = string or "",         --皮肤界面的描述       好像没啥用
                            rarity = string or "Loyal", --珍惜度 官方不存在的珍惜度则直接覆盖字符串
                            rarityorder = int or -1 --      珍惜度的排序 好像没啥用
                            raritycorlor = {R,G,B,A} or { 0.635, 0.769, 0.435, 1 }  --珍惜度的颜色
                            atlas = string or nil,      --贴图xml
                            image = string or nil,        --贴图tex 不带.tex
                            --解决官方默认皮肤图标不搜索mod的问题  如果是 prefab和imagename名字一致的 建议用官方的 RegisterInventoryItemAtlas
                            bank    = string or nil,        --如果需要替换bank就传 不需要就不传
                            build   = string or skinname,   --如果需要替换build就传 不需要就默认和皮肤同名
                            anim    = string or nil,        --如果需要替换anim就传 不需要就不传
                            
                            basebank    = string or nil,        --如果替换了bank就传 不需要就不传
                            basebuild   = string or prefab,        --如果替换了build就传 不需要默认原prefab
                            baseanim    = string or nil,        --如果替换了anim就传 不需要就不传
                            
                            checkfn = function or nil,  检查是否拥有的 主要是客机自己执行 为空则默认拥有
                            checkclientfn = function or nil, 检查客户端是否拥有的 主要是主机执行 
                            initfn = function or nil,   
                            clearfn = function or nil,
                               
                            --所有参数会顺传给返回的prefab
                                skintags = {} or nil, 皮肤的tag 用于过滤
                                assets = {} or nil,   皮肤用到的资源
                            --其他参数暂时用不到，需要的自己带进来吧，会自动传递官方的
                            
                        }
        
]]

---@class data_api_skins_dst_lan
---@field whitelist boolean|nil # 是否启用白名单解锁模式

---@class data_api_skins
---@field name string
---@field des string|nil
---@field rarity string
---@field rarityorder integer|nil
---@field raritycorlor RGBA
---@field atlas string|nil
---@field image string|nil
---@field bank string|nil
---@field build string|nil
---@field anim string|nil
---@field basebank string|nil
---@field basebuild string|nil
---@field baseanim string|nil
---@field checkfn function|nil
---@field checkclientfn function|nil
---@field initfn function|nil
---@field clearfn function|nil
---@field skintags string[]|nil
---@field assets table|nil
---@field dst_lan data_api_skins_dst_lan|nil # dst-lan插件提供的额外功能

---@class api_skins
---@field MakeItemSkin fun(base, skinname, data:data_api_skins):table
---@field MakeCharacterSkin fun(base, skinname, data)
---@field MakeItemSkinDefaultImage fun(base, atlas, image)
%(modid_upper)s_API = %(modid_upper)s_API

local itembaseimage = {}
function MakeItemSkinDefaultImage(base, atlas, image) itembaseimage[base] = {atlas, (image or base) .. ".tex", "default.tex"} end

---comment
---@param base any
---@param skinname any
---@param data data_api_skins
---@return table
function MakeItemSkin(base, skinname, data)
    data.type = nil
    itemskins[skinname] = data
    data.base_prefab = base
    data.rarity = data.rarity or "Loyal" -- 默认珍惜度
    data.build_name_override = data.build_name_override or skinname
    -- 不存在的珍惜度 自动注册字符串
    if not STRINGS.UI.RARITY[data.rarity] then
        STRINGS.UI.RARITY[data.rarity] = data.rarity
        SKIN_RARITY_COLORS[data.rarity] = data.raritycorlor or {0.635, 0.769, 0.435, 1}
        RARITY_ORDER[data.rarity] = data.rarityorder or -1
        if data.FrameSymbol then FrameSymbol[data.rarity] = data.FrameSymbol end
    end
    -- 注册到字符串
    STRINGS.SKIN_NAMES[skinname] = data.name or skinname
    STRINGS.SKIN_DESCRIPTIONS[skinname] = data.des or ""
    if data.atlas and data.image then RegisterInventoryItemAtlas(data.atlas, data.image .. ".tex") end
    -- 注册到皮肤列表
    if not PREFAB_SKINS[base] then PREFAB_SKINS[base] = {} end
    table.insert(PREFAB_SKINS[base], skinname)
    if not PREFAB_SKINS_IDS[base] then PREFAB_SKINS_IDS[base] = {} end
    local index = 1
    for k, v in pairs(PREFAB_SKINS_IDS[base]) do index = index + 1 end
    PREFAB_SKINS_IDS[base][skinname] = index
    -- 创建皮肤预制物

    -- 白名单皮肤
    local haswhitelist = data.dst_lan and data.dst_lan.whitelist or false
    local old_checkfn = data.checkfn
    if (old_checkfn ~= nil or haswhitelist) then
        data.checkfn = function(checkfn_i, checkfn_name, ...)
            local check_whitelist = true
            if haswhitelist then
                if unlock_skins_map[checkfn_name] == nil then
                    assert(false,'你为'..checkfn_name..'皮肤设置了白名单模式,但是没有设置白名单列表!')
                elseif not unlock_skins_map[checkfn_name][TheNet:GetUserID()] then
                    check_whitelist = false
                end
            end
            local check_old_checkfn = true
            if old_checkfn ~= nil then
                check_old_checkfn = old_checkfn(checkfn_i, checkfn_name, ...)
            end
            return check_whitelist and check_old_checkfn
        end
    end
    local old_checkclientfn = data.checkclientfn
    if (old_checkclientfn ~= nil or haswhitelist) then 
        data.checkclientfn = function(checkclientfn_i, checkclientfn_userid, checkclientfn_name, ...)
            local check_whitelist = true
            if haswhitelist then
                if unlock_skins_map[checkclientfn_name] == nil then
                    assert(false,'你为'..checkclientfn_name..'皮肤设置了白名单模式,但是没有设置白名单列表!')
                elseif not unlock_skins_map[checkclientfn_name][checkclientfn_userid] then
                    check_whitelist = false
                end
            end
            local check_old_checkclientfn = true
            if old_checkclientfn ~= nil then
                check_old_checkclientfn = old_checkclientfn(checkclientfn_i, checkclientfn_userid, checkclientfn_name, ...)
            end
            return check_whitelist and check_old_checkclientfn
        end
    end

    data.skininit_fn = data.init_fn or nil
    data.skinclear_fn = data.clear_fn or nil
    data.init_fn = function(i) basic_skininit_fn(i, skinname) end
    data.clear_fn = function(i) basic_skinclear_fn(i, skinname) end
    if data.skinpostfn then
        data.skinpostfn(data) -- 给一个玩家改init_fn的接口
    end
    local prefab_skin = CreatePrefabSkin(skinname, data)
    if data.clear_fn then prefab_skin.clear_fn = data.clear_fn end

    prefab_skin.type = "item"
    RegisterPrefabs(prefab_skin) -- 注册并加载皮肤的prefab
    TheSim:LoadPrefabs({skinname})
    return prefab_skin
end

local namemaps = {}
-- 允许 skinname 皮肤 共用base的权限
function MakeSkinNameMap(base, skinname) namemaps[skinname] = base end
function GetSkinMap(skinname) return namemaps[skinname] or skinname end
function GetSkinMapByBase(base)
    local r = {[base] = 1}
    for k, v in pairs(namemaps) do if v == base then r[k] = 1 end end
    return r
end
-- 下面的可以不看

-- 皮肤权限hook

local timelastest = 0

local mt = getmetatable(TheInventory)
local oldTheInventoryCheckOwnership = TheInventory.CheckOwnership
mt.__index.CheckOwnership = function(i, name, ...)
    -- print(i,name,...)
    name = namemaps[name] or name
    if type(name) == "string" and (characterskins[name] or itemskins[name]) then
        if characterskins[name] and characterskins[name].checkfn then
            return characterskins[name].checkfn(i, name, ...)
        elseif itemskins[name] and itemskins[name].checkfn then
            return itemskins[name].checkfn(i, name, ...)
        else
            return true
        end
    else
        return oldTheInventoryCheckOwnership(i, name, ...)
    end
end
local oldTheInventoryCheckOwnershipGetLatest = TheInventory.CheckOwnershipGetLatest
mt.__index.CheckOwnershipGetLatest = function(i, name, ...)
    -- print(i,name,...)
    name = namemaps[name] or name
    if type(name) == "string" and (characterskins[name] or itemskins[name]) then
        if characterskins[name] and characterskins[name].checkfn then
            return characterskins[name].checkfn(i, name, ...), timelastest
        elseif itemskins[name] and itemskins[name].checkfn then
            return itemskins[name].checkfn(i, name, ...), timelastest
        else
            return true, timelastest
        end
    else
        return oldTheInventoryCheckOwnershipGetLatest(i, name, ...)
    end
end

local oldTheInventoryCheckClientOwnership = TheInventory.CheckClientOwnership
mt.__index.CheckClientOwnership = function(i, userid, name, ...)
    name = namemaps[name] or name
    if type(name) == "string" and (characterskins[name] or itemskins[name]) then
        if characterskins[name] and characterskins[name].checkclientfn then
            return characterskins[name].checkclientfn(i, userid, name, ...)
        elseif itemskins[name] and itemskins[name].checkclientfn then
            return itemskins[name].checkclientfn(i, userid, name, ...)
        else
            return true
        end
    else
        return oldTheInventoryCheckClientOwnership(i, userid, name, ...)
    end
end

local oldExceptionArrays = GLOBAL.ExceptionArrays
GLOBAL.ExceptionArrays = function(ta, tb, ...)
    local need
    for i = 1, 100, 1 do
        local data = debug.getinfo(i, "S")
        if data then
            if data.source and data.source:match("^scripts/networking.lua") then need = true end
        else
            break
        end
    end
    if need then
        local newt = oldExceptionArrays(ta, tb, ...)
        for k, v in pairs(skincharacters) do
            table.insert(newt, k) -- 偷渡
        end
        return newt
    else
        return oldExceptionArrays(ta, tb, ...)
    end
end
local oldIsDefaultCharacterSkin = IsDefaultCharacterSkin
GLOBAL.IsDefaultCharacterSkin = function(item, ...)
    item = item and namemaps[item] or item
    if item and characterskins[item] then
        if characterskins[item].checkfn then
            return characterskins[item].checkfn(nil, item)
        else
            return true
        end
    else
        return oldIsDefaultCharacterSkin(item, ...)
    end
end
local oldGetPortraitNameForItem = GetPortraitNameForItem
GLOBAL.GetPortraitNameForItem = function(item)
    item = item and namemaps[item] or item
    if item and characterskins[item] and characterskins[item].share_bigportrait_name then return characterskins[item].share_bigportrait_name end
    return oldGetPortraitNameForItem(item)
end
local oldGetFrameSymbolForRarity = GetFrameSymbolForRarity
GLOBAL.GetFrameSymbolForRarity = function(item)
    item = item and namemaps[item] or item
    return FrameSymbol[item] or oldGetFrameSymbolForRarity(item)
end
-- 骗过皮肤面板，让他以为我们是官方人物
local function rainlightbaseenable(self)
    if self.name == "LoadoutSelect" then -- 加载LoadoutSelect之前
        for k, v in pairs(skincharacters) do if not table.contains(DST_CHARACTERLIST, k) then table.insert(DST_CHARACTERLIST, k) end end
    elseif self.name == "LoadoutRoot" then -- 已经判断完have_base_option了  可以删了 哈哈
        for k, v in pairs(skincharacters) do if table.contains(DST_CHARACTERLIST, k) then RemoveByValue(DST_CHARACTERLIST, k) end end
    end
end
AddClassPostConstruct("widgets/widget", rainlightbaseenable)
AddSimPostInit(function()
    if not TheNet:IsOnlineMode() then
        local net = getmetatable(GLOBAL.TheNet)
        net.__index.IsOnlineMode = function(n, ...) return true end
    end
end)
-- 人物皮肤的init_fn 和 clear_fn
AddComponentPostInit("skinner", function(self)
    local oldfn = self.SetSkinName
    if oldfn then
        function self.SetSkinName(s, skinname, ...)
            local old = s.skin_name
            local new = skinname
            if characterskins[old] and characterskins[old].clear_fn then characterskins[old].clear_fn(s.inst, old) end
            if characterskins[new] and characterskins[new].init_fn then characterskins[new].init_fn(s.inst, new) end
            oldfn(s, skinname, ...)
        end
    end
end)

AddClassPostConstruct("widgets/recipepopup", function(self)
    local oldfn = self.GetSkinOptions
    function self.GetSkinOptions(s, ...)
        local ret = oldfn(s, ...)
        if ret then
            if ret[1] and ret[1].image then
                if s.recipe and s.recipe.product and itembaseimage[s.recipe.product] then -- 存在则覆盖
                    ret[1].image = itembaseimage[s.recipe.product]
                end
            end
            for k, v in pairs(s.skins_list) do
                if ret[k + 1] and ret[k + 1].image and v and v.item and itemskins[v.item] and (itemskins[v.item].atlas or itemskins[v.item].image) then

                    local image = itemskins[v.item].image or v.item .. ".tex"
                    if image:sub(-4) ~= ".tex" then image = image .. ".tex" end
                    local atlas = itemskins[v.item].atlas or GetInventoryItemAtlas(image)
                    ret[k + 1].image = {atlas, image, "default.tex"}

                end
            end
        end
        return ret
    end
end)

local skinselector = require("widgets/redux/craftingmenu_skinselector")
function hookskinselector(self)
    local oldfn = self.GetSkinOptions
    function self.GetSkinOptions(s, ...)
        local ret = oldfn(s, ...)
        if ret then
            if ret[1] and ret[1].image then
                if s.recipe and s.recipe.product and itembaseimage[s.recipe.product] then -- 存在则覆盖
                    ret[1].image = itembaseimage[s.recipe.product]
                end
            end
            for k, v in pairs(s.skins_list) do
                if ret[k + 1] and ret[k + 1].image and v and v.item and itemskins[v.item] and (itemskins[v.item].atlas or itemskins[v.item].image) then
                    local image = itemskins[v.item].image or v.item .. ".tex"
                    if image:sub(-4) ~= ".tex" then image = image .. ".tex" end
                    local atlas = itemskins[v.item].atlas or GetInventoryItemAtlas(image)
                    ret[k + 1].image = {atlas, image, "default.tex"}

                end
            end
        end
        return ret
    end
end
hookskinselector(skinselector)
local oldGetSkinInvIconName = GetSkinInvIconName
GLOBAL.GetSkinInvIconName = function(item, ...)
    if itemskins[item] and itemskins[item].image then
        local image = itemskins[item].image
        if image:sub(-4) == ".tex" then image = image:sub(1, -5) end
        return image
    end
    return oldGetSkinInvIconName(item, ...)

end

-- 这是全局函数 所以可以放后面 在执行前定义好就行
function basic_skininit_fn(inst, skinname)
    if inst.components.placer == nil and not TheWorld.ismastersim then return end
    local data = itemskins[skinname]
    if not data then return end
    if data.bank then inst.AnimState:SetBank(data.bank) end
    inst.AnimState:SetBuild(data.build or skinname)
    if data.anim then -- 改了下【雨荧
        if data.animcircle then
            inst.AnimState:PlayAnimation(data.anim, true)
        else
            inst.AnimState:PlayAnimation(data.anim)
        end
    end
    if inst.components.inventoryitem ~= nil then
        inst.components.inventoryitem.atlasname = data.atlas or ("images/inventoryimages/" .. skinname .. ".xml")
        inst.components.inventoryitem:ChangeImageName(data.image or skinname)
    end
    if data.skininit_fn then data.skininit_fn(inst, skinname) end
end
function basic_skinclear_fn(inst, skinname) -- 默认认为 build 和prefab同名 不对的话自己改
    local prefab = inst.prefab or ""
    local data = itemskins[skinname]
    if not data then return end
    if data.basebank then inst.AnimState:SetBank(data.basebank) end
    if data.baseanim then -- 改了下【雨荧
        if data.baseanimcircle then
            inst.AnimState:PlayAnimation(data.baseanim, true)
        else
            inst.AnimState:PlayAnimation(data.baseanim)
        end
    end
    inst.AnimState:SetBuild(data.basebuild or prefab)
    if inst.components.inventoryitem ~= nil then
        inst.components.inventoryitem.atlasname = GetInventoryItemAtlas(prefab .. ".tex")
        inst.components.inventoryitem:ChangeImageName(prefab)

    end
    if itemskins[skinname].skinclear_fn then itemskins[skinname].skinclear_fn(inst, skinname) end
end
local oldSpawnPrefab = SpawnPrefab
GLOBAL.SpawnPrefab = function(prefab, skin, skinid, userid, ...)
    if itemskins[skin] then skinid = 0 end
    return oldSpawnPrefab(prefab, skin, skinid, userid, ...)
end
local oldReskinEntity = Sim.ReskinEntity
Sim.ReskinEntity = function(sim, guid, oldskin, newskin, skinid, userid, ...)
    local inst = Ents[guid]
    if oldskin and itemskins[oldskin] then
        itemskins[oldskin].clear_fn(inst) -- 清除旧皮肤的
    end
    local r = oldReskinEntity(sim, guid, oldskin, newskin, skinid, userid, ...)
    if newskin and itemskins[newskin] then

        itemskins[newskin].init_fn(inst)
        inst.skinname = newskin
        inst.skin_id = 0
    end
    return r
end

function GetSkin(name) return characterskins[name] or itemskins[name] or nil end

if recipe_help then
    AddSimPostInit(function()
        for k, v in pairs(AllRecipes) do
            if v.product ~= v.name and PREFAB_SKINS[v.product] then
                PREFAB_SKINS[v.name] = PREFAB_SKINS[v.product]
                PREFAB_SKINS_IDS[v.name] = PREFAB_SKINS_IDS[v.product]
            end
        end
    end)
end

if thank_help then
    local ThankYouPopup = require "screens/thankyoupopup"
    local tohook = {OpenGift = 1, ChangeGift = 1}
    for k, v in pairs(tohook) do
        tohook[k] = ThankYouPopup[k]
        ThankYouPopup[k] = function(self, ...)

            local r = tohook[k](self, ...)

            local item = self.current_item and self.items and self.items[self.current_item] and self.items[self.current_item].item
            if item then
                local skin = GetSkin(item)
                if skin and skin.swap_icon then
                    self.spawn_portal:GetAnimState():OverrideSkinSymbol("SWAP_ICON", skin.swap_icon.build, skin.swap_icon.image)
                elseif skin and skin.image and skin.atlas then
                    self.spawn_portal:GetAnimState():OverrideSkinSymbol("SWAP_ICON", softresolvefilepath(skin.atlas), skin.image .. ".tex")
                end
            end

            return r
        end
    end
end

local oldCreatePrefabSkin = GLOBAL.CreatePrefabSkin
local fninfo = debug.getinfo(oldCreatePrefabSkin)
if fninfo and fninfo.source and not fninfo.source:match("scripts/prefabskin%.lua") then -- 不是官方的就用自己的
    -- print("UseMySelfCreatePrefabSkin")
    function CreatePrefabSkin(name, info)
        local prefab_skin = Prefab(name, nil, info.assets, info.prefabs)
        prefab_skin.is_skin = true
        -- Hack to deal with mods with bad data. Type is now required, and who knows how many character mods are missing this field.
        if info.type == nil then info.type = "base" end
        prefab_skin.base_prefab = info.base_prefab
        prefab_skin.type = info.type
        prefab_skin.skin_tags = info.skin_tags
        prefab_skin.init_fn = info.init_fn
        prefab_skin.build_name_override = info.build_name_override
        prefab_skin.bigportrait = info.bigportrait
        prefab_skin.rarity = info.rarity
        prefab_skin.rarity_modifier = info.rarity_modifier
        prefab_skin.skins = info.skins
        prefab_skin.skin_sound = info.skin_sound
        prefab_skin.is_restricted = info.is_restricted
        prefab_skin.granted_items = info.granted_items
        prefab_skin.marketable = info.marketable
        prefab_skin.release_group = info.release_group
        prefab_skin.linked_beard = info.linked_beard
        prefab_skin.share_bigportrait_name = info.share_bigportrait_name
        if info.torso_tuck_builds ~= nil then for _, base_skin in pairs(info.torso_tuck_builds) do BASE_TORSO_TUCK[base_skin] = "full" end end
        if info.torso_untuck_builds ~= nil then for _, base_skin in pairs(info.torso_untuck_builds) do BASE_TORSO_TUCK[base_skin] = "untucked" end end
        if info.torso_untuck_wide_builds ~= nil then for _, base_skin in pairs(info.torso_untuck_wide_builds) do BASE_TORSO_TUCK[base_skin] = "untucked_wide" end end
        if info.has_alternate_for_body ~= nil then for _, base_skin in pairs(info.has_alternate_for_body) do BASE_ALTERNATE_FOR_BODY[base_skin] = true end end
        if info.has_alternate_for_skirt ~= nil then for _, base_skin in pairs(info.has_alternate_for_skirt) do BASE_ALTERNATE_FOR_SKIRT[base_skin] = true end end
        if info.one_piece_skirt_builds ~= nil then for _, base_skin in pairs(info.one_piece_skirt_builds) do ONE_PIECE_SKIRT[base_skin] = true end end
        if info.legs_cuff_size ~= nil then for base_skin, size in pairs(info.legs_cuff_size) do BASE_LEGS_SIZE[base_skin] = size end end
        if info.feet_cuff_size ~= nil then for base_skin, size in pairs(info.feet_cuff_size) do BASE_FEET_SIZE[base_skin] = size end end
        if info.skin_sound ~= nil then SKIN_SOUND_FX[name] = info.skin_sound end
        if info.fx_prefab ~= nil then SKIN_FX_PREFAB[name] = info.fx_prefab end
        if info.type ~= "base" then prefab_skin.clear_fn = _G[prefab_skin.base_prefab .. "_clear_fn"] end
        return prefab_skin
    end
else
    CreatePrefabSkin = oldCreatePrefabSkin
end
