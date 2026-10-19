---@diagnostic disable: undefined-field, inject-field
-- 常规忽略
---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---comment
---@param s string
---@return table<integer,string>
---@nodiscard
local function decode_data(s,sep)
    local res = {}
    for part in string.gmatch(s, "[^|]+") do
        table.insert(res, part)
    end
    return res
end

---@class api_particle # 粒子API
local dst_lan = {}

---生成线性缩放包络线样式
---@param start_scale number # 起始缩放比
---@param end_scale number # 结束缩放比
---@param step number # 时间的步长
---@return envelope_scale.unit[]
---@nodiscard
function dst_lan:genLerpEnvelopeScale(start_scale, end_scale, step)
    local envs = {}
    for t = 0, 1, step do
        local s = Lerp(start_scale, end_scale, t)
        table.insert(envs, { t, { s, s } })
    end
    return envs
end

---获取屏幕平行向右(垂直于镜头)的方向的单位向量
---@return number|nil # x方向
---@return number|nil # z方向
---@nodiscard
function dst_lan:getCameraHDirVertical()
    local camera_angle = TheCamera and TheCamera:GetHeading() or nil 
    if camera_angle == nil then return end

    local radians = math.rad(camera_angle)
    local x = -math.sin(radians)
    local z = math.cos(radians)
    return x,z
end

---生成粒子样式
---@param i integer 粒子样式序号,这里的序号最大值是InitEmitters的参数,若custom_every_particle_style参数为false,那么此参数应恒为0
---@param max_lifetime number|nil 粒子生命周期
---@param angle number|nil # 粒子旋转角度
---@param ang_vel number|nil # 转速
---@param uv_offset_u number # uv采样 u左起点(水平) 
---@param uv_offset_v number # uv采样 v下起点(水平)
---@param pos_and_velocity_generator_fn fun():number,number,number,number,number,number # 粒子初始位置和初速度的生成函数
function dst_lan:emitParticle(inst,i,max_lifetime,angle,ang_vel,uv_offset_u,uv_offset_v,pos_and_velocity_generator_fn)
    local lifetime = max_lifetime or self:randomLifeTime(3)
    local px, py, pz, vx, vy, vz = pos_and_velocity_generator_fn()

    local angle = angle or math.random() * 360
    local u,v = uv_offset_u or 0, uv_offset_v or 0
    local ang_vel = ang_vel or (UnitRand() - 1) * 5

    inst.fx_effect:AddRotatingParticleUV(
        i,
        lifetime,           -- lifetime
        px, py, pz,         -- position
        vx, vy, vz,         -- velocity
        angle, ang_vel,     -- angle, angular_velocity
        u,v                 -- uv offset
    )
end

---生成浮动生命时间
---@param max_lifetime number
---@return number
---@nodiscard
function dst_lan:randomLifeTime(max_lifetime)
    return max_lifetime * (.5 + UnitRand() * .5)
end

