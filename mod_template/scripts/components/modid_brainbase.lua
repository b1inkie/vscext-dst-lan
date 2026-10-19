local Coords,Sugar = COORDS_%(modid)s,SUGAR_%(modid)s

---@class components
---@field %(modid)s_brainbase component_%(modid)s_brainbase

---@class component_%(modid)s_brainbase: component_base
---@field inst ent
---@field _task any
---@field master ent|nil # 引用一下绑定的主人
---@field customgetmasterfn (fun(this:ent):ent|nil)|nil # 自定义获取主人的函数
---@field stopthink_interval number|nil # 停止思考时的sleep时间
---@field x number # 线程中用(一定不为nil): 自己的x坐标
---@field z number # 线程中用(一定不为nil): 自己的z坐标
---@field pt Vector3 # 线程中用(一定不为nil): 自己的pt
---@field x_m number # 线程中用(一定不为nil): master的x坐标
---@field z_m number # 线程中用(一定不为nil): master的z坐标
---@field pt_m Vector3 # 线程中用(一定不为nil): master的pt
---@field force_tp_dist number # 强制传送距离
---@field force_tp_rethink number # 强制传送后,rethink时间
---@field force_tp_failed_rethink number # 强制传送失败时,rethink时间
---@field force_follow_dist number # 强制跟随距离
---@field force_follow_radius number # 强制跟随的圆环半径
---@field force_follow_rethink number # 强制跟随后,rethink时间
---@field follow_dist number # 常规跟随距离
---@field follow_rethink number # 跟随后,rethink时间
---@field wander_radius number|nil # wander半径
---@field wander_rethink number|nil # wander后, rethink间隔
---@field wander_failed_rethink number|nil # wander失败时, rethink间隔
---@field protect_rethink number|nil # 保险用rethink间隔
---@field _initialized boolean|nil # 是否已经初始化
---@field mainbehavelist_highpriority ((fun(base:component_%(modid)s_brainbase,me:ent,master:ent):number|nil)|CBT)[] # 自定义行为逻辑列表
---@field mainbehavelist ((fun(base:component_%(modid)s_brainbase,me:ent,master:ent):number|nil)|CBT)[] # 自定义行为逻辑列表
---@field forceexitbehavelists CBT[] # 强制退出并reset的behave列表
---@field _lastsuccessbehaveexitfn fun(this,base:component_%(modid)s_brainbase,me:ent,master:ent)|nil # 上一个执行成功的behave的forceexitfn,(暂时废弃)
local %(modid)s_brainbase = Class(
---@param self component_%(modid)s_brainbase
---@param inst ent
function(self, inst)
    self.inst = inst
    self.master = nil
    self.mainbehavelist_highpriority = {}
    self.mainbehavelist = {}
    self.forceexitbehavelists = {}
    local cmp = self
    self._task = inst:DoTaskInTime(2+UnitRand(),function ()
        if inst == nil or not inst:IsValid() then return end
        assert(cmp._initialized, "请调用组件%(modid)s_brain:Init()来初始化")
        inst.Physics:Stop()
        inst.components.locomotor:Stop()
        inst:StartThread(function ()
            repeat repeat
                -- //不存在 
                if cmp == nil then Sleep(5) break end
                -- //停止思考
                if cmp.stopthink_interval then cmp:Sleep(cmp.stopthink_interval) break end
                -- //没有主人
                local master = cmp:GetMasterValid()
                if master == nil then cmp:Sleep(5) break end
                -- 获取坐标
                local pt = inst:GetPosition() if pt == nil then cmp:Sleep(3) break end
                cmp.pt = pt local x,_,z = pt:Get() cmp.x,cmp.z = x,z
                local pt_m = master:GetPosition() if pt_m == nil then cmp:Sleep(3) break end
                cmp.pt_m = pt_m local x_m,_,z_m = pt_m:Get() cmp.x_m,cmp.z_m = x_m,z_m
                -- 获取距离
                local dist = Coords:calcDist(x,z,x_m,z_m,true)
                -- // mainbehavelist_highpriority
                if cmp.mainbehavelist_highpriority then
                    local rethinktime = cmp.stopthink_interval
                    for _,behavefn in ipairs(cmp.mainbehavelist_highpriority) do
                        if type(behavefn) == 'function' then
                            rethinktime = behavefn(cmp,inst,master)
                        else
                            rethinktime = behavefn:_Run(cmp,inst,master)
                        end
                        if rethinktime then break end
                    end
                    if rethinktime then cmp:Sleep(rethinktime) break end
                end
                -- //强制传送距离
                if dist > cmp.force_tp_dist then
                    local des_x,des_z = Coords:GenPointInCircle(x_m,z_m,3)()
                    local cur_tile = TheWorld.Map:GetTileAtPoint(des_x,0,des_z)
                    -- 如果是虚空或海洋 跳过这一轮检测
                    if cur_tile == 65535 or cur_tile == 1 or (cur_tile >= 201 and cur_tile <= 208) then
                        cmp:Sleep(cmp.force_tp_rethink) break -- 强制传送失败
                    end
                    cmp:Say("距离过远,强制传送")
                    cmp:ForceExit(cmp,inst,master) -- 强制reset
                    inst.Transform:SetPosition(des_x,0,des_z)
                    cmp:Sleep(cmp.force_tp_failed_rethink) break -- 强制传送成功
                -- //强制跟随距离
                elseif dist > cmp.force_follow_dist then
                    local des_x,des_z = Coords:GenPointOnRing(x_m,z_m,4.5)()
                    cmp:Say("距离稍远,强制跟随")
                    cmp:ForceExit(cmp,inst,master) -- 强制reset
                    cmp:GoTo(des_x,des_z)
                    cmp:Sleep(cmp.force_follow_rethink) break -- 不能间隔太高, 否则主人跑太远就追不上了
                end
                -- //在加载外
                if inst:IsAsleep() then cmp:Sleep(5) break end
                -- // mainbehavelist
                if cmp.mainbehavelist then
                    local rethinktime = cmp.stopthink_interval
                    for _,behavefn in ipairs(cmp.mainbehavelist) do
                        if type(behavefn) == 'function' then
                            rethinktime = behavefn(cmp,inst,master)
                        else
                            rethinktime = behavefn:_Run(cmp,inst,master)
                        end
                        if rethinktime then break end
                    end
                    if rethinktime then cmp:Sleep(rethinktime) break end
                end
                -- //常规跟随
                if dist > cmp.follow_dist then
                    cmp:Say("常规跟随")
                    local des_x,des_z = Coords:GenPointOnRing(x_m,z_m,6)()
                    cmp:GoTo(des_x,des_z)
                    cmp:Sleep(cmp.follow_rethink) break -- 不能间隔太高, 否则主人跑太远就追不上了
                end
                -- //wander
                do
                    if cmp.wander_radius then
                        cmp:Say("wander")
                        local des_x,des_z = Coords:GenPointOnRing(x_m,z_m,6)()
                        local _dist = Coords:calcDist(x,z,des_x,des_z,true)
                        if _dist < cmp.wander_radius then
                            cmp:GoTo(des_x,des_z)
                            cmp:Sleep(cmp.wander_rethink) break -- 重启动间隔久一些, 到这里玩家基本等于在挂机了
                        end
                        cmp:Sleep(cmp.wander_rethink) break -- wander失败
                    end
                end

                -- // potect threadtask
                cmp:Sleep(cmp.protect_rethink)
            until true until false
        end)
    end)

    -- -- 人物的sg有各种问题 故做此处理 宠物可以删掉
    -- inst:ListenForEvent('death',function (this, data)
    --     local pt = inst:GetPosition()
    --     local _fx = SpawnPrefab('fx_%(modid)s_misc')
    --     ---@cast _fx ent_fx
    --     _fx:fn_fx_%(modid)s_misc('wilson','%(modid)s','death',false,true,nil,nil,pt)

    --     cmp:RemoveImmediately()
    -- end)

    local old_Remove = inst.Remove
    function inst:Remove(...)
        cmp:RemoveImmediately(true)
        return old_Remove(self,...)
    end

    -- 防止别人停不掉
    function inst:RestartBrain()
        cmp:StartThink()
    end
    function inst:StopBrain()
        cmp:StopThink(3)
    end
end)

