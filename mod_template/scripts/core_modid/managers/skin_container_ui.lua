-- hide
-- 功能(需要填写): 箱子的UI皮肤


---@type table<string,data_skin_containerwidget> # 键为容器的prefab
local map = {

}

AddClassPostConstruct('widgets/containerwidget',
---comment
---@param self widget_containerwidget
---@param ... unknown
function (self, ...)
    local old_Open = self.Open
    function self:Open(container, doer, ...)
        if old_Open ~= nil then
            old_Open(self, container, doer, ...)
        end
        local box = self.container
        if box and box.prefab then
            local box_data = map[box.prefab]
            if box_data then
                local cur_box_build = box.AnimState:GetBuild()
                if cur_box_build ~= nil and cur_box_build ~= box_data.default_box_build then
                    local skin_data = box_data.skins and box_data.skins[cur_box_build]
                    if skin_data then
                        local scaleandpos = skin_data.scaleandpos
                        if scaleandpos then
                            self.bganim:GetAnimState():SetBuild(skin_data.ui_build)
                            self.bganim:SetScale(scaleandpos[1],scaleandpos[2],1)
                            self.bganim:SetPosition(scaleandpos[3],scaleandpos[4],0)
                        end

                        if skin_data.slot_xml and skin_data.slot_tex then
                            for _,v in ipairs(self.inv) do
                                v.bgimage:SetTexture(skin_data.slot_xml, skin_data.slot_tex)
                            end
                        end
                    end
                else
                    local default_scaleandpos = box_data.default_scaleandpos
                    self.bganim:SetScale(default_scaleandpos[1],default_scaleandpos[2],1)
                    self.bganim:SetPosition(default_scaleandpos[3],default_scaleandpos[4],0)
                end
            end
        end
    end
end)
