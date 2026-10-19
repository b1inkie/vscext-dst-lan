-- hide
-- 功能(需要填写): 击杀获取能力模板

---1. (填写)数据表: core_%(modid)s/data/killability.lua
---2. 组件和replica: %(modid)s_killability

---给哪些角色添加
local avatar_prefabs = {
    -- 'webbert',
}
AddReplicableComponent('%(modid)s_killability')
for _,v in ipairs(avatar_prefabs) do
    AddPrefabPostInit(v, function (inst)
        if not TheWorld.ismastersim then
            return inst
        end
        inst:AddComponent('%(modid)s_killability')
    end)
end