---生成粒子prefab
---@param data data_particle
---@private
function dst_lan:_MakeParticle(data)
    local TEXTURE = data.is_mod_texture and resolvefilepath(data.texture) or data.texture
    local SHADER = 'shaders/vfx_particle.ksh'


    local COLOUR_ENVELOPE_NAME = data.prefab..'_colourenvelope'
    local SCALE_ENVELOPE_NAME = data.prefab..'_scaleenvelope'

    local assets = {
        Asset('IMAGE', TEXTURE),
        Asset('SHADER', SHADER),
    }

    local function InitEnvelope()
        if data.enable_envelope_colour then 
            for i, envelope_colour in ipairs(data.envelope_colour) do
                EnvelopeManager:AddColourEnvelope(COLOUR_ENVELOPE_NAME..tostring(i-1),envelope_colour)
            end
        end
        if data.enable_envelope_scale then
            for i, envelope_scale in ipairs(data.envelope_scale) do
                EnvelopeManager:AddVector2Envelope(SCALE_ENVELOPE_NAME..tostring(i-1), envelope_scale)
            end
        end

        ---@diagnostic disable-next-line: cast-local-type
        InitEnvelope = nil
    end

    local function particle_fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddNetwork()
        inst:AddTag('FX')
        inst.entity:SetPristine()
        inst.persists = false

        ---@class ent
        ---@field _dst_lan_particle_data netvar|nil # dstlan 插件粒子框架提供的字段,网络变量
        ---@field particle_send_data_to_client (fun(self,...:string|number))|nil # dstlan 插件粒子框架提供的字段, 用这个方法同步数据

        if data.hasnetvar then
            inst._dst_lan_particle_data = net_string(inst.GUID, "_dst_lan_particle_data", "_dst_lan_particle_data.event")
            
            function inst:particle_send_data_to_client(...)
                inst._dst_lan_particle_data:set(table.concat({...}, '|'))
            end
        end

        if TheNet:IsDedicated() then
            return inst
        elseif InitEnvelope ~= nil then
            InitEnvelope()
        end

        ---@class ent
        ---@field particle_data table<integer,string> # dstlan 插件粒子框架提供的字段,客机在发射时调用

        inst.particle_data = {}
        if data.hasnetvar then
            inst:ListenForEvent('_dst_lan_particle_data.event',function ()
                local res = inst._dst_lan_particle_data:value()
                for i,v in ipairs(decode_data(res or '')) do
                    inst.particle_data[i] = v
                end
            end)
        end

        inst.fx_effect = inst.entity:AddVFXEffect()
        
        
        if data.custom_every_particle_style then
            local num_emitters = #data.custom_every_particle_style_true
            inst.fx_effect:InitEmitters(num_emitters)
            for i, custom_type in ipairs(data.custom_every_particle_style_true) do
                inst.fx_effect:SetRenderResources(i-1, TEXTURE, SHADER)
                inst.fx_effect:SetRotationStatus(i-1, custom_type.rotationstatus)
                inst.fx_effect:SetUVFrameSize(i-1, 1/data.texture_num_col, 1/data.texture_num_row)
                inst.fx_effect:SetMaxNumParticles(i-1, custom_type.maxnum)
                inst.fx_effect:SetMaxLifetime(i-1, custom_type.life)
                if data.enable_envelope_colour then
                    local _envelope = data.custom_every_particle_style_use_same_envelope and (COLOUR_ENVELOPE_NAME..'0') or (COLOUR_ENVELOPE_NAME..tostring(i-1))
                    inst.fx_effect:SetColourEnvelope(i-1, _envelope)
                end
                if data.enable_envelope_scale then
                    local _envelope = data.custom_every_particle_style_use_same_envelope and (SCALE_ENVELOPE_NAME..'0') or (SCALE_ENVELOPE_NAME..tostring(i-1))
                    inst.fx_effect:SetScaleEnvelope(i-1, _envelope)
                end
                inst.fx_effect:SetBlendMode(i-1, custom_type.blendmode) -- BLENDMODE.Premultiplied
                inst.fx_effect:EnableBloomPass(i-1, custom_type.enablebloompass)
                inst.fx_effect:SetSortOrder(i-1, custom_type.sort_order)
                inst.fx_effect:SetSortOffset(i-1, custom_type.sort_offset)
                inst.fx_effect:SetGroundPhysics(i-1, custom_type.enable_ground_physics)
                inst.fx_effect:SetAcceleration(i-1, custom_type.acceleration[1], custom_type.acceleration[2], custom_type.acceleration[3])
                inst.fx_effect:SetDragCoefficient(i-1, custom_type.dragcoefficient)
            end
        else
            local i = 1
            inst.fx_effect:InitEmitters(1)
            local _type = data.custom_every_particle_style_false
            if _type then
                inst.fx_effect:SetRenderResources(i-1, TEXTURE, SHADER)
                inst.fx_effect:SetRotationStatus(i-1, _type.rotationstatus)
                inst.fx_effect:SetUVFrameSize(i-1, 1/data.texture_num_col, 1/data.texture_num_row)
                inst.fx_effect:SetMaxNumParticles(i-1, _type.maxnum)
                inst.fx_effect:SetMaxLifetime(i-1, _type.life)
                if data.enable_envelope_colour then
                    local _envelope = data.custom_every_particle_style_use_same_envelope and (COLOUR_ENVELOPE_NAME..'0') or (COLOUR_ENVELOPE_NAME..tostring(i-1))
                    inst.fx_effect:SetColourEnvelope(i-1, _envelope)
                end
                if data.enable_envelope_scale then
                    local _envelope = data.custom_every_particle_style_use_same_envelope and (SCALE_ENVELOPE_NAME..'0') or (SCALE_ENVELOPE_NAME..tostring(i-1))
                    inst.fx_effect:SetScaleEnvelope(i-1, _envelope)
                end
                inst.fx_effect:SetBlendMode(i-1, _type.blendmode) -- BLENDMODE.Premultiplied
                inst.fx_effect:EnableBloomPass(i-1, _type.enablebloompass)
                inst.fx_effect:SetSortOrder(i-1, _type.sort_order)
                inst.fx_effect:SetSortOffset(i-1, _type.sort_offset)
                inst.fx_effect:SetGroundPhysics(i-1, _type.enable_ground_physics)
                inst.fx_effect:SetAcceleration(i-1, _type.acceleration[1], _type.acceleration[2], _type.acceleration[3])
                inst.fx_effect:SetDragCoefficient(i-1, _type.dragcoefficient)
            end
        end

        inst._fx_effect_delay = function(delay,fn)
            local timer = nil 
            return function()
                if timer == nil then
                    timer = inst:DoTaskInTime(delay,function()
                        fn()
                        if timer ~= nil then timer:Cancel() timer = nil end
                    end)
                end
            end
        end

        local emitter_type = data.emitter_type.type

        inst.emittermanager = function()
            if emitter_type == 'once' then
                EmitterManager:AddEmitter(inst, nil, function()
                    data.emit_fn(inst)
                    if inst and inst:IsValid() then 
                        inst:Remove()
                    end
                end)
            elseif emitter_type == 'delay' then
                local fx_effect_delay = inst._fx_effect_delay(data.emitter_type.delay,function()
                    data.emit_fn(inst)
                end)
                EmitterManager:AddEmitter(inst, nil, function()
                    fx_effect_delay()
                end)
            elseif emitter_type == '鲵鱼' then
                EmitterManager:AddEmitter(inst, nil, function()
                    data.emit_fn(inst)
                end)
            elseif emitter_type == 'move' then
                inst.last_pos = inst:GetPosition()
                EmitterManager:AddEmitter(inst, nil, function()
                    local cur_pos = inst:GetPosition()
                    if inst.last_pos ~= cur_pos then
                        data.emit_fn(inst)
                        inst.last_pos = cur_pos
                    end
                end)
            end
        end

        if data.emit_when_spawn then
            inst.emittermanager()
        end

        return inst
    end

    return Prefab(data.prefab, particle_fn, assets)
end

---生成粒子prefab
---@param data data_particle[]
---@return ent[]
---@nodiscard
function dst_lan:MakeParticles(data)
    local particles = {}
    for i,v in ipairs(data) do
        table.insert(particles, self:_MakeParticle(v))
    end
    return particles
end


return dst_lan  