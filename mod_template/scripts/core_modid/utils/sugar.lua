---@class LAN_TOOL_SUGARS
local tool = {
    EPSILON = 1e-7,
    ---判断不是敌人的标签组
    tags_notenemy = {"companion","glommer","abigail","INLIMBO","FX","wall","structure","player"},
}

----------------------------------
-- GAME
----------------------------------

---获取最外层的owner
---@param invitem ent
---@return nil|ent
---@nodiscard
function tool:GetOwnerReal(invitem)
    local _player = nil
    if invitem.components and invitem.components.inventoryitem then
        local seekowner = invitem.components.inventoryitem.owner
        while seekowner ~= nil do
            if seekowner:HasTag("player") then
                _player = seekowner
                break
            elseif seekowner.components and seekowner.components.container and
            seekowner.components.inventoryitem and seekowner.components.inventoryitem.owner then
                seekowner = seekowner.components.inventoryitem.owner
            else
                break
            end
        end
    end
    return _player
end

---实体是有效并存活的
---@param ent any
---@return boolean
---@nodiscard
function tool:checkAlive(ent)
    if ent and ent:IsValid() and ent.components.health and not ent.components.health:IsDead() then
        return true
    end
    return false
end

---卸下已装备的物品
---@param equipment any 欲卸下的装备
function tool:unequipItem(equipment)
    if equipment and equipment:IsValid() and equipment.components.equippable ~= nil and equipment.components.equippable:IsEquipped() then
        local owner = equipment.components.inventoryitem.owner
        if owner ~= nil and owner.components.inventory ~= nil then
            local item = owner.components.inventory:Unequip(equipment.components.equippable.equipslot)
            if item ~= nil then
                owner.components.inventory:GiveItem(item, nil, owner:GetPosition())
            end
        end
    end
end

---大概率能成功添加掉落物lootdrop的方法,这个方法是勾lootsetupfn的
---@param inst ent
---@param fn function 这里写添加lootdrop掉落物的逻辑
---@deprecated
function tool:addLootDropAlwaysSuccess(inst,fn)
    if not inst.components.lootdropper then
        inst:AddComponent('lootdropper')
    end
    local old_lootsetupfn = inst.components.lootdropper.lootsetupfn
    inst.components.lootdropper:SetLootSetupFn(function (...)
        local res = old_lootsetupfn ~= nil and {old_lootsetupfn(...)} or {}
        fn(...)
        return unpack(res)
    end)
end

---成组生成物品
---@param prefa_id PrefabID
---@param num integer
---@return ent[] # 生成的物品表
---@nodiscard
function tool:spawnPrefabByStack(prefa_id,num)
    local res = {}
    local prefab = SpawnPrefab(prefa_id)
    local maxsize = prefab.components.stackable and prefab.components.stackable.maxsize
    -- 可堆叠,且堆叠数量大于1
    if maxsize then
        if maxsize == math.huge then
            prefab.components.stackable:SetStackSize(num)
            table.insert(res,prefab)
        else
            local stacks = math.floor(num / maxsize)
            local left = num - maxsize * stacks
            if stacks > 0 then
                for i = 1, stacks do
                    local item = SpawnPrefab(prefa_id)
                    item.components.stackable:SetStackSize(maxsize)
                    table.insert(res,item)
                end
            end
            if left > 0 then
                local item = SpawnPrefab(prefa_id)
                item.components.stackable:SetStackSize(left)
                table.insert(res,item)
            end
        end
    else -- 不可堆叠
        table.insert(res,prefab)
    end
    return res
end

---抛物品
---@param loot ent 预制物
---@param pt Vector3 坐标
---@param min_distance number|nil 最小抛出距离,防止某些单位模型太大,抛出距离太小,导致玩家捡不到物品,可不填
---@param max_distance number|nil 最大抛出距离,可不填
function tool:flingItem(loot, pt, min_distance, max_distance)
    if loot ~= nil then
        loot.Transform:SetPosition(pt:Get())

        local min_speed = 0
        local max_speed = 2
        local y_speed = 8
        local y_speed_variance = 4

        min_distance = min_distance or 0
        max_distance = max_distance or 2

        if loot.Physics ~= nil then
            local angle = math.random() * TWOPI
            local speed = min_speed + math.random() * (max_speed - min_speed)

            local sinangle = math.sin(angle)
            local cosangle = math.cos(angle)
            loot.Physics:SetVel(speed * cosangle, GetRandomWithVariance(y_speed, y_speed_variance), speed * -sinangle)

            local radius = (min_distance + math.random() * (max_distance - min_distance)) * loot:GetPhysicsRadius(1)
            loot.Transform:SetPosition(pt.x + cosangle * radius, pt.y + 0.5, pt.z - sinangle * radius)
        end
    end
