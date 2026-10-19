---@class replica_components
---@field event_trigger_%(modid)s replica_event_trigger_%(modid)s

---@class replica_event_trigger_%(modid)s
---@field inst ent
---@field event_name netvar
---@field type netvar
---@field trigger netvar
local event_trigger_%(modid)s = Class(
---@param self replica_event_trigger_%(modid)s
---@param inst ent
function(self, inst)
    self.inst = inst
    self.event_name = net_string(inst.GUID, "event_trigger_%(modid)s.event_name")
    self.type = net_string(inst.GUID, "event_trigger_%(modid)s.type")
    self.trigger = net_bool(inst.GUID, "event_trigger_%(modid)s.trigger",'event_trigger_%(modid)s_triggered')
end)

function event_trigger_%(modid)s:SetEventName(event_name)
    self.event_name:set(event_name)
end

function event_trigger_%(modid)s:GetEventName()
    return self.event_name:value()
end

function event_trigger_%(modid)s:SetType(type)
    self.type:set(type)
end

function event_trigger_%(modid)s:GetType()
    return self.type:value()
end

function event_trigger_%(modid)s:Trigger(value)
    return self.trigger:set(value)
end

return event_trigger_%(modid)s