-- show
-- 杂项

local modid = '%(modid)s'

--------------------------------------------------------------
--------------------%(modid)s_addequiptag 组件----------------
----------------------若要启用 请去掉下面的注释-----------------
--------------------------------------------------------------

-- -- 添加一个slot 用于 `%(modid)s_addequiptag` 组件.
-- EQUIPSLOTS.EXTRA_VOIDEQUIP = 'extra_voidequip'
-- -- 禁止在特殊槽位装卸装备时播放动画
-- local old_PushEvent = StateGraphInstance.PushEvent
-- function StateGraphInstance:PushEvent(event,data,...)
--     ---@cast data event_data_equip
--     if event == 'equip' and data and data.eslot and data.eslot == EQUIPSLOTS.EXTRA_VOIDEQUIP then
--         return
--     ---@cast data event_data_unequip
--     elseif event == 'unequip' and data and data.eslot and data.eslot == EQUIPSLOTS.EXTRA_VOIDEQUIP then
--         return
--     end
--     return old_PushEvent ~= nil and old_PushEvent(self,event,data,...) or nil
-- end

-- -- 禁止在特殊槽位装卸装备时播放声音
-- local old_PlaySound = SoundEmitter.PlaySound
-- SoundEmitter.PlaySound = function(emitter, event, name, volume, ...)

--     if event == 'dontstarve/wilson/equip_item' then

--         if ThePlayer and ThePlayer.components.%(modid)s_player_addequiptag and ThePlayer.components.%(modid)s_player_addequiptag:_ShouldSilent() then
--             ThePlayer.components.%(modid)s_player_addequiptag:_ResetSilent()
--             volume = 0
--         end

--         if ThePlayer and ThePlayer.dstlan_silent_addequiptag then
--             ThePlayer.dstlan_silent_addequiptag = nil
--             volume = 0
--         end

--     end
--     return old_PlaySound ~= nil and old_PlaySound(emitter, event, name, volume, ...) or nil
-- end

-- -- 注册客机rpchandler,需要silent时flag一下
-- AddClientModRPCHandler(modid,'dstlan_silent_addequiptag',function ()
--     if ThePlayer then
--         ThePlayer.dstlan_silent_addequiptag = true
--     end
-- end)

-- -- 给玩家添加`%(modid)s_player_addequiptag`组件
-- AddPlayerPostInit(function (inst)
--     if not TheWorld.ismastersim then
--         return inst
--     end
--     if inst.components.%(modid)s_player_addequiptag == nil then
--         inst:AddComponent('%(modid)s_player_addequiptag')
--         inst.components.%(modid)s_player_addequiptag:_Init(EQUIPSLOTS.EXTRA_VOIDEQUIP)
--     end
-- end)

--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------