end

---消耗一个物品,消耗成功返回true
---@param itm ent
---@return boolean
function tool:consumeOneItem(itm)
    if itm and itm:IsValid() then
        if itm.components.stackable then
            itm.components.stackable:Get():Remove()
            return true
        else
            itm:Remove()
            return true
        end
    end
    return false
end

---通过prefabID查找装备栏的所有装备
---@param player ent # 玩家
---@param equip_prefab string # 装备prefabID
---@return ent[] equips # 所有找到的装备
---@nodiscard
---@return boolean found # 是否找到了至少一个
function tool:findEquipments(player,equip_prefab)
    local equips,found = {},false
    local equip_slots = player and player.components.inventory and player.components.inventory.equipslots
    for _, v in pairs(equip_slots or {}) do
        if v.prefab and v.prefab == equip_prefab then
            table.insert(equips,v)
            found = true
        end
    end
    return equips,found
end

---通过关键字查找装备栏的所有装备
---@param player ent # 玩家
---@param kw string|string[] # 关键字或者关键字数组
---@return ent[] equips # 所有找到的装备
---@nodiscard
---@return boolean found # 是否找到了至少一个
function tool:findEquipmentsWithKeywords(player,kw)
    local equips,found = {},false
    local equip_slots = player and player.components.inventory and player.components.inventory.equipslots
    if type(kw) == 'string' then
        for _, v in pairs(equip_slots or {}) do
            if v.prefab and string.find(v.prefab,kw) then
                table.insert(equips,v)
                found = true
            end
        end
    else
        for _, v in pairs(equip_slots or {}) do
            if v.prefab then
                for _,keyword in ipairs(kw) do
                    if string.find(v.prefab,keyword) then
                        table.insert(equips,v)
                        found = true
                        break
                    end
                end
            end
        end
    end
    return equips,found
end

---获取装备栏的所有装备,假定所有装备中的物品没有重复,返回一个键为prefabID,值为装备实体的表
---@param player ent
---@return table<string,ent> # 返回一个键为prefabID,值为装备实体的表
---@nodiscard
function tool:getAllEquipments(player)
    local equips = {}
    local equip_slots = player and player.components.inventory and player.components.inventory.equipslots
    for _, v in pairs(equip_slots or {}) do
        if v.prefab then
            equips[v.prefab] = v
        end
    end
    return equips
end

---真伤
---@param dmg number
---@param victim ent
function tool:dealTrueDmg(dmg,victim)
    if victim and victim:IsValid() and victim.components.health and not victim.components.health:IsDead() then
        local maxhealth = victim.components.health.maxhealth
        local cur_per = victim.components.health:GetPercent()
        local should_hp = math.max(0,maxhealth * cur_per - dmg)
        local should_per = math.min(1,should_hp / maxhealth)
        victim.components.health:SetPercent(should_per)
    end
end

---减少 `rechargeable` 组件的cd(在cd中时)
---@param item ent
---@param reduce number # 减少多少秒, 单位: 秒
function tool:rechargeableReduceCD(item,reduce)
    if item and item:IsValid() and item.components.rechargeable and not item.components.rechargeable:IsCharged() then
        local cur_percent = item.components.rechargeable:GetPercent()
        local chargetime = item.components.rechargeable:GetChargeTime()
        local total = item.components.rechargeable.total
        local new_percent = math.min(1,cur_percent + cur_percent/chargetime)
        item.components.rechargeable:SetCharge(new_percent*total,true)
    end
end

----------------------------------
-- OTHERS
----------------------------------


---闭包: 判断字符串是否不包含指定的所有字符串
---@param ... string 需要判断的字符串长参
---@return fun(string_needcheck:string):boolean
---@nodiscard
function tool:stringNotInclude(...)
    local arg = {...}
    return function (string_needcheck)
        for i,v in ipairs(arg) do
            if string.find(string_needcheck,v) then
                return false
            end
        end
        return true
    end
