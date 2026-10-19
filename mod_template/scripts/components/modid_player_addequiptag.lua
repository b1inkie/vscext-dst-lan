local modid = '%(modid)s'

---@type SourceModifierList
local SourceModifierList = require("util/sourcemodifierlist")

---本组件之前是加在物品上,现在改为玩家的组件
---要用这个组件,请先点下面这个跳转过去
---@source ../core_%(modid)s/managers/misc.lua:6 
local _______see -- ctrl + 左键 点我快速跳转至 managers 中查看所需要做的其他事

---@class components
---@field %(modid)s_player_addequiptag component_%(modid)s_player_addequiptag # 这个组件是添加给玩家的,调用add方法,添加装备才有的tag,也能让玩家有装备时的效果,例如夜视 护目镜等

-- 方法不止一种, 我写着玩的, 你也可以勾equiphastag,然后遍历物品栏,再模拟一次装备

---@class component_%(modid)s_player_addequiptag
---@field inst ent
---@field equipslot string|nil
---@field tags tagID[]|nil
---@field _silent boolean
local %(modid)s_player_addequiptag = Class(
---@param self component_%(modid)s_player_addequiptag
---@param inst ent
function(self, inst)
    self.inst = inst
    self.equipslot = nil
    self.tags = nil

    self._silent = false
end,
nil,
{
})

---初始化(已由插件自动调用,请勿自行调用)
---@param assign_new_equipslot string # 分配一个新的equipslot,需要自己事先创建 <br> 虽然equipslots有上限,但 我们可以用相同的槽位, 例如在可以在 `modmain` 添加 `EQUIPSLOTS.EXTRA_VOIDEQUIP = 'extra_voidequip'` <br> `../core_%(modid)s/managers/misc.lua:6`  这个路径下有我预设的代码块 启用一下即可
function %(modid)s_player_addequiptag:_Init(assign_new_equipslot)
    self.equipslot = assign_new_equipslot
end

---comment
---@return ent_%(modid)s_player_addequiptag
---@nodiscard
---@private
function %(modid)s_player_addequiptag:_createVoidEquip()
    ---@class ent_%(modid)s_player_addequiptag : ent
    ---@field tags_map table<tagID,SourceModifierList>

    local wp = SpawnPrefab('spear')
    ---@cast wp ent_%(modid)s_player_addequiptag
    wp:AddTag('NOCLICK')
    wp:AddTag('NOBLOCK')
    wp:AddTag('nosteal')
    wp:AddTag('hide_percentage')
    wp.components.equippable.onequipfn = nil
    wp.components.equippable.onunequipfn = nil
    wp.AnimState:SetMultColour(1,1,1,0)
    wp.components.equippable.equipslot = self.equipslot
    wp.components.inventoryitem:ChangeImageName('xxxxx')
    wp.tags_map = {}
    wp.persists = false
    return wp
end

---comment
---@param player ent
---@param newtags tagID[]
function %(modid)s_player_addequiptag:AddTags(player,newtags)
    assert(self.equipslot ~= nil, 'Component %(modid)s_player_addequiptag: Please call the Init method to assign a new equipslot first !')
    if player and player:HasTag('player') then
        -- 获取当前装备的所有有用的tag
        local old = player.components.inventory:GetEquippedItem(self.equipslot)
        ---@cast old ent_%(modid)s_player_addequiptag
        -- 移除旧装备 生成新装备 数据传输 添加tag 并刷新装备状态
        local new = self:_createVoidEquip()
        if old and old:IsValid() then
            for k,v in pairs(old.tags_map) do
                new.tags_map[k] = SourceModifierList(new, false, SourceModifierList.boolean)
                for src_ent,v2 in pairs(v._modifiers or {}) do                    
                    for key,modifier_val in pairs(v2.modifiers or {}) do
                        new.tags_map[k]:SetModifier(src_ent, modifier_val, key)
                    end
                end
            end
            old:Remove()
        end
        old = nil
        for _,tag in ipairs(newtags) do
            if new.tags_map[tag] == nil or not new.tags_map[tag]:Get() then
                new.tags_map[tag] = nil
                new.tags_map[tag] = SourceModifierList(new, false, SourceModifierList.boolean)
            end
            new.tags_map[tag]:SetModifier(self.inst,true,'dst_lan')
            new:AddTag(tag)
        end
        self:_Silent(player)
        player.components.inventory:Equip(new,nil,true)
        if new.parent then
            new.parent:RemoveChild(new)
        end
    end
end

---comment
---@param player ent|nil
---@param newtags tagID[]
function %(modid)s_player_addequiptag:RemoveTags(player,newtags)
    player = player or ( self.inst.components.inventoryitem and self.inst.components.inventoryitem:GetGrandOwner() ) or nil
    if player and player:HasTag('player') then
        -- 获取当前装备的所有有用的tag
        local old = player.components.inventory:GetEquippedItem(self.equipslot)
        ---@cast old ent_%(modid)s_player_addequiptag
        -- 移除旧装备 生成新装备 数据传输 添加tag 并刷新装备状态
        local new = self:_createVoidEquip()
        if old and old:IsValid() then
            for k,v in pairs(old.tags_map) do
                new.tags_map[k] = SourceModifierList(new, false, SourceModifierList.boolean)
                for src_ent,v2 in pairs(v._modifiers or {}) do
                    for key,modifier_val in pairs(v2.modifiers or {}) do
                        new.tags_map[k]:SetModifier(src_ent, modifier_val, key)
                    end
                end
            end
            -- new.tags_map = deepcopy(old.tags_map) or {}
            old:Remove()
        end
        old = nil
        for _,tag in ipairs(newtags) do
            if new.tags_map[tag] == nil then
                new:RemoveTag(tag)
            else
                if not new.tags_map[tag]:Get() then
                    new.tags_map[tag] = nil
                    new:RemoveTag(tag)
                else
                    new.tags_map[tag]:RemoveModifier(self.inst,'dst_lan')
                    if not new.tags_map[tag]:Get() then
                        new.tags_map[tag] = nil
                        new:RemoveTag(tag)
                    else
                        new:AddTag(tag)
                    end
                end
            end
        end
        self:_Silent(player)
        player.components.inventory:Equip(new,nil,true)
        if new.parent then
            new.parent:RemoveChild(new)
        end
    end
end

---comment
---@param player ent
---@private
function %(modid)s_player_addequiptag:_Silent(player)
    SendModRPCToClient(GetClientModRPC(modid,'dstlan_silent_addequiptag'),player.userid)
    self._silent = true
end

---comment
---@return boolean
---@nodiscard
function %(modid)s_player_addequiptag:_ShouldSilent()
    return self._silent
end

function %(modid)s_player_addequiptag:_ResetSilent()
    self._silent = false
end

return %(modid)s_player_addequiptag