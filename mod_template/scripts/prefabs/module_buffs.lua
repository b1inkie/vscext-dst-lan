-------------------------------------------------------------------------
----------------------- Prefab building functions -----------------------
-------------------------------------------------------------------------

local function OnTimerDone(inst, data)
    if data.name == "buffover" then
        inst.components.debuff:Stop()
    end
end

---comment
---@param name string
---@param params data_buff
local function MakeBuff(name, params)
    local ATTACH_BUFF_DATA = {
        buff = "ANNOUNCE_ATTACH_BUFF_"..string.upper(name),
        priority = params.priority
    }
    local DETACH_BUFF_DATA = {
        buff = "ANNOUNCE_DETACH_BUFF_"..string.upper(name),
        priority = params.priority
    }

    local function OnAttached(inst, target)
        inst.entity:SetParent(target.entity)
        inst.Transform:SetPosition(0, 0, 0) --in case of loading
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)

        target:PushEvent("foodbuffattached", ATTACH_BUFF_DATA)
        if params.onattachedfn ~= nil then
            params.onattachedfn(inst, target, name)
        end
    end

    local function OnExtended(inst, target)
        inst.components.timer:StopTimer("buffover")
        inst.components.timer:StartTimer("buffover", params.duration, params.paused)

        target:PushEvent("foodbuffattached", ATTACH_BUFF_DATA)
        if params.onextendedfn ~= nil then
            params.onextendedfn(inst, target, name)
        end
    end

    local function OnDetached(inst, target)
        if params.ondetachedfn ~= nil then
            params.ondetachedfn(inst, target, name)
        end

        target:PushEvent("foodbuffdetached", DETACH_BUFF_DATA)
        inst:Remove()
    end

    local function fn()
        local inst = CreateEntity()

        if not TheWorld.ismastersim then
            --Not meant for client!
            inst:DoTaskInTime(0, inst.Remove)
            return inst
        end

        inst.entity:AddTransform()

        --[[Non-networked entity]]
        --inst.entity:SetCanSleep(false)
        inst.entity:Hide()
        inst.persists = false

        inst:AddTag("CLASSIFIED")

        inst:AddComponent("debuff")
        inst.components.debuff:SetAttachedFn(OnAttached)
        inst.components.debuff:SetDetachedFn(OnDetached)
        inst.components.debuff:SetExtendedFn(OnExtended)
        inst.components.debuff.keepondespawn = true

        inst:AddComponent("timer")
        if params.duration then
            inst.components.timer:StartTimer("buffover", params.duration, params.paused)
        end
        inst:ListenForEvent("timerdone", OnTimerDone)

        return inst
    end

    return Prefab("buff_"..name, fn, nil, params.prefabs)
end

---@type data_buff[]
local data = require('core_%(modid)s/data/buffs')
local res = {}
for _,v in ipairs(data) do
    table.insert(res,MakeBuff(v.id,v))
    STRINGS.CHARACTERS.GENERIC['ANNOUNCE_ATTACH_BUFF_'..string.upper(v.id)] = v.attached_string or ' '
    STRINGS.CHARACTERS.GENERIC['ANNOUNCE_DETACH_BUFF_'..string.upper(v.id)] = v.detached_string or ' '
    if STRINGS.NAMES == nil then
        STRINGS.NAMES = {}
    end
    STRINGS.NAMES[string.upper('buff_'..v.id)] = v.buff_string or 'NONAME BUFF'
end

return unpack(res)