end

---闭包: 判断字符串是否包含任意一个列出来的字符串
---@param ... string 需要判断的字符串长参
---@return fun(string_needcheck:string):boolean
---@nodiscard
function tool:stringIncludeOneOfThese(...)
    local arg = {...}
    return function (string_needcheck)
        for i,v in ipairs(arg) do
            if string.find(string_needcheck,v) then
                return true
            end
        end
        return false
    end
end

---查找并获取某个上值
---@param fn function
---@param target_name string
---@return any
---@nodiscard
function tool:upvalueFind(fn, target_name)
    local i = 1
    repeat
        local upvalue_name, upvalue_value = debug.getupvalue(fn, i)
        if upvalue_name == target_name then
            return upvalue_value
        end
        i = i + 1
    until not upvalue_name
    return nil
end

---简易装饰器
---@param parent any # 类
---@param field string # 需要勾的字段(方法名)
---@param before_fn nil|fun(self, ...) # 在原函数前执行
---@param after_fn nil|fun(self, ...) # 在原函数后执行
function tool:hookFn(parent,field,before_fn,after_fn)
    if after_fn == nil then
        local old_fn = parent[field]
        parent[field] = function (...)
            if before_fn ~= nil then
                before_fn(...)
            end
            return old_fn(...)
        end
        return
    end
    local old_fn = parent[field]
    parent[field] = function (...)
        if before_fn ~= nil then
            before_fn(...)
        end
        local res = old_fn ~= nil and {old_fn(...)} or {}
        after_fn(...)
        return unpack(res)
    end
end

---简易装饰器
---@param parent any # 类
---@param field string # 需要勾的字段(方法名)
---@param before_fn nil|fun(self, ...):... # 在原函数前执行，返回值会被处理
---@param after_fn nil|fun(self, ...):... # 在原函数后执行
function tool:hookFnHasReturn(parent, field, before_fn, after_fn)
    local old_fn = parent[field]

    if old_fn == nil then
        -- 如果原函数不存在，直接返回
        parent[field] = function(self, ...)
            if before_fn ~= nil then
                before_fn(self, ...)
            end
            if after_fn ~= nil then
                after_fn(self, ...)
            end
        end
        return
    end

    parent[field] = function(self, ...)
        local before_args = {...}
        local before_result = nil

        if before_fn ~= nil then
            before_result = {before_fn(self, unpack(before_args))}
        end

        -- 如果 before_fn 返回了值，则使用这些值作为新的参数
        local args_to_pass = before_result or before_args

        local res = {old_fn(self, unpack(args_to_pass))}

        if after_fn ~= nil then
            after_fn(self, unpack(args_to_pass))
        end

        return unpack(res)
    end
end

---比较浮点数是否相等
---@param a number
---@param b number
---@return boolean
---@nodiscard
function tool:floatEqual(a,b)
    return math.abs(a - b) < self.EPSILON
end

---转义字符串中的特殊字符
local function escape_string(s)
    return string.gsub(s, '"', "\'")
end

---将表转换为字符串(递归打印,注意深度)
---@param t table # 需要转换的表
---@param depth nil|number # 递归深度(不填则无限大)
---@param indent nil|any # 缩进(nil就行)
---@return string # 转换后的字符串
---@nodiscard
function tool:table2string(t, depth, indent)
    -- 递归打印表
    local s = "{\n"
    indent = indent or "\t"
    depth = depth or math.huge  -- 默认深度为无穷大，表示一直递归

    local key_count = 0
    for k, v in pairs(t) do
        key_count = key_count + 1
        if depth <= 0 then
            s = s .. indent .. "[...] = \"...\",\n"
            break
        end

        local new_indent = indent .. "\t"
        local _fix_k = tonumber(k)
        local fix_k
        if _fix_k ~= nil and type(_fix_k) == "number" then
            fix_k = _fix_k
        else
            fix_k = "\"" .. escape_string(tostring(k)) .. "\""
        end

        s = s .. new_indent .. "[" .. fix_k .. "] = "  

        if type(v) == "table" then
            s = s .. self:table2string(v, depth - 1, new_indent)
        else
            s = s .. "\"" .. escape_string(tostring(v)) .. "\""
        end

        if key_count < #t then  
            s = s .. ",\n"
        else
            s = s .. "\n"
        end
    end
    s = s .. indent .. "}"
    return s
