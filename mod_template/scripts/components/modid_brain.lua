-- 这是一个"组件脑子"
-- 全部都是优先选择节点
-- 添加后先调用`Init`看候选项
-- 如何添加行为: 1. AddTemplateBehave 添加我写的预设行为, 可以配置参数 2. AddCustomBehave 自己写逻辑
-- 最后: 这个组件调用起来特别方便, 但是不建议你用, 除非你知道自己在做什么

local %(modid)s_brainbase = require("components/%(modid)s_brainbase")
local Coords,Sugar = COORDS_%(modid)s,SUGAR_%(modid)s

------------------------------------------------------------------------------------------------------
-- 行为基类

---@class CBT # create behave template
---@field _ctor any
---@field priority_high true|nil # 是否是高优先级行为,是则在强制传送前执行,否则在常规跟随前执行,默认是nil
---@field mainfn fun(this,base:component_%(modid)s_brainbase,me:ent,master:ent):number|nil
---@field event_triggers {event:eventID,source_is_master:boolean|nil,fn:fun(me:ent,master:ent|nil,event_data:table|nil)}[]|nil
---@field forceexitfn nil|(fun(this,base:component_%(modid)s_brainbase,me:ent,master:ent)) # 强制退出并reset的函数 (高优先级节点打断普通优先级节点时,执行)
local CBT = Class(function(self)
    self.event_triggers = {}
end)
---每个行为模板都应有初始化函数用于传参
---@param ... any
function CBT:Init(...)
end

---comment
---@param event eventID
---@param fn fun(me:ent,master:ent|nil,event_data:table|nil)
---@param source_is_master boolean|nil
function CBT:AddEventHandler(event,fn,source_is_master)
    table.insert(self.event_triggers,{event=event,source_is_master=source_is_master,fn=fn})
end

---comment
---@param base component_%(modid)s_brainbase
---@param me ent
---@param master ent
---@return number|nil # **行为执行成功** : 返回值rethink时间 <br> **行为执行失败**: 返回nil,则继续执行剩余的逻辑
---@nodiscard
function CBT:_Run(base,me,master)
    return self.mainfn(self,base,me,master)
end

------------------------------------------------------------------------------------------------------
-- 创建行为模板 behavetemplate_xxx: CBT

--[[

---单个行为模板的主逻辑
---@param self behavetemplate_xxx
---@param base component_%(modid)s_brainbase
---@param me ent
---@param master ent
---@return number|nil #
local function behavetemplate_xxx_mainfn(self,base, me, master)
    return nil
end

---@class behavetemplate_xxx: CBT
---@overload fun(priority_high:boolean|nil):behavetemplate_xxx
local behavetemplate_xxx = Class(CBT,
---@param self behavetemplate_xxx
---@param priority_high boolean|nil
function(self,priority_high)
    CBT._ctor(self)
    self.priority_high = priority_high
    self.mainfn = behavetemplate_xxx_mainfn
end)
---
function behavetemplate_xxx:Init()
end

]]

------------------------------------------------------------------------------------------------------
-- *行为: 战斗躲避

---@param self behavetemplate_combat_evasion
---@param base component_%(modid)s_brainbase
---@param me ent
---@param master ent
---@return number|nil #
local function behavetemplate_combat_evasion_mainfn(self,base, me, master)
    local brain = me.components.%(modid)s_brain
    if master.components.combat and Sugar:taskIfExist(master,'taskintime%(modid)s_brain_flag_masterincombat') then
        local closest = Coords:findClosestEntToPoint(base.x_m,0,base.z_m,self.search_around_enemey_radius,nil,nil,{'_combat','_health'},{"companion","glommer","abigail","INLIMBO","FX","wall","structure","player"})[1]
        if closest then
            local enemy_x,_,enemy_z = closest:GetPosition():Get()
            local des_x,des_z = Coords:findEvadePoint(enemy_x,enemy_z,base.x_m,base.z_m,self.evade_angle,self.min_radius,self.max_radius)
            base:GoTo(des_x,des_z)
            base:Say("正在躲避到玩家身后")
            return 1
        end
        return 2
    end
    return nil
