---@diagnostic disable: lowercase-global, undefined-global, trailing-space
---@diagnostic disable: return-type-mismatch, inject-field, undefined-field, need-check-nil

-- exported/custom_status_meter_01
-- ├── bg 背景(可自行更换)
-- ├── frame_circle badge相框的基础样式
-- ├── level *勿动(计量条)
-- ├── power_stage 用于增加badge相框的样式,可自行添加,s1为基础样式
-- └── custom_status_meter.scml animzipname

-- 一般来说,badge显示的肯定是和prefab有关的某个属性,所以一般会写一个组件,用于处理这个属性,以及一个客机组件,用于同步badge显示的数值

local Badge = require "widgets/badge"
local UIAnim = require "widgets/uianim"

---@class api_badge # badge API
local dst_lan = {}

---badge widget
---@param animzipname string
---@param meter_color RGBA
---@param meter_maxnum number
---@param nobackgroud boolean|nil # 没有背景,默认有
---@param hide_at_first boolean|nil # 默认不隐藏
---@return class
---@private
function dst_lan:Widget(animzipname,meter_color,meter_maxnum,nobackgroud,hide_at_first)
    
    local animpack = animzipname -- anim.zip name, so that it can be shared

    local WidgetPower = Class(Badge, function(self, owner, art)
        Badge._ctor(self, art, owner, meter_color, nil, nil, nil, true)

        self.topperanim = self.underNumber:AddChild(UIAnim())
        self.topperanim:GetAnimState():SetBank(animpack)
        self.topperanim:GetAnimState():SetBuild(animpack)
        self.topperanim:GetAnimState():PlayAnimation("anim")
        self.topperanim:GetAnimState():SetMultColour(unpack(meter_color))
        self.topperanim:SetScale(1, -1, 1)
        self.topperanim:SetClickable(false)
        self.topperanim:GetAnimState():AnimateWhilePaused(false)
        self.topperanim:GetAnimState():SetPercent("anim", 1)

        if self.circleframe ~= nil then
            self.circleframe:GetAnimState():Hide("frame")
        else
            self.anim:GetAnimState():Hide("frame")
        end

        self.circleframe2 = self.underNumber:AddChild(UIAnim())
        self.circleframe2:GetAnimState():SetBank(animpack)
        self.circleframe2:GetAnimState():SetBuild(animpack)
        self.circleframe2:GetAnimState():PlayAnimation("frame")
        self.circleframe2:GetAnimState():AnimateWhilePaused(false)

        self.sanityarrow = self.underNumber:AddChild(UIAnim())
        self.sanityarrow:GetAnimState():SetBank("sanity_arrow")
        self.sanityarrow:GetAnimState():SetBuild("sanity_arrow")
        self.sanityarrow:GetAnimState():PlayAnimation("neutral")
        self.sanityarrow:SetClickable(false)
        self.sanityarrow:GetAnimState():AnimateWhilePaused(false)

        self.meter_maxnum = meter_maxnum
        
        self.backing:GetAnimState():SetBank(animpack)
        self.backing:GetAnimState():SetBuild(animpack)
        self.backing:GetAnimState():PlayAnimation("bg")
        if nobackgroud then
            self.backing:GetAnimState():SetMultColour(0,0,0,0)
        end

        self:SetStage(1)
        self:StartUpdating()

        self:SetPercent(0,meter_maxnum)

        if hide_at_first then
            self:Hide()
        end
    end)


    function WidgetPower:SetPercent(val, max, penaltypercent) -- val is 0~1
        val = val or 0

        max = max or self.meter_maxnum
        
        Badge.SetPercent(self, val/max, max)

        penaltypercent = penaltypercent or 0
        self.topperanim:GetAnimState():SetPercent("anim", 1 - penaltypercent)
    end

    function WidgetPower:SetStage(stage)
        self.circleframe2:GetAnimState():PlayAnimation("s"..tostring(stage))
    end

    function WidgetPower:OnUpdate(dt)
        if TheNet:IsServerPaused() then return end

        -- local down
        -- if (self.owner.IsFreezing ~= nil and self.owner:IsFreezing()) or
        --     (self.owner.replica.health ~= nil and self.owner.replica.health:IsTakingFireDamageFull()) or
        --     (self.owner.replica.hunger ~= nil and self.owner.replica.hunger:IsStarving()) or
        --     self.acidsizzling ~= nil or
        --     next(self.corrosives) ~= nil then
        --     down = "_most"
        -- elseif self.owner.IsOverheating ~= nil and self.owner:IsOverheating() then
        --     down = self.owner:HasTag("heatresistant") and "_more" or "_most"
        -- end

        -- Show the up-arrow when we're sleeping (but not in a straw roll: that doesn't heal us)
        -- local up = down == nil and self.owner.replica.health ~= nil
            -- (
            --     (   (self.owner.player_classified ~= nil and self.owner.player_classified.issleephealing:value()) or
            --         next(self.hots) ~= nil or next(self.small_hots) ~= nil or
            --         (self.owner.replica.inventory ~= nil and self.owner.replica.inventory:EquipHasTag("regen"))
            --     ) or
            --     (self.owner:HasDebuff("wintersfeastbuff"))
            -- ) and 
            -- self.owner.replica.health ~= nil and self.owner.replica.health:IsHurt()

        -- local anim =
        --     (down ~= nil and ("arrow_loop_decrease"..down)) or
        --     (not up and "neutral") or
        --     (next(self.hots) ~= nil and "arrow_loop_increase_most") or
        --     "arrow_loop_increase"

        -- if self.arrowdir ~= anim then
        --     self.arrowdir = anim
        --     self.sanityarrow:GetAnimState():PlayAnimation(anim, true)
        -- end
    end

    return WidgetPower