end

---将结果打印(宣告)在公屏上
---@param ... string # 需要打印的字符串
function tool:declare(...)
    local s = ''
    for i = 1, select('#', ...) do s = s .. tostring(select(i, ...)) .. ' ' end
    TheNet:Announce(s)
end

---保留几位小数
---@param round number # 保留几位
---@param ... number # 数字
---@return string ... # 结果
---@nodiscard
function tool:fnum(round,...)
    local res = {}
    for i = 1, select('#', ...) do res[i] = string.format('%.'..round..'f', select(i, ...)) end
    return unpack(res)
end

---限制多行字符串每行的最大长度,并换到下一行
---@param str string
---@param line_maxlen integer
---@param max_lines integer|nil # 最大行数，默认为nil表示不限制行数
---@return string
---@nodiscard
function tool:limitMultiLineStringSingleLineMaxLen(str, line_maxlen, max_lines)
    local res = ''
    local len = string.utf8len(str)
    local line_len = line_maxlen
    local i = 1
    local current_lines = 1
    max_lines = max_lines or math.huge  -- 默认为无穷大，表示不限制行数

    while i <= len do
        local char = string.utf8sub(str, i, i)
        local char_len = string.utf8len(char)
        local byte = string.byte(char)

        if line_len < char_len then
            if current_lines >= max_lines then
                -- 如果已达到最大行数，截断剩余内容
                break
            end
            res = res .. '\n'
            line_len = line_maxlen
            current_lines = current_lines + 1
        end

        if char == '\n' then
            if current_lines >= max_lines then
                -- 如果已达到最大行数，截断剩余内容
                break
            end
            res = res .. char
            line_len = line_maxlen
            current_lines = current_lines + 1
        else
            if byte >= 0x80 then
                -- line_len = line_len - char_len
                line_len = line_len - 1
            else
                line_len = line_len - .5
            end
            res = res .. char
        end

        i = i + 1
    end

    return res
end

---判断mod有没有开启 通过mod的文件夹名字 (本方法一般用来判断工坊mod)
---@param folder_name string # 例如 "workshop-123456"
---@return boolean
---@nodiscard
function tool:checkMODEnabledByFolderName(folder_name)
    if TUNING.MOD_%(modid_upper)s.MOD_LIST and TUNING.MOD_%(modid_upper)s.MOD_LIST.map_dirname then
        if TUNING.MOD_%(modid_upper)s.MOD_LIST.map_dirname[folder_name] then
            return true
        end
    end
    return false
end

---判断mod有没有开启 通过modifo中填写的名字
---@param modinfo_name string # 例如 "我的mod"
---@return boolean
---@nodiscard
function tool:checkMODEnabledByModInfoName(modinfo_name)
    if TUNING.MOD_%(modid_upper)s.MOD_LIST and TUNING.MOD_%(modid_upper)s.MOD_LIST.map_modinfoname then
        for _,name in ipairs(TUNING.MOD_%(modid_upper)s.MOD_LIST.map_modinfoname) do
            if string.find(name,modinfo_name) then return true end
        end
    end
    return false
end

---从TUNING中获取mod的配置项数据
---@param op_suffix string # modinfo中的配置项后缀 例如 `_lang`
---@return any
---@nodiscard
function tool:getModConfigDataFromTUNING(op_suffix)
    return TUNING[string.upper('CONFIG_%(modid_upper)s'..op_suffix)]
end