end

---@class behavetemplate_combat_evasion: CBT
---@overload fun(priority_high:boolean|nil):behavetemplate_combat_evasion
---@field leave_battle_time number # 判定进入战斗后离开战斗的时间
---@field search_around_enemey_radius number # 搜索主人附近敌人的半径
---@field evade_angle number # 在主人身后的躲避角度(扇形,角度制)
---@field min_radius number # 躲避的最小范围
---@field max_radius number # 躲避的最大范围
local behavetemplate_combat_evasion = Class(CBT,
---@param self behavetemplate_combat_evasion
---@param priority_high boolean|nil # 是否是高优先级行为,是则在强制传送前执行,否则在常规跟随前执行
function(self,priority_high)
    CBT._ctor(self)
    self.leave_battle_time = 10
    self.search_around_enemey_radius = 6
    self.evade_angle = 70
    self.min_radius = 7
    self.max_radius = 10
    self.priority_high = priority_high
    self.mainfn = behavetemplate_combat_evasion_mainfn
end)
---
---@param leave_battle_time number|nil # 判定进入战斗后离开战斗的时间
---@param search_around_enemey_radius number|nil # 搜索主人附近敌人的半径
---@param evade_angle number|nil # 在主人身后的躲避角度(扇形,角度制)
---@param min_radius number|nil # 躲避的最小范围
---@param max_radius number|nil # 躲避的最大范围
function behavetemplate_combat_evasion:Init(leave_battle_time,search_around_enemey_radius,evade_angle,min_radius,max_radius)
    if leave_battle_time then self.leave_battle_time = leave_battle_time end
    if search_around_enemey_radius then self.search_around_enemey_radius = search_around_enemey_radius end
    if evade_angle then self.evade_angle = evade_angle end
    if min_radius then self.min_radius = min_radius end
    if max_radius then self.max_radius = max_radius end
end

------------------------------------------------------------------------------------------------------
-- 行为模板: 工作(workable)

