---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---@class api_stack 自定义堆叠API
local dst_lan = {}

---修改堆叠(客户端)
---@private
function dst_lan:hookReplica()
    AddClassPostConstruct("components/stackable_replica", function(self)
        -- 原堆叠上限是4095,如果超过这个数,则需要重新构造 _ctor来修改注册的网络变量,因为网络变量不可以重复注册
        local old_SetMaxSize = self.SetMaxSize
        function self:SetMaxSize(maxsize,...)
            local stack = self.inst.prefab and TUNING.LAN_STACK[string.upper(self.inst.prefab)]
            if stack ~= nil then
                return
            end

            return old_SetMaxSize(self,maxsize,...)
        end
    
        local old_MaxSize = self.MaxSize
        function self:MaxSize(...)
            local stack = self.inst.prefab and TUNING.LAN_STACK[string.upper(self.inst.prefab)]
            if stack ~= nil then
                return self._ignoremaxsize:value() and math.huge or stack
            end
            return old_MaxSize(self,...)
        end
    
        local old_OriginalMaxSize = self.OriginalMaxSize
        function self:OriginalMaxSize(...)
            local stack = self.inst.prefab and TUNING.LAN_STACK[string.upper(self.inst.prefab)]
            if stack ~= nil then
                return stack
            end
            return old_OriginalMaxSize(self,...)
        end
    end)
end

---修改堆叠(服务器端)
---@private
function dst_lan:setMaxStackSize(tbl)
    if TUNING.LAN_STACK == nil then 
        TUNING.LAN_STACK = {}
    end
    for k,v in pairs(tbl) do
        TUNING.LAN_STACK[string.upper(k)] = v

        AddPrefabPostInit(k, function(inst)
            inst.prefab = k 
            if not TheWorld.ismastersim then
                return inst
            end
            if inst.components.stackable == nil then
                inst:AddComponent("stackable")
            end
            inst.components.stackable.maxsize = v
        end)
    end
end

---主函数
---@param tbl table<string, number> 欲修改堆叠的prefab表
function dst_lan:main(tbl)
    self:setMaxStackSize(tbl)
    self:hookReplica()
end

return dst_lan