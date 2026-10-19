-- hide
-- 功能(需要填写): 勾 event

---@class hook_event_sg
---@field fn fun(equips_map: table<PrefabID, ent>,player: ent):boolean # `equips_map`: 一张表,含所有装备中的物品,键为prefab id,值引用实体, 返回值为true时则拦截事件，返回值为false则不拦截事件
---@field client_fn fun(inst: ent)|nil # 客户端触发的函数

---@type table<eventID, table<string, hook_event_sg>>
local allevents = {
    -- ['attacked'] = { -- 挨打事件
    --     overlordbloodarmor_and_demonicembracehat = { -- 唯一id
    --         fn =  function (equips_map,player)
    --             if equips_map['lol_wp_overlordbloodarmor'] and equips_map['lol_wp_demonicembracehat'] then
    --                 return true
    --             end
    --             return false
    --         end,
    --         client_fn = function (inst) -- 客户端依旧添加挨打时的视觉效果
    --             if inst and inst.HUD and inst.HUD.bloodover then
    --                 inst.HUD.bloodover:Flash()
    --             end
    --         end
    --     }
    -- },
    -- ['knockback'] = { -- 击飞事件
    -- },
    -- ['knockedout'] = { -- 醉酒事件?

    -- }
    -- ['freeze'] = {},
    -- ['startfiredamage'] = {},
    -- ['firedamage'] = {},
}

AddReplicableComponent('event_trigger_%(modid)s')

AddPlayerPostInit(function (inst)
    inst:ListenForEvent('event_trigger_%(modid)s_triggered',function ()
        if inst == ThePlayer and inst.replica.event_trigger_%(modid)s then
            local event_name = inst.replica.event_trigger_%(modid)s:GetEventName() or ''
            if event_name == '' then
                return
            end
            local type = inst.replica.event_trigger_%(modid)s:GetType() or ''
            if type == '' then
                return
            end
            local fn = allevents[event_name] and allevents[event_name][type] and allevents[event_name][type].client_fn
            if fn then
                fn(inst)
            end
        end
    end)

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent('event_trigger_%(modid)s')
end)

local old_PushEvent = EntityScript.PushEvent
function EntityScript:PushEvent(event,data,...)
    -- 筛选事件
    if allevents[event] then
        -- 筛选player
        if self and self.components.event_trigger_%(modid)s then
            local type -- 被哪个type拦了
            -- hook
            local allow = true
            local equips = SUGAR_%(modid)s:getAllEquipments(self)
            for k,rule in pairs(allevents[event]) do
                if rule.fn and rule.fn(equips,self) then
                    allow = false
                    type = k
                    break
                end
            end
            -- 如果被拦了
            if not allow then
                -- 判断是否有type
                if type then
                    -- 传递数据
                    self.components.event_trigger_%(modid)s:Push(event,type)
                end
                return
            end
        end
    end
    return old_PushEvent(self,event,data,...)
end

local old_HandleEvent = State.HandleEvent
function State:HandleEvent(sg,eventame,data,...)
    local inst = self.inst
    if allevents[sg] then
        if inst and inst.components.event_trigger_%(modid)s then
            local allow = true
            local equips = SUGAR_%(modid)s:getAllEquipments(inst)
            for k,rule in pairs(allevents[sg]) do
                if rule.fn and rule.fn(equips,inst) then
                    allow = false
                    break
                end
            end
            if not allow then
                return
            end
        end
    end
    return old_HandleEvent(self,sg,eventame,data,...)
end