-- hide
-- 功能(需要填写): alt + 左键点击库存物品宣告
-- 将需要宣告的物品的逻辑放在下表中

---@type table<PrefabID, fun(inst:ent)>
local items = {
    -- my_weapon = function (inst)
    --     -- this function is client only
    --     TheNet:Say('快捷宣告')
    -- end,
}


local function tryAnnounce(slot)
    ---@type ent
    local item = slot.tile.item
    if item and item.replica then
        local prefab = item.prefab
        local fn = prefab and items[prefab]
        if fn then
            fn(item)
        end
    end
end

local function couldAnnouce(slot)
    ---@type ent
    local item = slot.tile.item
    local prefab = item and item.prefab
    if prefab and items[prefab] then
        return true
    end
    return false
end

for _,classname in pairs({"invslot", "equipslot"}) do
	local SlotClass = require("widgets/"..classname)
	local SlotClass_OnControl = SlotClass.OnControl
	function SlotClass:OnControl(control, down, ...)
		if down and control == CONTROL_ACCEPT
			-- and TheInput:IsControlPressed(CONTROL_FORCE_INSPECT)
			-- and TheInput:IsControlPressed(CONTROL_FORCE_TRADE)
            -- and TheInput:IsKeyDown(KEY_SHIFT)
            and TheInput:IsKeyDown(KEY_ALT)
			and self.tile and couldAnnouce(self) then -- ignore empty slots
			tryAnnounce(self)
        -- else
        --     return SlotClass_OnControl(self, control, down, ...)
		end
        return SlotClass_OnControl(self, control, down, ...)
	end
end
