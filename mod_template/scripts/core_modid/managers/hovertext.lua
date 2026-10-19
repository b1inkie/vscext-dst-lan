-- hide
-- 功能(无需修改): 添加悬浮提示


-- AddPrefabPostInit(k,function (inst)
------------------------------------------------
------------------------------------------------
--[[  将下面拷贝到预制物,修改 _res 即可
    inst:DoTaskInTime(0,function ()
        local old_GetNearBytHoverExtendHint = inst.GetNearBytHoverExtendHint
        function inst:GetNearBytHoverExtendHint(...)
            local res,offset = nil,nil
            if old_GetNearBytHoverExtendHint ~= nil then
                res,offset = old_GetNearBytHoverExtendHint(self,...)
            end
            res = res or ''
            offset = offset or 0
            local _res = ''
            return res.._res,offset
        end
    end)
]]
------------------------------------------------
------------------------------------------------
--     if not TheWorld.ismastersim then
--         return inst
--     end
-- end)

---@class ent
---@field GetNearBytHoverExtendHint (fun():string,number|nil)|nil # 在主信息左右显示的hover提示<br> 第一个返回值是字符串,第二个是x轴偏移量 <br> 由于初始偏移较小,如果单行文字过长,可以考虑限制单行字数,或者设置这个偏移量

---@type widget_text
local Text = require 'widgets/text'

---@class widget_hoverer_webbert : widget_hoverer
---@field nearby_text widget_text

AddClassPostConstruct('widgets/hoverer',
---comment
---@param self widget_hoverer_webbert
function (self)
    if self.nearby_text == nil then
        self.nearby_text = self.text:AddChild(Text(UIFONT, 30))
        self.nearby_text:SetPosition(self.default_text_pos)
        local old_OnUpdate = self.OnUpdate
        function self:OnUpdate(...)
            local res = old_OnUpdate(self,...)
            if self.owner.components.playercontroller == nil or not self.owner.components.playercontroller:UsingMouse() then
                self.nearby_text:SetString('')
            elseif not self.forcehide then
                local tar = TheInput:GetHUDEntityUnderMouse()
                tar = tar and tar.widget and tar.widget.parent and tar.widget.parent.item or TheInput:GetWorldEntityUnderMouse()
                if tar and tar.entity and tar.prefab then
                    local tar_prefab = tar.prefab
                    local extra_hint = nil
                    local extend_hint,x_offset = nil,nil
                    if tar.GetNearBytHoverExtendHint then
                        extend_hint,x_offset = tar:GetNearBytHoverExtendHint()
                    end

                    extra_hint = ''

                    local _hint = extra_hint and (extend_hint and (extra_hint .. "\n" .. extend_hint) or extra_hint) or extend_hint
                    if _hint and _hint ~= '' then
                        self.nearby_text:SetString(_hint)

                        local pos = TheInput:GetScreenPosition()
                        local scale = self:GetScale()
                        local scr_w, scr_h = TheSim:GetScreenSize()
                        local w = 0
                        -- local h = 0

                        if self.text ~= nil and self.str ~= nil then
                            local w0, h0 = self.text:GetRegionSize()
                            w = math.max(w, w0)
                            -- h = math.max(h, h0)
                        end
                        if self.secondarytext ~= nil and self.secondarystr ~= nil then
                            local w1, h1 = self.secondarytext:GetRegionSize()
                            w = math.max(w, w1)
                            -- h = math.max(h, h1)
                        end

                        w = w * scale.x * .5
                        -- h = h * scale.y * .5

                        local offset = (pos.x > scr_w/2 and -1 or 1) * (w + 100 + (x_offset or 0))
                        self.nearby_text:SetPosition(self.default_text_pos + Vector3(offset,50,0))
                    end
                else
                    self.nearby_text:SetString('')
                end
            end
            return res
        end
    end
end)