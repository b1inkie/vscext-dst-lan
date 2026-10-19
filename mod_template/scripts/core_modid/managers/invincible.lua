-- hide
-- 功能(无需修改): 设置无敌的
-- 方法都在health组件中
-- 设置无敌,但回血可以回,只是不能扣血,同时该无敌不能被无视掉

---@type SourceModifierList
local SourceModifierList = require("util/sourcemodifierlist")

AddComponentPostInit('health',
---comment
---@param self component_health
function (self)

    self._dst_lan_invincible_modifier = SourceModifierList(self.inst,false,SourceModifierList.boolean)

    function self:ModifierLanInvincible(source,m,key)
        self._dst_lan_invincible_modifier:SetModifier(source,m,key)
    end

    function self:RemoveModifierLanInvincible(source,key)
        self._dst_lan_invincible_modifier:RemoveModifier(source,key)
    end

    function self:CheckIsLanInvincible()
        ---@diagnostic disable-next-line: inject-field
        return self._dst_lan_invincible_modifier:Get()
    end

end)