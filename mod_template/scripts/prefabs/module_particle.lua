---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---@type api_particle
local Particle = require('core_%(modid)s/api/particle')

---@type data_particle[]
local data = {
    {
        prefab                 = 'dmg_display',
        is_mod_texture         = true,
        texture                = 'fx/dmg_num.tex',
        texture_num_col        = 10,
        texture_num_row        = 1,
        enable_envelope_colour = true,
        enable_envelope_scale  = true,
        envelope_colour        = {
            {{0, {1,1,1,.7}},{.7, {1,1,1,1}},{1, {1,1,1,0}}},
        },
        envelope_scale = {
            Particle:genLerpEnvelopeScale(.6,3,.1),
        },
        custom_every_particle_style = false,
        custom_every_particle_style_use_same_envelope = true,
        custom_every_particle_style_false = {
            rotationstatus        = true,
            maxnum                = 200,
            life                  = 2,
            blendmode             = BLENDMODE.Premultiplied,
            enable_ground_physics = false,
            sort_offset           = 0,
            sort_order            = 0,
            enablebloompass       = true,
            acceleration          = {0,0,0},
            dragcoefficient       = .03,
        },
        emitter_type = {
            type  = 'once',
        },
        emit_when_spawn = false,
        emit_fn = function (inst)
            Particle:emitParticle(inst,0,4,0,0,0,0,function ()
                local fixed_x,fixed_z = Tools:findPointInLineParallelCamera()
                local dist = Tools:calcDist(0,0,fixed_x,fixed_z,true)
                local px, pz = Tools:findPointOnLine(0,0, fixed_x, fixed_z, dist,i*0.5)
                local py = 2
                local vx, vy, vz = 0, 2, 0
                return px, py, pz, vx, vy, vz
            end)
        end
    },
}

return unpack(Particle:MakeParticles(data))