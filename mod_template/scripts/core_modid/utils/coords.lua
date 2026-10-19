---@diagnostic disable: undefined-global

---@class LAN_TOOL_COORDS
local tools = {
    ---@type table<integer, integer>
    map_camera_angle_to_transform_angle = {
        [360] = -275,
        [315] = -225,
        [270] = -180 ,
        [225] = -135,
        [180] = -90,
        [135] = -45,
        [90] = 0,
        [45] = 45,
        [0] = 90,
    },
    ---@type integer[]
    camera_angle = {0, 45, 90, 135, 180, 225, 270, 315, 360},
}


---获取人物面前的点P坐标
---@param inst ent # 人物
---@param dist number # 点P和人物距离
---@param angle number|nil # (角度制)Transform:GetRotation
---@param player_pos_x number|nil # 人物x坐标
---@param player_pos_z number|nil # 人物y坐标
---@return number # 点p的x坐标
---@return number # 点p的y坐标
---@nodiscard
function tools:calcCoordFront(inst,dist,angle,player_pos_x,player_pos_z)
    local angle = angle or inst.Transform:GetRotation()
    local _
    if player_pos_x and player_pos_z then
    else
        player_pos_x,_,player_pos_z = inst:GetPosition():Get()
    end

    local radian_angle = (angle-90) * math.pi / 180
    return player_pos_x - dist * math.sin(radian_angle), player_pos_z - dist * math.cos(radian_angle)
end


---获取默认方向到指定方向的转角 与GetRotation略有不同
---@param x1 number # 向量起点x坐标
---@param z1 number # 向量起点z坐标
---@param x2 number # 向量终点x坐标
---@param z2 number # 向量终点z坐标
---@return number
---@nodiscard
function tools:angleBetweenVectors(x1, z1, x2, z2)
    local x0,z0 = x1 + 1,z1
    local vec1X,vec1Z = x0 - x1,z0 - z1 -- 默认方向向量
    local vec2X,vec2Z = x2 - x1,z2 - z1 -- 向量AB

    local dotProduct = vec1X * vec2X + vec1Z * vec2Z -- 点乘
    local magA,magB = math.sqrt(vec1X^2+vec1Z^2),math.sqrt(vec2X^2+vec2Z^2) -- 向量模长

    local cosTheta = dotProduct / (magA * magB) -- 余弦值
    local theta = math.deg(math.acos(cosTheta)) -- 角度
    if z2-z1>0 then theta = 360-theta end -- 旋转是固定顺时针的,所以要转的角度超过180度时,要...
    return theta
end

---判断目标点是否在扇形范围内(不带半径)
---@param doer_pt Vector3 玩家位置
---@param forward_pt Vector3 扇形中轴线方向点
---@param rad_angle number 扇形张角（弧度）
---@param test_pt Vector3 要检测的目标点
---@return boolean
---@nodiscard
function tools:testPosWithinAngle(doer_pt,forward_pt,rad_angle,test_pt)
    -- 计算从玩家位置指向中轴线方向的向量
    local forward_x = forward_pt.x - doer_pt.x
    local forward_z = forward_pt.z - doer_pt.z

    -- 计算从玩家位置指向目标点的向量
    local to_target_x = test_pt.x - doer_pt.x
    local to_target_z = test_pt.z - doer_pt.z

    -- 计算两个向量之间的夹角余弦值
    local dot_product = forward_x * to_target_x + forward_z * to_target_z
    local magnitude_forward = math.sqrt(forward_x * forward_x + forward_z * forward_z)
    local magnitude_to_target = math.sqrt(to_target_x * to_target_x + to_target_z * to_target_z)

    if magnitude_forward == 0 or magnitude_to_target == 0 then
        return false
    end

    local cos_angle_between = dot_product / (magnitude_forward * magnitude_to_target)

    -- 由于浮点数精度问题，可能超过[-1, 1]范围
    cos_angle_between = math.max(-1, math.min(1, cos_angle_between))

    local angle_between = math.acos(cos_angle_between)

    -- 比较夹角与扇形张角的一半
    return angle_between <= rad_angle * .5