---初始化:一定要调用(防止你不看),但是可以几乎不用填
---@param useentbindcmp_or_customgetmasterfn true|(fun(this:ent):ent|nil) # 填true则使用插件提供的组件`avemujica_ent_bind_child`来获取master,填函数则使用自定义获取主人的函数
---@param force_tp_dist number|nil # 强制传送距离
---@param force_tp_rethink number|nil # 强制传送后,rethink时间
---@param force_tp_failed_rethink number|nil # 强制传送失败时,rethink时间
---@param force_follow_dist number|nil # 强制跟随距离
---@param force_follow_radius number|nil # 强制跟随的圆环半径
---@param force_follow_rethink number|nil # 强制跟随后,rethink时间
---@param follow_dist number|nil # 常规跟随距离
---@param follow_rethink number|nil # 跟随后,rethink时间
---@param wander_radius number|nil # wander半径,不填则不wander
---@param wander_rethink number|nil # wander后, rethink间隔
---@param wander_failed_rethink number|nil # wander失败时, rethink间隔
---@param protect_rethink number|nil # 保险用rethink间隔
function %(modid)s_brainbase:Init(useentbindcmp_or_customgetmasterfn,force_tp_dist,force_tp_rethink,force_tp_failed_rethink,force_follow_dist,force_follow_radius,force_follow_rethink,follow_dist,follow_rethink,wander_radius,wander_rethink,wander_failed_rethink,protect_rethink)
    if type(useentbindcmp_or_customgetmasterfn) == 'function' then
        self.customgetmasterfn = useentbindcmp_or_customgetmasterfn
    end
    self.force_tp_dist = force_tp_dist or 50
    self.force_tp_rethink = force_tp_rethink or 2
    self.force_tp_failed_rethink = force_tp_failed_rethink or 2
    self.force_follow_dist = force_follow_dist or 15
    self.force_follow_radius = force_follow_radius or 4.5
    self.force_follow_rethink = force_follow_rethink or 2
    self.follow_dist = follow_dist or 8
    self.follow_rethink = follow_rethink or 2
    self.wander_radius = wander_radius or 6
    self.wander_rethink = wander_rethink or 5
    self.wander_failed_rethink = wander_failed_rethink or 5

    self.protect_rethink = protect_rethink or 6
    self._initialized = true
