-- hide
-- 当你使用官方组件来写技能时,貌似会因为没有正确移除 reticule 组件,导致玩家的轮盘施法放不出来,本文件就是用来修复这个bug的

AddComponentPostInit('aoetargeting',
---comment
---@param self component_aoetargeting
function (self)
    function self:StartTargeting()
        if ThePlayer ~= nil and ThePlayer.components.playercontroller ~= nil then
            if self.inst.replica.inventoryitem ~= nil and self.inst.replica.inventoryitem:IsGrandOwner(ThePlayer) then
                if self.inst.components.reticule == nil then
                    self.inst:AddComponent("reticule")
                end
                for k, v in pairs(self.reticule) do
					self.inst.components.reticule[k] = v
				end
				ThePlayer.components.playercontroller:RefreshReticule(self.inst)
            end
        end
    end
end)