end

---获取两点间的距离
---@param x1 number # A点x坐标
---@param z1 number # A点z坐标
---@param x2 number # B点x坐标
---@param z2 number # B点z坐标
---@param do_sqrt boolean|nil # 是否开平方
---@return number # 距离
---@nodiscard
function tools:calcDist(x1,z1,x2,z2,do_sqrt)
    -- @param: do_sqrt 是否开平方
    local dist = (x1-x2)^2+(z1-z2)^2
    if do_sqrt then dist = math.sqrt(dist) end
    return dist
end

---获取2个实体间的距离(无y轴)
---@param ent1 ent
---@param ent2 ent
---@param do_sqrt boolean|nil # 是否开平方 默认不开
function tools:calcDistByEnt(ent1,ent2,do_sqrt)
    local x1,_,z1 = ent1:GetPosition():Get()
    local x2,_,z2 = ent2:GetPosition():Get()
    return self:calcDist(x1,z1,x2,z2,do_sqrt)
end

---根据转角获取坐标
---@param x1 number # 起点x坐标
---@param z1 number # 起点z坐标
---@param theta number # (角度制)线段与默认方向的夹角(带符号)
---@param dist number # 距离
---@return number # x坐标
---@return number # z坐标
---@nodiscard
function tools:calcRotatedCoords(x1, z1, theta, dist)
    local radian = math.rad(theta)
    local x2 = x1 + dist * math.cos(radian)
    local z2 = z1 - dist * math.sin(radian)
    return x2, z2
end

---获取直线上的某个点P(向量AB 长度dist , 以A为起点)
---@param x1 number # 起点A的x坐标
---@param z1 number # 起点A的z坐标
---@param x2 number # 终点B的x坐标
---@param z2 number # 终点B的z坐标
---@param dist number # AB距离
---@param n number # 起点A到点P的距离
---@return number # 点P的x坐标
---@return number # 点P的z坐标
---@nodiscard
function tools:findPointOnLine(x1, z1, x2, z2, dist, n)
    -- 计算AB方向向量
    local dx = x2 - x1
    local dz = z2 - z1
    -- 标准化方向向量 
    local norm_dx = dx / dist
    local norm_dz = dz / dist
    -- 计算点P的坐标
    local xp = x1 + n * norm_dx
    local zp = z1 + n * norm_dz
    return xp, zp
end

---获取圆周上的某个点P
---@param x number # 圆心x坐标
---@param z number # 圆心z坐标
---@param radius number # 半径
---@param direction 1|-1 # 1:顺时针 -1:逆时针
---@param angle number # (角度制)角度
---@return number # 点P的x坐标
---@return number # 点P的z坐标
---@nodiscard
function tools:findPointOnCircle(x,z,radius,direction,angle)

    angle = angle*direction
    local des_x = x + math.cos(math.rad(angle))*radius
    local des_z = z + math.sin(math.rad(angle))*radius

    return des_x, des_z
end

--- 计算带弧度的点P的坐标
---@param x1 number 线段起点X坐标
---@param z1 number 线段起点Z坐标
---@param x2 number 线段终点X坐标
---@param z2 number 线段终点Z坐标
---@param n number 点P到线段起点的距离
---@param arc_height number 弧度的高度
---@return number, number # 点P的X和Z坐标
---@nodiscard
function tools:findPointOnArc(x1, z1, x2, z2,dist, n, arc_height)
    -- 计算AB方向向量
    local dx = x2 - x1
    local dz = z2 - z1

    -- 计算中间控制点的坐标
    local cx = (x1 + x2) / 2
    local cz = (z1 + z2) / 2

    -- 计算t值
    local t = n / dist

    -- 使用二次贝塞尔曲线公式计算点P的坐标
    local xp = (1 - t)^2 * x1 + 2 * (1 - t) * t * cx + t^2 * x2
    local zp = (1 - t)^2 * z1 + 2 * (1 - t) * t * cz + t^2 * z2

    -- 添加弧度
    local arc_y = arc_height * (1 - t) * t

    -- 将弧度高度投影到Z轴
    zp = zp + arc_y

    return xp, zp
