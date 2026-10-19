-- hide
-- 功能(需要填写): 组件动作拓展(空手对地等)

local Sugar = SUGAR_%(modid)s

---@type data_extra_action
local data = {
    actions = {
        -- {
        --     id = 'ACTION_TEST_POINT_GROUND_START',
        --     str = '开圈',
        --     fn = function(act)
        --         local doer = act.doer
        --         if doer and doer:IsValid() then
        --             if not doer:HasTag('webbert_hint') then
        --                 doer:AddTag('webbert_hint')
        --             end
        --         end
        --         return true
        --     end,
        --     state = '%(modid)s_blanksg',
        --     actiondata = {
        --         priority = 7,
        --         mount_valid = false,
        --         distance = 20,
        --     },
        -- },
        -- {
        --     id = 'ACTION_TEST_POINT_GROUND_CONFIRM',
        --     str = '确定',
        --     fn = function(act)
        --         local doer = act.doer
        --         if doer and doer:IsValid() then
        --             if doer:HasTag('webbert_hint') then
        --                 doer:RemoveTag('webbert_hint')
        --             end
        --         end
        --         return true
        --     end,
        --     state = 'quickcastspell',
        --     actiondata = {
        --         priority = 7,
        --         mount_valid = false,
        --         distance = 20,
        --     },
        -- },
        -- {
        --     id = 'ACTION_TEST_POINT_GROUND_CANCEL',
        --     str = '取消',
        --     fn = function(act)
        --         local doer = act.doer
        --         if doer and doer:IsValid() then
        --             if doer:HasTag('webbert_hint') then
        --                 doer:RemoveTag('webbert_hint')
        --             end
        --         end
        --         return true
        --     end,
        --     state = '%(modid)s_blanksg',
        --     actiondata = {
        --         priority = 7,
        --         mount_valid = false,
        --         distance = 20,
        --     },
        -- }
    },
    pickers = {
        -- 用该框架写的一个带指示器的空手动作 右键开圈 左键确定 右键取消
        -- {
        --     avatars = {'webbert'},
        --     type = 'pointspecial',
        --     fn_pointspecial = function (inst, pos, useitem, right, usereticulepos, ...)
        --         if right and not inst:HasTag('webbert_hint') then
        --             if ThePlayer then
        --                 Sugar:removeEntRefer(ThePlayer,'webberthint')
        --             end
        --             return 'ACTION_TEST_POINT_GROUND_START'
        --         end
        --         if not right and inst:HasTag('webbert_hint') then
        --             if ThePlayer then
        --                 local webberthint = ThePlayer['webberthint']
        --                 if webberthint == nil or not webberthint:IsValid() then
        --                     local fx = Sugar:addEntRefer(ThePlayer,'webberthint',SpawnPrefab('fx_webbert_misc'),true)
        --                     ---@cast fx ent_fx
        --                     fx:fn_fx_webbert_misc('reticuleaoe','reticuleaoe','idle_small',true,false,nil,true,ConsoleWorldPosition())
        --                     -- 缓动用这个
        --                     -- fx:AddComponent("updatelooper")
        --                     -- local smoothing = 25
        --                     -- fx.components.updatelooper.followhandler = TheInput:AddMoveHandler(function(x, y)
        --                     --     local x1, y1, z1 = TheSim:ProjectScreenPos(x, y)
        --                     --     local p = (x1 ~= nil and y1 ~= nil and z1 ~= nil and Vector3(x1, y1, z1)) or nil
        --                     --     fx.components.updatelooper.targetpos = p
        --                     -- end)
        --                     -- fx.components.updatelooper:AddOnWallUpdateFn(function (this, dt)
        --                     --     if fx and fx:IsValid() then
        --                     --         local x, z = nil,nil
        --                     --         if fx.components.updatelooper.targetpos then
        --                     --             x,_,z = fx.components.updatelooper.targetpos:Get()
        --                     --         else
        --                     --             x,_,z = ConsoleWorldPosition():Get()
        --                     --         end
        --                     --         if dt and x and z then
        --                     --             local x0, _, z0 = fx:GetPosition():Get()
        --                     --             x = Lerp(x0, x, dt * smoothing)
        --                     --             z = Lerp(z0, z, dt * smoothing)
        --                     --         end
        --                     --         fx.Transform:SetPosition(x,0,z)
        --                     --     end
        --                     -- end)
        --                     fx:AddComponent("updatelooper")
        --                     fx.components.updatelooper:AddOnWallUpdateFn(function (this, dt)
        --                         if fx and fx:IsValid() then
        --                             local x,_,z = ConsoleWorldPosition():Get()
        --                             fx.Transform:SetPosition(x,0,z)
        --                         end
        --                     end)
        --                 end
        --             end
        --             return 'ACTION_TEST_POINT_GROUND_CONFIRM'
        --         end
        --         if right and inst:HasTag('webbert_hint') then
        --             return 'ACTION_TEST_POINT_GROUND_CANCEL'
        --         end
        --     end
        -- }
    },
}