end


---生成badge
---@param params data_badge[]
---@private
function dst_lan:UI(params)
    for _, param in pairs(params) do
        table.insert(Assets,Asset("ANIM","anim/" .. param.animzipname .. ".zip"))
        local WidgetPower = self:Widget(param.animzipname,param.meter_color,param.meter_maxnum,param.nobackgroud,param.hide_at_first)
        
        if param.drag_enable then
            WidgetPower:SetTooltip(param.drag_hint or STRINGS.MOD_%(modid_upper)s.DRAG_INFO)
            local old_oldOnControl = WidgetPower.OnControl
            WidgetPower.OnControl = function(self, control, down)
                local offset = .9
                if self.focus and control == CONTROL_SECONDARY then
                    if down then
                        if not self.followhandler then
                            local mousepos = TheInput:GetScreenPosition()
                            self.m_startpos = mousepos       --鼠标初始坐标
                            self.p_startpos = self:GetPosition() --面板初始坐标
                            self.followhandler = TheInput:AddMoveHandler(function(x, y)
                                local pos = Vector3(x, y, 0)
                                local self_scale = self:GetScale()
                                local newpos = self.p_startpos + (pos - self.m_startpos) / (self_scale.x / offset) --修正偏移值
                                self:SetPosition(newpos)
                                if not Input:IsMouseDown(MOUSEBUTTON_RIGHT) then
                                    if self.followhandler then
                                        self.followhandler:Remove()
                                    end
                                    self.followhandler = nil
                                    self.m_startpos = nil
                                    self.p_startpos = nil
                                end
                            end)
                            local self_scale = self:GetScale()
                            local newpos = self.p_startpos + (mousepos - self.m_startpos) / (self_scale.x / offset) --修正偏移值
                            self:SetPosition(newpos)
                        end
                    else
                        if self.followhandler then
                            self.followhandler:Remove()
                        end
                        self.followhandler = nil
                        self.m_startpos = nil
                        self.p_startpos = nil
                        -- local newpos = self:GetPosition()
                    end
                end
                return old_oldOnControl ~= nil and old_oldOnControl(self,control,down) or nil
            end
        end
        
        AddClassPostConstruct('widgets/statusdisplays', function(self)
            if self.owner:HasTag("player") and self.owner.prefab ~= nil and (param.owners == nil or table.contains(param.owners, self.owner.prefab)) then
                self[param.badgeid] = self:AddChild(WidgetPower(self.owner))
                self[param.badgeid]:SetPosition(unpack(param.pos))
                self.inst:ListenForEvent(param.eventname,function()
                    param.eventfn(self[param.badgeid],self.owner)
                    -- self[param.badgeid]:SetStage(stage)
                    -- self[param.badgeid]:SetPercent(power)
                end,self.owner)
            end
        end)
    end
end

---main
---@param params data_badge[]
function dst_lan:main(params)
    self:UI(params)
end

return dst_lan