---做周期任务并过一会儿取消,或者不取消 <br> 注意: 直接调用 会先尝试取消该任务
---@param doer ent|nil # 执行者,不填则生成临时预制物用来跑任务
---@param taskname string|nil # 任务名, 如果不填 `doer` , 那么这里也可以不填
---@param interval number # 周期间隔
---@param duration number|nil # 不填时则不主动取消周期任务
---@param fn function # 周期函数
---@param fn_when_time_up function|nil # duration到0时执行
---@param initialdelay number|nil # 初始延迟,填0则立刻执行,不填则以 `interval` 为延迟
---@return string taskname # 任务名
function tool:taskDoPeriodicForAWhile(doer,taskname,interval,duration,fn,fn_when_time_up,initialdelay)
    if taskname == nil then
        taskname = 'task_periodic_temp_' .. tostring(os.clock())
    end
    local temp = nil
    if doer == nil then
        doer = CreateEntity()
        temp = doer
    end
    if doer[taskname] ~= nil then doer[taskname]:Cancel() doer[taskname] = nil end
    if doer[taskname..'_cancel'] ~= nil then doer[taskname..'_cancel']:Cancel() doer[taskname..'_cancel'] = nil end
    doer[taskname] = doer:DoPeriodicTask(interval,fn,initialdelay or interval)
    if duration ~= nil then
        doer[taskname..'_cancel'] = doer:DoTaskInTime(duration,function()
            if doer and doer[taskname] ~= nil then doer[taskname]:Cancel() doer[taskname] = nil end
            if doer and doer[taskname..'_cancel'] ~= nil then doer[taskname..'_cancel']:Cancel() doer[taskname..'_cancel'] = nil end
            if fn_when_time_up ~= nil then
                fn_when_time_up()
            end
            if temp and temp:IsValid() then
                temp:Remove()
            end
            temp = nil
        end)
    end
    return taskname
end

---做倒计时任务
---@param doer ent|nil # 执行者,不填则生成临时预制物用来跑任务
---@param taskname string|nil # 任务名, 如果不填 `doer` , 那么这里也可以不填
---@param time number
---@param fn function|nil
---@param kill_task_first boolean|nil # 是否先取消之前的任务,默认取消
---@return string taskname # 任务名
function tool:taskDoInTime(doer,taskname,time,fn,kill_task_first)
    if taskname == nil then
        taskname = 'task_intime_temp_' .. tostring(os.clock())
    end
    local temp = nil
    if doer == nil then
        doer = CreateEntity()
        temp = doer
    end
    if kill_task_first == nil or kill_task_first == true then
        if doer[taskname] ~= nil then doer[taskname]:Cancel() doer[taskname] = nil end
    end
    doer[taskname] = doer:DoTaskInTime(time,function ()
        if fn ~= nil then
            fn()
        end
        if doer and doer[taskname] ~= nil then doer[taskname]:Cancel() doer[taskname] = nil end
        if temp and temp:IsValid() then
            temp:Remove()
        end
        temp = nil
    end)
    return taskname
end

---取消一个挂在实体上的任务,并置空所在的字段
---@param doer ent
---@param taskname string
function tool:taskCancel(doer,taskname)
    if doer[taskname] ~= nil then
        doer[taskname]:Cancel()
    end
    doer[taskname] = nil
end

---任务存不存在
---@param doer ent
---@param taskname string
---@return boolean
---@nodiscard
function tool:taskIfExist(doer,taskname)
    return doer[taskname] ~= nil
end

---添加 范围 buff
---@param start_or_forcestop boolean # true:开始  false:强制停止
---@param killfirst_ifexist boolean # true:任务存在时先取消再执行 <br> false:`仅`用于检查任务是否存在,无论存不存在都不会执行buff,此时会返回一个布尔值,用于判断任务是否存在
---@param doer ent # 宿主
---@param field string # 技能名 字段
---@param radius number|nil # 半径, 不填默认半径为`4`(即一个地皮)
---@param must_have_tags tagID[]|nil # 必须含有的标签
---@param cant_have_tags tagID[]|nil # 不能含有的标签
---@param must_have_one_of_tags tagID[]|nil # 至少有下列其中一个标签
---@param fn_filter (fun(target:ent):boolean)|nil # 目标过滤函数,可不填
---@param detect_interval number|nil # 检测间隔,不填则为 `1` s
---@param initialdelay number|nil # 初始延迟,填0则立刻执行,不填则以 `detect_interval` 为延迟, 默认 `1` s
---@param remove_delay number|nil # 离开范围后,延迟移除的时间,不填则为 `0.5` s
---@param fn_applybuff fun(target:ent)|nil # 这个不填,那上什么buff呢
---@param fn_removebuff fun(target:ent)|nil # 除非你这buff不用移除,不然就填
---@return boolean|nil
function tool:taskSPAoeBuff(start_or_forcestop,killfirst_ifexist,doer,field,radius,must_have_tags,cant_have_tags,must_have_one_of_tags,fn_filter,detect_interval,initialdelay,remove_delay,fn_applybuff,fn_removebuff)
    if start_or_forcestop then
        if killfirst_ifexist then
            if doer[field] ~= nil then doer[field]:Cancel() end
            doer[field] = nil
            doer[field] = doer:DoPeriodicTask(detect_interval or 1,function ()
                local x,y,z = doer:GetPosition():Get()
                for _,v in pairs(TheSim:FindEntities(x, y, z, radius or 4, must_have_tags, cant_have_tags, must_have_one_of_tags)) do
                    if fn_filter == nil or fn_filter(v) then
                        if fn_applybuff then
                            fn_applybuff(v)
                        end
                        self:taskDoInTime(v,field..'_buff_runing',(detect_interval or 1) + (remove_delay or .5),function ()
                            if fn_removebuff then
                                fn_removebuff(v)
                            end
                        end,true)
                    end
                end
            end,initialdelay or detect_interval or 1)
        else
            return doer[field] ~= nil
        end
    else
        if doer[field] ~= nil then doer[field]:Cancel() end
        self:taskCancel(doer,field..'_buff_runing')
    end
    return nil