end





---锥形区域伤害计算(如果张角比较大用我;如果张角太小,就当成激光了,分成一个个圈来遍历) 1/2 计算圆锥的外切圆
---@param maxRange number # 圆锥的最大长度
---@param centerX number # 圆锥的圆心X坐标
---@param centerZ number # 圆锥的圆心Z坐标
---@param pointOnAxis_X number # 锥中轴线上的任意一个点的X坐标
---@param pointOnAxis_Z number # 锥中轴线上的任意一个点的Z坐标
---@param angle number # (角度制)圆锥的张角
---@return { x:number, z:number, r:number} # 外切圆的圆心坐标和半径
---@nodiscard
function tools:coneExcircle(maxRange, centerX, centerZ, pointOnAxis_X, pointOnAxis_Z,angle)
    -- 将角度转换为弧度
    local angleRad = math.rad(angle)

    -- 计算外切圆的半径
    local radius = maxRange / (1 + math.sin(angleRad / 2))

    -- 计算圆心到锥顶的距离
    local distanceToCenter = radius * math.sin(angleRad / 2)

    -- 计算中轴线的方向向量
    local directionX = pointOnAxis_X - centerX
    local directionZ = pointOnAxis_Z - centerZ
    local directionLength = math.sqrt(directionX * directionX + directionZ * directionZ)

    -- 归一化方向向量
    local normalizedDirectionX = directionX / directionLength
    local normalizedDirectionZ = directionZ / directionLength

    -- 计算外切圆圆心的坐标
    local excircleCenterX = centerX + normalizedDirectionX * distanceToCenter
    local excircleCenterZ = centerZ + normalizedDirectionZ * distanceToCenter

    -- 返回外切圆的圆心坐标和半径
    return {x = excircleCenterX, z = excircleCenterZ, r = radius}
end

---2/2 计算某个点有没有落在圆锥内
---@param checkX number # 要检查的点的x坐标
---@param checkZ number # 要检查的点的z坐标
---@param centerX number # 圆锥的圆心x坐标
---@param centerZ number # 圆锥的圆心z坐标
---@param pointOnAxis_X number # 圆锥中轴线上任意一个点的x坐标
---@param pointOnAxis_Z number # 圆锥中轴线上任意一个点的z坐标
---@param coneAngle number # (角度制)圆锥的张角
---@param maxRange number # 圆锥的最大长度
---@return boolean # 点是否在圆锥内
---@nodiscard
function tools:isEnemyInCone(checkX, checkZ, centerX, centerZ, pointOnAxis_X, pointOnAxis_Z, coneAngle, maxRange)
    -- 将角度转换为弧度
    local angleRad = math.rad(coneAngle)

    -- 计算圆锥的朝向向量
    local directionX = pointOnAxis_X - centerX
    local directionZ = pointOnAxis_Z - centerZ

    -- 计算检查点到圆锥圆心的向量
    local checkVectorX = checkX - centerX
    local checkVectorZ = checkZ - centerZ

    -- 计算两个向量之间的点积
    local dotProduct = directionX * checkVectorX + directionZ * checkVectorZ

    -- 计算两个向量的模长
    local directionMagnitude = math.sqrt(directionX * directionX + directionZ * directionZ)
    local checkVectorMagnitude = math.sqrt(checkVectorX * checkVectorX + checkVectorZ * checkVectorZ)

    -- 防止除以零错误
    if directionMagnitude == 0 or checkVectorMagnitude == 0 then
        return false
    end

    -- 计算两个向量之间的夹角
    local angle = math.acos(dotProduct / (directionMagnitude * checkVectorMagnitude))

    -- 检查角度是否在圆锥张角之内
    if angle > angleRad / 2 then
        return false
    end

    -- 检查点到圆心的距离是否小于最大射程
    local distance = math.sqrt(checkVectorX * checkVectorX + checkVectorZ * checkVectorZ)
    if distance > maxRange then
        return false
    end

    return true