local fixed_actions = {}
for _,action_tbl in pairs(data.actions or {}) do
    table.insert(fixed_actions,{ id = action_tbl.id, str = action_tbl.str, fn = action_tbl.fn, state = action_tbl.state, actiondata = action_tbl.actiondata})
end
for _,picker_tbl in pairs(data.pickers or {}) do
    local picker_avatars = picker_tbl.avatars
    local picker_type = picker_tbl.type
    local picker_fn = picker_tbl['fn_'..picker_type]
    local function hooks(inst)
        inst:DoTaskInTime(0,function ()
            if inst.components.playeractionpicker ~= nil then
                local old_pointspecialactionsfn = inst.components.playeractionpicker.pointspecialactionsfn
                inst.components.playeractionpicker.pointspecialactionsfn = function(this, pos, useitem, right,...)
                    local res_action_id = picker_fn(inst, pos, useitem, right, ...)
                    if res_action_id then
                        return {ACTIONS[res_action_id]}
                    end
                    return old_pointspecialactionsfn ~= nil and old_pointspecialactionsfn(this, pos, useitem, right,...) or {}
                end
            end
        end)
    end
    if picker_avatars == nil then AddPlayerPostInit(function (inst) hooks(inst) if not TheWorld.ismastersim then return inst end end)
    else
        for _,avatar in ipairs(picker_avatars) do
            AddPrefabPostInit(avatar,function (inst) hooks(inst) if not TheWorld.ismastersim then return inst end end)
        end
    end
end
for _,act in pairs(fixed_actions) do
    local addaction = AddAction(act.id,type(act.str) == 'string' and act.str or 'Missing ComponnetAction Name',act.fn)
    if act.actiondata then
        for k,v in pairs(act.actiondata) do addaction[k] = v end
    end
    if type(act.str) == 'function' then
        ---@diagnostic disable-next-line: inject-field
        addaction.stroverridefn = act.str
    end
    AddStategraphActionHandler('wilson',ActionHandler(addaction, type(act.state) == 'string' and act.state or act.state))
    AddStategraphActionHandler('wilson_client',ActionHandler(addaction, type(act.state) == 'string' and act.state or act.state))
end


---@class data_extra_action_action # 动作扩展模块的 actions 表的单个元素
---@field id string # 唯一ID,全大写
---@field str (fun(act: { doer: ent|nil, target: ent|nil, invobject: ent|nil, GetActionPoint: fun(): Vector3}):string)|string # 动作描述,可以是函数,直接返回动作显示的字符串
---@field fn fun(act: { doer: ent|nil, target: ent|nil, invobject: ent|nil, GetActionPoint: fun(): Vector3}): boolean # 动作触发时执行函数
---@field state (fun(inst:ent,act: { doer: ent|nil, target: ent|nil, invobject: ent|nil, GetActionPoint: fun(): Vector3}):string)|string|"give"|"doshortaction"|"domediumaction"|"dolongaction"|"castspell"|"quickcastspell" # 播放什么sg <br> '"give"' # 给予 <br> '"doshortaction"' # 快速搓东西 <br> '"domediumaction"' # 正常搓东西 <br> '"dolongaction"' # 慢慢搓东西 <br> '"castspell"' # 慢速释放法术 <br> '"quickcastspell"' # 快速释放法术
---@field actiondata _actiondata
---@field canqueuer string|nil # 兼容排队论
---| '"allclick"' # 默认
---| '"rightclick"' # 右键动作

---@class data_extra_action_picker
---@field avatars PrefabID[]|nil # 不填则给所有角色添加
---@field type string # 类型
---| '"pointspecial"' # 空手对地
---@field fn_pointspecial nil|(fun(inst:ent,pos:Vector3,useitem:idk,right:boolean,usereticulepos:idk,...:idk):(string|nil)) # 空手动作picker,返回动作ID,全大写

---@class data_extra_action # 动作扩展模块表
---@field actions data_extra_action_action[]|nil
---@field pickers data_extra_action_picker[]