---@param self behavetemplate_work
---@param base component_%(modid)s_brainbase
---@param me ent
---@param master ent
---@return number|nil #
local function behavetemplate_work_mainfn(self,base, me, master)
    local brain = me.components.%(modid)s_brain
    -- task存在代表玩家还在工作
    if Sugar:taskIfExist(master,self._masterworktask) then
        -- 挑选目标
        local canbeworked_thisround = nil
        if brain[self._cmp_tarfield] == nil or not brain[self._cmp_tarfield]:IsValid() then
            local ents = TheSim:FindEntities(base.x, 0, base.z, self.radius, self.meworktargettags, {"INLIMBO","FX"})
            for _,v in ipairs(ents) do
                if v:IsValid() and v.components.workable and v.components.workable:CanBeWorked() and (self.meworktargettestfn == nil or self.meworktargettestfn(v)) then
                    brain[self._cmp_tarfield] = v
                    canbeworked_thisround = true
                    break
                end
            end
        end
        -- 如果目标有效 且能被工作
        local _tar = brain[self._cmp_tarfield]
        if canbeworked_thisround or (_tar and _tar:IsValid() and _tar:HasTag(self.actionid..'_workable') and _tar.components.workable and _tar.components.workable:CanBeWorked()) then
            -- 如果使用bufferedaction
            if self._should_use_bufferedaction then
                local wp = me.components.inventory and me.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
                local wp_can_work,flagwp = nil,'_can_'..self.actionid
                if wp and wp:IsValid() then
                    if wp[flagwp] then wp_can_work = true else Sugar:unequipItem(wp) end
                end
                if not wp_can_work then
                    local tools = self.use_bufferedaction.tools
                    local newwp = SpawnPrefab(tools[math.random(#tools)])
                    newwp[flagwp] = true
                    newwp.persists = false
                    if newwp.components.finiteuses then
                        newwp.components.finiteuses.Use = function()end
                    end
                    if newwp.components.equippable then
                        local old_onunequipfn = newwp.components.equippable.onunequipfn
                        newwp.components.equippable.onunequipfn = function (...)
                            if old_onunequipfn ~= nil then old_onunequipfn(...) end
                            newwp:DoTaskInTime(0,function() if newwp and newwp:IsValid() then newwp:Remove() newwp = nil end end)
                        end
                    end
                    me.components.inventory:Equip(newwp,nil,true)
                end
                if Coords:calcDistByEnt(me,_tar,true) < self.use_bufferedaction.pushaction_dist then
                    if not Sugar:taskIfExist(me,self._keeptask) then
                        me.components.locomotor:Stop()
                        local bufferedaction = BufferedAction(me,_tar,ACTIONS[self.actionid])
                        bufferedaction.distance = self.use_bufferedaction.bufferedaction_dist
                        bufferedaction.arrivedist = self.use_bufferedaction.bufferedaction_arrivedist
                        Sugar:taskDoPeriodicForAWhile(me,self._keeptask,self.use_bufferedaction.bufferedaction_pushinterval,nil,function()
                            if _tar and _tar:IsValid() and _tar:HasTag(self.actionid..'_workable') and _tar.components.workable and _tar.components.workable:CanBeWorked() and me and me:IsValid() then
                                me.components.locomotor:PushAction(bufferedaction)
                            else
                                if brain then brain[self._cmp_tarfield] = nil end
                                if me then Sugar:taskCancel(me,self._keeptask) end
                            end
                        end,nil,0)
                    end
                    return self.use_bufferedaction.rethink_work
                else
                    base:GoToEntity(brain[self._cmp_tarfield])
                    return self.use_bufferedaction.rethink_gototarget
                end
            else
                -- 如果使用简易模式
                if Coords:calcDistByEnt(me,_tar,true) < self.use_simplemode.dowork_dist then
                    me.components.locomotor:Stop()
                    if self.use_simplemode.fn_playanimlist then self.use_simplemode.fn_playanimlist(me) end
                    me:DoTaskInTime(self.use_simplemode.donework_delay,function()
                        if _tar and _tar:IsValid() and _tar:HasTag(self.actionid..'_workable') and _tar.components.workable and _tar.components.workable:CanBeWorked() and me and me:IsValid() then
                            _tar.components.workable:WorkedBy(me,self.use_simplemode.worktimes)
                            if self.use_simplemode.onworkfn then self.use_simplemode.onworkfn(me,_tar) end
                        else
                            if brain then brain[self._cmp_tarfield] = nil end
                        end
                    end)
                    return self.use_simplemode.rethink_work
                else
                    base:GoToEntity(_tar)
                    return self.use_simplemode.rethink_gototarget
                end
            end
        else
            -- 丢弃不能工作的目标
            Sugar:taskCancel(me,self._keeptask)
            brain[self._cmp_tarfield] = nil
            return self.rethink_whenwtarrobbed
        end
    else
        -- 工作时间到,或者玩家的工作不是树,丢弃工作目标
        Sugar:taskCancel(me,self._keeptask)
        brain[self._cmp_tarfield] = nil
    end
    return nil
end

---@class behavetemplate_work: CBT
---@overload fun(priority_high:boolean|nil):behavetemplate_work
---@field _masterworktask string # 玩家工作任务
---@field _keeptask string # me keep工作任务
---@field _worktime number # 玩家工作后,me帮助的时间(计时器放master身上,就不需要给me一一添加了,节省一点)
---@field actionid action_name # action id
---@field masterworktargettestfn fun(target:ent):boolean # 判断master的工作对象是否符合要求
---@field _cmp_tarfield string # 组件里引用工作对象的字段名
---@field radius number # 工作搜索半径
---@field meworktargettags tagID[]|nil # me工作对象tags
---@field meworktargettestfn (fun(target:ent):boolean)|nil # 判断me的工作对象是否符合要求
---@field rethink_whenwtarrobbed number # 工作对象被抢先work完了,rethink时间
---@field use_bufferedaction {pushaction_dist:number,bufferedaction_dist:number,bufferedaction_arrivedist:number,bufferedaction_pushinterval:number,tools:PrefabID[],rethink_work:number,rethink_gototarget:number} # 使用bufferedaction来执行标准动作
---@field _should_use_bufferedaction true|nil # 是否使用bufferedaction来执行标准动作,否则用播动画的形式(人形随从用的)
---@field use_simplemode {dowork_dist:number,fn_playanimlist:fun(me:ent)|nil,donework_delay:number,worktimes:integer,onworkfn:fun(me:ent,target:ent)|nil,rethink_work:number,rethink_gototarget:number} # 
local behavetemplate_work = Class(CBT,
---@param self behavetemplate_work
---@param priority_high boolean|nil
function(self,priority_high)
    CBT._ctor(self)
    self.priority_high = priority_high
    self.mainfn = behavetemplate_work_mainfn
    self.forceexitfn = function (this, base, me, master)
        local brain = me.components.%(modid)s_brain
        Sugar:taskCancel(me,self._keeptask)
        brain[self._cmp_tarfield] = nil
    end
    self:AddEventHandler('working',function (me, master, event_data)
        if master then
            ---@cast event_data event_data_working
            local target = event_data and event_data.target
            if target and self.masterworktargettestfn(target) then
                Sugar:taskDoInTime(master,self._masterworktask,self._worktime,nil,true)
            end
        end
    end,true)
end)
---@param actionid action_name # action id 大写
---@param _worktime number|nil # 玩家工作后,me帮助的时间(计时器放master身上,就不需要给me一一添加了,节省一点,缺点是所有相同的me的帮助时间都一样了,默认 15 秒)
---@param masterworktargettestfn fun(target:ent):boolean # 判断master的工作对象是否符合要求
---@param radius number # 工作搜索半径
---@param meworktargettags tagID[]|nil # me工作对象tags
---@param meworktargettestfn (fun(target:ent):boolean)|nil # 判断me的工作对象是否符合要求
---@param rethink_whenwtarrobbed number|nil # 工作对象被抢先work完了,rethink时间
---@param use_bufferedaction nil|{pushaction_dist:number|nil,bufferedaction_dist:number|nil,bufferedaction_arrivedist:number|nil,bufferedaction_pushinterval:number|nil,tools:PrefabID[],rethink_work:number|nil,rethink_gototarget:number|nil}|nil # **二选一** 使用bufferedaction来执行标准动作
---@param use_simplemode nil|{dowork_dist:number|nil,fn_playanimlist:fun(me:ent)|nil,donework_delay:number|nil,worktimes:integer|nil,onworkfn:fun(me:ent,target:ent)|nil,rethink_work:number|nil,rethink_gototarget:number|nil} # **二选一**
function behavetemplate_work:Config(actionid,_worktime,masterworktargettestfn,radius,meworktargettags,meworktargettestfn,rethink_whenwtarrobbed,use_bufferedaction,use_simplemode)
    self.actionid = actionid
    self._worktime = _worktime or 15
    self._masterworktask = 'taskintime_workaction_'..self.actionid
    self._keeptask = 'taskperiod_keep_'..self.actionid
    self._cmp_tarfield = '_tartobe_'..self.actionid
    self.masterworktargettestfn = masterworktargettestfn
    self.radius = radius
    self.meworktargettags = meworktargettags or {}
    self.rethink_whenwtarrobbed = rethink_whenwtarrobbed or 1.5
    table.insert(self.meworktargettags,self.actionid..'_workable')
    self.meworktargettestfn = meworktargettestfn
    if use_bufferedaction then
        self._should_use_bufferedaction = true
        self.use_bufferedaction = {}
        self.use_bufferedaction.pushaction_dist = use_bufferedaction.pushaction_dist or 2
        self.use_bufferedaction.bufferedaction_dist = use_bufferedaction.bufferedaction_dist or 3
        self.use_bufferedaction.bufferedaction_arrivedist = use_bufferedaction.bufferedaction_arrivedist or 3
        self.use_bufferedaction.bufferedaction_pushinterval = use_bufferedaction.bufferedaction_pushinterval or .5
        self.use_bufferedaction.tools = use_bufferedaction.tools
        self.use_bufferedaction.rethink_work = use_bufferedaction.rethink_work or 1.5
        self.use_bufferedaction.rethink_gototarget = use_bufferedaction.rethink_gototarget or 1
    else
        assert(use_simplemode ~= nil, 'use_bufferedaction/use_simplemode 二种模式至少选一个')
        self._should_use_bufferedaction = nil
        self.use_simplemode = {}
        self.use_simplemode.dowork_dist = use_simplemode.dowork_dist or 2
        self.use_simplemode.fn_playanimlist = use_simplemode.fn_playanimlist
        self.use_simplemode.donework_delay = use_simplemode.donework_delay or .2
        self.use_simplemode.worktimes = use_simplemode.worktimes or 2
        self.use_simplemode.onworkfn = use_simplemode.onworkfn
        self.use_simplemode.rethink_work = use_simplemode.rethink_work or .7
        self.use_simplemode.rethink_gototarget = use_simplemode.rethink_gototarget or 1.5
    end
end

------------------------------------------------------------------------------------------------------
-- *行为: 帮忙砍树
---@class behavetemplate_work_chop: behavetemplate_work
---@overload fun(priority_high:boolean|nil):behavetemplate_work_chop
local behavetemplate_work_chop = Class(behavetemplate_work,
---@param self behavetemplate_work_chop
---@param priority_high boolean|nil
function(self,priority_high)
    behavetemplate_work._ctor(self)
    self.priority_high = priority_high
    self:Config('CHOP',nil,function (target)
        return target:HasTag('tree')
    end,10,{'tree'},nil,nil,{tools = {"axe","goldenaxe"}})
end)
---此行为无须`Init`,可以调用`Config`来调整参数
function behavetemplate_work_chop:Init()
end

------------------------------------------------------------------------------------------------------
-- *行为: 帮忙挖矿
---@class behavetemplate_work_mine: behavetemplate_work
---@overload fun(priority_high:boolean|nil):behavetemplate_work_mine
local behavetemplate_work_mine = Class(behavetemplate_work,
---@param self behavetemplate_work_mine
---@param priority_high boolean|nil
function(self,priority_high)
    behavetemplate_work._ctor(self)
    self.priority_high = priority_high
    self:Config('MINE',nil,function (target)
        return target:HasTag('boulder')
    end,10,{'boulder'},nil,nil,{tools = {"pickaxe","goldenpickaxe"}})
end)
---此行为无须`Init`,可以调用`Config`来调整参数
function behavetemplate_work_mine:Init()
end

------------------------------------------------------------------------------------------------------
-- *行为: 干小活(必须有一个目标)

---@param self behavetemplate_ezjob
---@param base component_%(modid)s_brainbase
---@param me ent
---@param master ent
---@return number|nil #
local function behavetemplate_ezjob_mainfn(self,base, me, master)
    local dont_test_thisround = nil
    if base['_ezjob_tar'] == nil or not base['_ezjob_tar']:IsValid() then
        base:Say('没有目标 准备寻找目标')
        local ents = TheSim:FindEntities(base.x, 0, base.z, self.radius, nil, {"INLIMBO","FX"})
        for _,tar in ipairs(ents) do
            local test_success = nil
            for _,tbl in ipairs(self.ezjoblist) do
                if tbl.fn_test(me,tar) then
                    base['_ezjob_tar'] = tar
                    base['_ezjob_datatbl'] = tbl
                    test_success = true
                    dont_test_thisround = true
                    base:Say('找到目标:' .. tar.GUID .. '|' .. tar.prefab)
                    break
                end
            end
            if test_success then break end
        end
    end
    local tar = base['_ezjob_tar']
    if dont_test_thisround or (tar and tar:IsValid()) then
        if base['_ezjob_datatbl'].fn_test(me,tar) then
            base:Say('目标可被干小活')
            if Coords:calcDistByEnt(me,tar,true) < base['_ezjob_datatbl'].arrivedist then
                base:Say('已接近目标')
                if base['_ezjob_datatbl'].fn_custominstead then
                    base['_ezjob_datatbl'].fn_custominstead(me,tar)
                else
                    me.Physics:Stop()
                    me.components.locomotor:Stop()
                    me:ForceFacePoint(tar:GetPosition():Get())
                    base['_ezjob_datatbl'].fn_playanimlist(me)
                    me:DoTaskInTime(base['_ezjob_datatbl'].donejob_delay,function ()
                        if me and me:IsValid() and tar and tar:IsValid() and base['_ezjob_datatbl'].fn_test(me,tar) then
                            base:Say('干小活!')
                            base['_ezjob_datatbl'].fn_dojob(me,tar)
                        end
                        base['_ezjob_tar'] = nil
                    end)
                end
                return base['_ezjob_datatbl'].rethink_jobsuccess
            else
                base:Say('距离较远,正在接近')
                base:GoToEntity(tar)
                return self.rethin_gototarget
            end
        else
            -- 目标有效 但是不能dojob了(被其他人抢先dojob了)
            base['_ezjob_tar'] = nil
            base:Say('目标的活被抢走了,重新思考')
            return self.rethin_targetberobbed
        end
    end
    return nil
end

---@class behavetemplate_ezjob: CBT
---@overload fun(priority_high:boolean|nil):behavetemplate_ezjob
---@field radius number # 搜索半径
---@field rethin_gototarget number # 走向目标后的rethink时间
---@field rethin_targetberobbed number # 目标被抢走后的rethink时间
---@field ezjoblist {jobname:string,arrivedist:number,donejob_delay:number,rethink_jobsuccess:number,fn_test:fun(me:ent,target:ent),fn_playanimlist:fun(me:ent),fn_dojob:fun(me:ent,target:ent),fn_custominstead:fun(me:ent,target:ent)}[] # ezjob列表
local behavetemplate_ezjob = Class(CBT,
---@param self behavetemplate_ezjob
---@param priority_high boolean|nil
function(self,priority_high)
    CBT._ctor(self)
    self.priority_high = priority_high
    self.radius = 10
    self.rethin_gototarget = 1
    self.rethin_targetberobbed = 1
    self.ezjoblist = {}
    self.forceexitfn = function (this, base, me, master)
        base['_ezjob_tar'] = nil
    end
    self.mainfn = behavetemplate_ezjob_mainfn
    -- self:AddEZJob(
        -- {
        --     jobname = 'collect_grass_and_twigs',
        --     donejob_delay = .9,
        --     rethink_jobsuccess = 1.2,
        --     fn_test = function (me, target)
        --         if (target.prefab == 'grass' or target.prefab == 'sapling') and target.components.pickable and target.components.pickable:CanBePicked() then
        --             return true
        --         end
        --     end,
        --     fn_playanimlist = function (me)
        --         if me.sg then me.sg:AddStateTag("nointerrupt") me.sg:AddStateTag("busy") end
        --         me.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
        --         me.AnimState:PlayAnimation("build_pre")
        --         me.AnimState:PushAnimation("build_loop",false)
        --         me.AnimState:PushAnimation("build_pst",false)
        --     end,
        --     fn_dojob = function (me, target)
        --         if me.sg then me.sg:RemoveStateTag("nointerrupt") me.sg:RemoveStateTag("busy") end
        --         target.components.pickable:Pick(me)
        --     end
        -- }
    -- )
end)

---除了`Init`,请调用`AddTemplateEZJob`添加预设job,或调用`AddEZJob`来自定义job逻辑,添加顺序即为优先级
---@param radius number|nil # 搜索半径
---@param arrivedist number|nil # 判定到达目标距离
---@param rethin_gototarget number|nil # 走向目标后的rethink时间
---@param rethin_targetberobbed number # 目标被抢走后的rethink时间
function behavetemplate_ezjob:Init(radius,arrivedist,rethin_gototarget,rethin_targetberobbed)
    if radius then self.radius = radius end
    if arrivedist then self.arrivedist = arrivedist end
    if rethin_gototarget then self.rethin_gototarget = rethin_gototarget end
    if rethin_targetberobbed then self.rethin_targetberobbed = rethin_targetberobbed end
end

---@class TemplateEZJobs
---@field jobname string|nil
---@field fn_test fun(me:ent,target:ent)
---@field arrivedist number
---@field rethink_jobsuccess number
---@field fn_custominstead fun(me:ent,target:ent)|nil
---@field donejob_delay number|nil
---@field fn_playanimlist fun(me:ent)|nil
---@field fn_dojob fun(me:ent,target:ent)|nil

---@type table<string,TemplateEZJobs>
local TemplateEZJobs = {
    -- 采集草和树枝
    collect_grass_and_twigs = {
        fn_test = function (me, target)
            return (target.prefab == 'grass' or target.prefab == 'sapling') and target.components.pickable ~= nil and target.components.pickable:CanBePicked()
        end,
        arrivedist = 1.2,
        rethink_jobsuccess = 1.2,
        fn_custominstead = function (me, target)
            local bufferedaction = BufferedAction(me,target,ACTIONS.PICK)
            bufferedaction.distance = 2
            bufferedaction.arrivedist = 2
            bufferedaction.silent_fail = true
            me.components.locomotor:PushAction(bufferedaction)
        end
    },
    -- 照顾农作物
    tend_crops = {
        fn_test = function (me, target)
            return target:HasTag('tendable_farmplant') and target.components.farmplanttendable ~= nil and target.components.farmplantstress ~= nil
        end,
        arrivedist = 1.5,
        rethink_jobsuccess = 1.2,
        donejob_delay = .3,
        fn_playanimlist = function (me)
            if not me.sg:HasStateTag('busy') then
                me.sg:GoToState('domediumaction')
            end
        end,
        fn_dojob = function (me, target)
            target.components.farmplanttendable:TendTo(me)
        end
    },
    -- 给农田浇水
    -- water_farmtile = {
    --     fn_test = function (me, target)
    --         if target:HasTag('farm_plant') then
    --             local x,_,z = target:GetPosition():Get()
    --             if TheWorld.Map:GetTileAtPoint(x,0,z) == WORLD_TILES.FARMING_SOIL and TheWorld.components.farming_manager and TheWorld.components.farming_manager:GetMoistureAtPoint(x,_,z) < 90 then
    --                 return true
    --             end
    --         end
    --         return false
    --     end,
    --     arrivedist = 1.5,
    --     rethink_jobsuccess = 1.2,
    --     donejob_delay = .7,
    --     fn_playanimlist = function (me)
    --         me.components.inventory:Unequip(EQUIPSLOTS.HANDS)
    --         me.AnimState:OverrideSymbol("swap_object", "swap_wateringcan", "swap_wateringcan")
    --         me.AnimState:Show("ARM_carry")
    --         me.AnimState:Hide("ARM_normal")
    --         if not me.sg:HasStateTag('busy') then
    --             me.sg:GoToState('pour')
    --         end
    --     end,
    --     fn_dojob = function (me, target)
    --         local x,_,z = target:GetPosition():Get()
    --         TheWorld.components.farming_manager:AddSoilMoistureAtPoint(x,0,z, 50)
    --     end
    -- }
}

---comment
---@param jobname 'collect_grass_and_twigs'|'tend_crops'
function behavetemplate_ezjob:AddTemplateEZJob(jobname)
    assert(TemplateEZJobs[jobname] ~= nil,"预设的 ezjob 不存在")
    TemplateEZJobs[jobname].jobname = jobname
    table.insert(self.ezjoblist,TemplateEZJobs[jobname])
end

---comment
---@param jobname string
---@param fn_test fun(me:ent,target:ent)
---@param arrivedist number
---@param rethink_jobsuccess number
---@param fn_custominstead fun(me:ent,target:ent)|nil # 用这个函数完全自定义接近目标后的逻辑,填了之后后面的参数就不用填了
---@param donejob_delay number|nil
---@param fn_playanimlist fun(me:ent)|nil
---@param fn_dojob fun(me:ent,target:ent)|nil
function behavetemplate_ezjob:AddEZJob(jobname,fn_test,arrivedist,rethink_jobsuccess,fn_custominstead,donejob_delay,fn_playanimlist,fn_dojob)
    local ezjob = {jobname = jobname,fn_test = fn_test,arrivedist = arrivedist,rethink_jobsuccess = rethink_jobsuccess}
    if fn_custominstead then
        ezjob.fn_custominstead = fn_custominstead
    else
        ezjob.donejob_delay = donejob_delay
        ezjob.fn_playanimlist = fn_playanimlist
        ezjob.fn_dojob = fn_dojob
    end
    table.insert(self.ezjoblist,ezjob)
end

------------------------------------------------------------------------------------------------------
-- 将所有行为模板添加到枚举和行为模板总表中

---@alias behavetemplate_enum string
---| 'behavetemplate_combat_evasion' # 主动规避战斗(往主人身后,远离敌人的方向移动)
---| 'behavetemplate_work_chop' # 帮忙砍树
---| 'behavetemplate_work_mine' # 帮忙挖矿
---| 'behavetemplate_ezjob' # 干小活

---@type table<behavetemplate_enum,any>
local BehaveTemplate = {
    behavetemplate_combat_evasion = behavetemplate_combat_evasion,
    behavetemplate_work_chop = behavetemplate_work_chop,
    behavetemplate_work_mine = behavetemplate_work_mine,
    behavetemplate_ezjob = behavetemplate_ezjob,
}

---@class components
---@field %(modid)s_brain component_%(modid)s_brain

---@class component_%(modid)s_brain: component_%(modid)s_brainbase
---@field inst ent
local %(modid)s_brain = Class(%(modid)s_brainbase,
---@param self component_%(modid)s_brain
---@param inst ent
function(self, inst)
    %(modid)s_brainbase._ctor(self, inst)
    self.inst = inst
end)

-- function %(modid)s_brain:OnSave()
--     return {
--     }
-- end

-- function %(modid)s_brain:OnLoad(data)
-- end

---添加自定义行为(添加顺序即为优先级)
---@param fn fun(base:component_%(modid)s_brainbase,me:ent,master:ent):number|nil # **行为执行成功** : 返回值rethink时间 <br> **行为执行失败**: 返回nil,则继续执行剩余的逻辑
---@param priority_high true|nil # 是否是高优先级行为,是则在强制传送前执行,否则在常规跟随前执行
function %(modid)s_brain:AddCustomBehave(fn,priority_high)
    if priority_high then
        table.insert(self.mainbehavelist_highpriority,fn)
    else
        table.insert(self.mainbehavelist,fn)
    end
end

---添加预设行为(添加顺序即为优先级)
---@generic T
---@param help behavetemplate_enum # 这个参数仅为触发枚举候选项,用于填入第二个参数,此参数不会被使用
---@param template `T` # 填和第一个参数一样
---@param priority_high true|nil # 是否是高优先级行为,是则在强制传送前执行,否则在常规跟随前执行
---@param fn (fun(o:T):CBT)|nil # 调用第一个参数的`Init`方法来自定义参数,并`请返回第一个参数`
function %(modid)s_brain:AddTemplateBehave(help,template,priority_high,fn)
    local behave = BehaveTemplate[template]
    assert(behave ~= nil, '未定义的模板:'..template)
    local newbehave = fn ~= nil and fn(behave(priority_high)) or behave(priority_high)
    table.insert(priority_high and self.mainbehavelist_highpriority or self.mainbehavelist,newbehave)
    if newbehave.forceexitfn ~= nil then
        table.insert(self.forceexitbehavelists,newbehave)
    end
    if newbehave.event_triggers and next(newbehave.event_triggers) then
        local me = self.inst
        me:DoTaskInTime(1,function()
            local master = self:GetMasterValid()
            for _,event_tbl in ipairs(newbehave.event_triggers) do
                if not event_tbl.source_is_master then
                    me:ListenForEvent(event_tbl.event,function (_,data)
                        event_tbl.fn(me,master,data)
                    end)
                elseif master ~= nil then -- 没获取上就不监听了
                    me:ListenForEvent(event_tbl.event,function (_,data)
                        event_tbl.fn(me,master,data)
                    end,master)
                end
            end
        end)
    end
end


return %(modid)s_brain