end

---
---@param player ent
function %(modid)s_brainbase:SetMaster(player)
    self.master = player
end

---获取主人并且是valid
---@return ent|nil
---@nodiscard
function %(modid)s_brainbase:GetMasterValid()
    local inst = self.inst
    -- 设置了主人就直接获取 没设置就用自己写的绑定逻辑 或者 从绑定组件里找
    local master =  self.master or (self.customgetmasterfn and self.customgetmasterfn(inst)) or (inst.components.%(modid)s_ent_bind_child and inst.components.%(modid)s_ent_bind_child:GetMaster())
    if master and master:IsValid() then
        self.master = master
        return master
    end
    return nil
end

---(仅在线程中调用)一定能获取到主人,不在线程中时,请调用`GetMasterValid`
---@return ent
---@nodiscard
function %(modid)s_brainbase:GetMaster()
    return self.master
end

---comment
---@param time number|nil
function %(modid)s_brainbase:StopThink(time)
    self.stopthink_interval = time or 5
end

function %(modid)s_brainbase:StartThink()
    self.stopthink_interval = nil
end

---comment
---@param time number
function %(modid)s_brainbase:Sleep(time)
    Sleep(time)
end

---comment
---@param x number
---@param z number
function %(modid)s_brainbase:GoTo(x,z)
    self.inst.components.locomotor:GoToPoint(Vector3(x,0,z))
end

---comment
---@param ent ent
---@param bufferedaction any
---@param run any
function %(modid)s_brainbase:GoToEntity(ent,bufferedaction,run)
    self.inst.components.locomotor:GoToEntity(ent,bufferedaction,run)
end

---debug用的,让child说话
---@param str string
---@param talk_or_annouce boolean|nil
function %(modid)s_brainbase:Say(str,talk_or_annouce)
    -- * 可以将下面这段注释掉, 而不是删掉这个函数
    -- if not talk_or_annouce then
    --     Sugar:declare(str)
    -- elseif self.inst.components.talker then
    --     self.inst.components.talker:Say(str,nil,true,true)
    -- end
end

---高优先级节点打断普通优先级节点时,执行
---@param base component_%(modid)s_brainbase
---@param me ent
---@param master ent
function %(modid)s_brainbase:ForceExit(base,me,master)
    for _,v in ipairs(self.forceexitbehavelists) do
        v.forceexitfn(v,base,me,master)
    end
end

---comment
---@param dont_remove boolean|nil # 不调用`:Remove()`
function %(modid)s_brainbase:RemoveImmediately(dont_remove)
    if self._task then
        self:StopThink(99)
        KillThreadsWithID(self._task)
        if not dont_remove then
            self.inst:Remove()
        end
    end
end
return %(modid)s_brainbase