end

---添加持续性buff, 在持续时间结束后, 进入cd
---@param doer ent # 技能执行者
---@param field string # 技能名字段, (注意 `这个字段会在内部进行修饰`, 不过我们不需要在外部索引它)
---@param duration number # 持续时间
---@param cd number # cd
---@param fn_attached function|nil
---@param fn_detached function|nil
function tool:taskDurationBuffWithCD(doer,field,duration,cd,fn_attached,fn_detached)
    field = 'dst_lan' .. field
    if doer['task_intime'..field..'cd'] == nil then
        if doer['task_intime'..field..'buff'] == nil then
            if fn_attached then fn_attached() end
            doer['task_intime'..field..'buff'] = doer:DoTaskInTime(duration,function ()
                if doer then
                    if fn_detached then fn_detached() end
                    doer['task_intime'..field..'cd'] = doer:DoTaskInTime(cd,function () if doer and doer['task_intime'..field..'cd'] ~= nil then doer['task_intime'..field..'cd']:Cancel() doer['task_intime'..field..'cd'] = nil end end)
                    if doer['task_intime'..field..'buff'] ~= nil then doer['task_intime'..field..'buff']:Cancel() doer['task_intime'..field..'buff'] = nil end
                end
            end)
        end
    end
end

---将一个实体挂到另一个母体上,并返回这个实体
---@param owner ent
---@param field string
---@param ent ent
---@param remove_before_add boolean|nil # 是否在添加前 确保该字段下没有实体
---@param setparent_or_followsymbol boolean|nil # `true`: SetParent , `false`: FollowSymbol
---@param symbol_whenfollowsymbol string|nil # 当使用`FollowSymbol`时, 跟随的通道
---@param x_followsymbol number|nil # 当使用`FollowSymbol`时才填
---@param y_followsymbol number|nil # 当使用`FollowSymbol`时才填
---@param z_followsymbol number|nil # 当使用`FollowSymbol`时才填
---@return ent
---@nodiscard
function tool:addEntRefer(owner,field,ent,remove_before_add,setparent_or_followsymbol,symbol_whenfollowsymbol,x_followsymbol,y_followsymbol,z_followsymbol)
    if remove_before_add then
        if owner[field] ~= nil and owner[field]:IsValid() then
            owner[field]:Remove()
        end
        owner[field] = nil
    end
    owner[field] = ent
    if setparent_or_followsymbol == true then
        ent.entity:SetParent(owner.entity)
    elseif setparent_or_followsymbol == false then
        ent.entity:AddFollower()
        ent.Follower:FollowSymbol(owner.GUID, symbol_whenfollowsymbol or nil,x_followsymbol or 0,y_followsymbol or 0,z_followsymbol or 0)
    end
    return ent
end

---移除实体引用
---@param owner ent
---@param field string
function tool:removeEntRefer(owner,field)
    if owner[field] ~= nil and owner[field]:IsValid() then
        owner[field]:Remove()
    end
    owner[field] = nil
end

return tool