end


---找距离点P最近的一只或topk只生物
---@param x number # 点P的x坐标
---@param y number # 点P的y坐标
---@param z number # 点P的z坐标
---@param radius number # 查询半径
---@param topk integer|nil # 距离最近的k个实体
---@return ent[] # 最近的生物实体
---@nodiscard
function tools:findClosestMobToPoint(x, y, z, radius, topk)
    local ents = TheSim:FindEntities(x, y, z, radius, {"companion","glommer","abigail","INLIMBO","FX","wall","structure","player"})
    local radius_sq = radius * radius
    local closest = nil
    local closest_dist = radius_sq
    local candidates = {}
    for _, v in pairs(ents or {}) do
        if v and v:IsValid() and v.components and v.components.combat and v.components.health and not v.components.health:IsDead() then
            local v_x, _, v_z = v:GetPosition():Get()
            local dist = self:calcDist(v_x, v_z, x, z)
            if dist <= radius_sq then
                if topk then
                    table.insert(candidates, {entity = v, distance = dist})
                elseif dist < closest_dist then
                    closest = v
                    closest_dist = dist
                end
            end
        end
    end
    if topk then
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
        local result = {}
        for i = 1, math.min(topk, #candidates) do table.insert(result, candidates[i].entity) end
        return #result > 0 and result or {}
    end
    return {closest}
end

---找距离点P最近的一只或topk只实体
---@param x number # 点P的x坐标
---@param y number # 点P的y坐标
---@param z number # 点P的z坐标
---@param radius number # 查询半径
---@param topk integer|nil # 距离最近的k个实体
---@param filter_fn (fun(tar:ent):boolean)|nil # 过滤函数
---@param must_have_tags tagID[]|nil # 必须包含的标签
---@param cant_have_tags tagID[]|nil # 不能包含的标签
---@param must_have_one_of_tags tagID[]|nil # 必须包含至少一个标签
---@return ent[] # 最近的实体
---@nodiscard
function tools:findClosestEntToPoint(x, y, z, radius, topk,filter_fn,must_have_tags,cant_have_tags,must_have_one_of_tags)
    local ents = TheSim:FindEntities(x, y, z, radius, must_have_tags,cant_have_tags,must_have_one_of_tags)
    local radius_sq = radius * radius
    local closest = nil
    local closest_dist = radius_sq
    local candidates = {}
    for _, v in pairs(ents or {}) do
        if v and v:IsValid() and (filter_fn == nil or filter_fn(v)) then
            local v_x, _, v_z = v:GetPosition():Get()
            local dist = self:calcDist(v_x, v_z, x, z)
            if dist <= radius_sq then
                if topk then
                    table.insert(candidates, {entity = v, distance = dist})
                elseif dist < closest_dist then
                    closest = v
                    closest_dist = dist
                end
            end
        end
    end
    if topk then
        table.sort(candidates, function(a, b) return a.distance < b.distance end)
        local result = {}
        for i = 1, math.min(topk, #candidates) do table.insert(result, candidates[i].entity) end
        return #result > 0 and result or {}
    end
    return {closest}
end

---相机转动后, 获取与屏幕水平朝右的点(方向向量)
---@return number|nil # 方向向量的x坐标
---@return number|nil # 方向向量的z坐标
---@nodiscard
function tools:findPointInLineParallelCamera()
    -- 获取相机角度, x轴正方向为0, 逆时针转为正, 范围[0,360]
    local camera_angle = TheCamera and TheCamera:GetHeading() or nil 
    if camera_angle == nil then return end
    -- 计算坐标
    local radians = math.rad(camera_angle)
    local x = -math.sin(radians)
    local z = math.cos(radians)

    return x,z
end

---二分找到距离表中最近的数
---@param target number # 要找得数
---@param numbers number[] # 数组
---@return number
---@nodiscard
function tools:findClosestNumber(target, numbers)
    local left = 1
    local right = #numbers

    while left < right do
        local mid = math.floor((left + right) / 2)
        if numbers[mid] < target then
            left = mid + 1
        else
            right = mid
        end
    end

    if left == 1 then
        return numbers[left]
    elseif left > #numbers then
        return numbers[#numbers]
    else
        local prev = numbers[left - 1]
        local curr = numbers[left]
        if math.abs(target - prev) < math.abs(target - curr) then
            return prev
        else
            return curr
        end
    end
end

---获取相机角度,注意只有客机下才有效,服务器默认为45
---@return nil|number
---@nodiscard
function tools:cameraGetAngle()
    local camera_angle = TheCamera and TheCamera:GetHeading() or nil
    return camera_angle
end

---相机转角转为 Transform 组件的转角
---@param camera_angle nil|number
---@return number|nil
---@nodiscard
function tools:cameraAngleToTransformAngle(camera_angle)
    if camera_angle == nil then
        camera_angle = self:cameraGetAngle()
    end
    if camera_angle then
        local angle = self:findClosestNumber(camera_angle,self.camera_angle)
        return angle and self.map_camera_angle_to_transform_angle[angle] or nil
    end
end


---计算三维坐标 圆环上任意点的坐标 ,初始位于yz平面,绕y轴转角angle,逆时针为正,圆环上任意点的角度point_angle
---@param radius number # 圆环半径
---@param point_angle number # (角度制)圆环上任意点的角度
---@param angle number # 绕y轴转角
---@param TangentVector boolean # 是否为切线方向
---@return number,number,number # 圆环上点的坐标
---@nodiscard
function tools:findPointOnCircle3D(radius, point_angle, angle, TangentVector)
    point_angle,angle = math.rad(point_angle),math.rad(angle)
    -- 计算未旋转前的坐标
    local x = 0
    local y = radius * math.cos(point_angle)
    local z = radius * math.sin(point_angle)

    if TangentVector then
        x = 0
        y = -radius * math.sin(point_angle)
        z = radius * math.cos(point_angle)
    end

    -- 应用旋转矩阵
    local rotationMatrix = {
        {math.cos(angle), 0, math.sin(angle)},
        {0, 1, 0},
        {-math.sin(angle), 0, math.cos(angle)}
    }
    local newX = rotationMatrix[1][1] * x + rotationMatrix[1][2] * y + rotationMatrix[1][3] * z
    local newY = rotationMatrix[2][1] * x + rotationMatrix[2][2] * y + rotationMatrix[2][3] * z
    local newZ = rotationMatrix[3][1] * x + rotationMatrix[3][2] * y + rotationMatrix[3][3] * z

    return newX, newY, newZ
end


---获取地图上的屏幕鼠标坐标
---@return number|nil,number|nil
---@nodiscard
function tools:getMapPosUnderMouse()
    local x, y = TheSim:GetPosition() --在屏幕上鼠标的坐标
    local w, h = TheSim:GetScreenSize() -- 屏幕当前尺寸
    if x and y and w and h then
        x = 2 * x / w - 1
        y = 2 * y / h - 1
        return x, y
    end
end


---获取 地图上的屏幕鼠标坐标 转换后的世界坐标
---@return number|nil,number|nil # 注意是x和z坐标
---@nodiscard
function tools:getWorldPosFromMapPos()
    local x, y = self:getMapPosUnderMouse()
    local world_x,world_z
    if x and y then
        local minimap = TheWorld.minimap.MiniMap
        world_x,world_z = minimap:MapPosToWorldPos(x, y, 0)
        return world_x,world_z
    end
end

---随机点生成器: 圆形内随机
---@param x number # 圆心x坐标
---@param z number # 圆心z坐标
---@param r number # 半径
---@return fun():number,number
---@nodiscard
function tools:GenPointInCircle(x,z,r)
    return function()
        -- Generate a random angle between 0 and 2*pi
        local theta = math.random() * 2 * math.pi
        -- Generate a random radius with uniform distribution
        local radius = math.sqrt(math.random())
        -- Calculate the random point in the circle
        local random_x = x + radius * r * math.cos(theta)
        local random_z = z + radius * r * math.sin(theta)
        return random_x, random_z
    end
end

--- 随机点生成器: 圆环上随机
---@param x number # 圆心x坐标
---@param z number # 圆心z坐标
---@param r number # 半径
---@return fun():number,number
---@nodiscard
function tools:GenPointOnRing(x, z, r)
    return function()
        local theta = math.random() * 2 * math.pi -- 随机角度 (0 到 2π)
        local random_x = x + r * math.cos(theta)   -- 固定半径
        local random_z = z + r * math.sin(theta)
        return random_x, random_z
    end
end

--- 随机点生成器: 圆环上随机 但是和参考点的夹角有最小角度要求
---@param x number # 圆心x坐标
---@param z number # 圆心z坐标
---@param r number # 半径
---@param min_angle number # 最小角度（度）
---@param initial_x number # 参考点的x坐标
---@param initial_z number # 参考点的z坐标
---@return fun():number,number
---@nodiscard
function tools:GenPointOnRingWithMinAngle(x, z, r, min_angle, initial_x, initial_z)
    local initial_angle_rad = math.atan2(initial_z - z, initial_x - x)
    local min_angle_rad = math.rad(min_angle)

    return function()
        local theta
        repeat
            theta = math.random() * 2 * math.pi
            local diff = math.abs(theta - initial_angle_rad)
            local angle_diff = math.min(diff, 2 * math.pi - diff)
        until angle_diff >= min_angle_rad

        local random_x = x + r * math.cos(theta)
        local random_z = z + r * math.sin(theta)
        return random_x, random_z
    end
end

---检查点是否在闭合多边形内部
---@param point {[1]:number, [2]:number} # 需要检查的点
---@param ... {[1]:number, [2]:number} # `顺时针` 或 `逆时针` 传入 闭合多边形的所有顶点
---@return boolean
---@nodiscard
function tools:isPointInPolygon(point, ...)
    local function isLeft(P0, P1, P2)
        return (P1[1] - P0[1]) * (P2[2] - P0[2]) - (P2[1] - P0[1]) * (P1[2] - P0[2])
    end

    local point_x, point_z = point[1], point[2]
    local polygon = {...}
    local wn = 0  -- Winding number

    local function updateWn(P0, P1)
        if P0[2] <= point_z then
            if P1[2] > point_z then
                if isLeft(P0, P1, {point_x, point_z}) > 0 then
                    wn = wn + 1
                end
            end
        else
            if P1[2] <= point_z then
                if isLeft(P0, P1, {point_x, point_z}) < 0 then
                    wn = wn - 1
                end
            end
        end
    end

    for i = 1, #polygon do
        local P0 = polygon[i]
        local P1 = polygon[(i % #polygon) + 1]
        updateWn(P0, P1)
    end

    return wn ~= 0
end

---获取宠物躲避位置（扇形区域）, 当玩家发生战斗,宠物主动移动到玩家身后,规避仇恨
---@param enemy_x number 敌人X坐标
---@param enemy_z number 敌人Z坐标
---@param p_x number 玩家X坐标
---@param p_z number 玩家Z坐标
---@param angle number 扇形角度（度）
---@param min_r number 最小半径
---@param max_r number 最大半径
---@return number, number
---@nodiscard
function tools:findEvadePoint(enemy_x, enemy_z, p_x, p_z, angle, min_r, max_r)
    local dir_x = enemy_x - p_x
    local dir_z = enemy_z - p_z
    local dist = math.sqrt(dir_x^2 + dir_z^2)

    dir_x, dir_z = -dir_x/dist, -dir_z/dist

    local base_angle = math.deg(math.atan2(dir_z, dir_x))

    local random_angle = base_angle + (math.random()*2 - 1) * angle/2

    local random_dist = min_r + math.random()*(max_r - min_r)

    local evade_x = p_x + math.cos(math.rad(random_angle)) * random_dist
    local evade_z = p_z + math.sin(math.rad(random_angle)) * random_dist

    return evade_x, evade_z
end

return tools