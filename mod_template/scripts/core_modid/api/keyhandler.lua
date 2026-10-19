---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---@class api_keyhandler # 按键处理API
local dst_lan = {
    map = {['KEY_TAB'] = KEY_TAB,['KEY_KP_0'] = KEY_KP_0,['KEY_KP_1'] = KEY_KP_1,['KEY_KP_2'] = KEY_KP_2,['KEY_KP_3'] = KEY_KP_3,['KEY_KP_4'] = KEY_KP_4,['KEY_KP_5'] = KEY_KP_5,['KEY_KP_6'] = KEY_KP_6,['KEY_KP_7'] = KEY_KP_7,['KEY_KP_8'] = KEY_KP_8,['KEY_KP_9'] = KEY_KP_9,['KEY_KP_PERIOD'] = KEY_KP_PERIOD,['KEY_KP_DIVIDE'] = KEY_KP_DIVIDE,['KEY_KP_MULTIPLY'] = KEY_KP_MULTIPLY,['KEY_KP_MINUS'] = KEY_KP_MINUS,['KEY_KP_PLUS'] = KEY_KP_PLUS,['KEY_KP_ENTER'] = KEY_KP_ENTER,['KEY_KP_EQUALS'] = KEY_KP_EQUALS,['KEY_MINUS'] = KEY_MINUS,['KEY_EQUALS'] = KEY_EQUALS,['KEY_SPACE'] = KEY_SPACE,['KEY_ENTER'] = KEY_ENTER,['KEY_ESCAPE'] = KEY_ESCAPE,['KEY_HOME'] = KEY_HOME,['KEY_INSERT'] = KEY_INSERT,['KEY_DELETE'] = KEY_DELETE,['KEY_END'] = KEY_END,['KEY_PAUSE'] = KEY_PAUSE,['KEY_PRINT'] = KEY_PRINT,['KEY_CAPSLOCK'] = KEY_CAPSLOCK,['KEY_SCROLLOCK'] = KEY_SCROLLOCK,['KEY_RSHIFT'] = KEY_RSHIFT,['KEY_LSHIFT'] = KEY_LSHIFT,['KEY_RCTRL'] = KEY_RCTRL,['KEY_LCTRL'] = KEY_LCTRL,['KEY_RALT'] = KEY_RALT,['KEY_LALT'] = KEY_LALT,['KEY_LSUPER'] = KEY_LSUPER,['KEY_RSUPER'] = KEY_RSUPER,['KEY_ALT'] = KEY_ALT,['KEY_CTRL'] = KEY_CTRL,['KEY_SHIFT'] = KEY_SHIFT,['KEY_BACKSPACE'] = KEY_BACKSPACE,['KEY_PERIOD'] = KEY_PERIOD,['KEY_SLASH'] = KEY_SLASH,['KEY_SEMICOLON'] = KEY_SEMICOLON,['KEY_LEFTBRACKET'] = KEY_LEFTBRACKET,['KEY_BACKSLASH'] = KEY_BACKSLASH,['KEY_RIGHTBRACKET= 93'] = KEY_RIGHTBRACKET,['KEY_A'] = KEY_A,['KEY_B'] = KEY_B,['KEY_C'] = KEY_C,['KEY_D'] = KEY_D,['KEY_E'] = KEY_E,['KEY_F'] = KEY_F,['KEY_G'] = KEY_G,['KEY_H'] = KEY_H,['KEY_I'] = KEY_I,['KEY_J'] = KEY_J,['KEY_K'] = KEY_K,['KEY_L'] = KEY_L,['KEY_M'] = KEY_M,['KEY_N'] = KEY_N,['KEY_O'] = KEY_O,['KEY_P'] = KEY_P,['KEY_Q'] = KEY_Q,['KEY_R'] = KEY_R,['KEY_S'] = KEY_S,['KEY_T'] = KEY_T,['KEY_U'] = KEY_U,['KEY_V'] = KEY_V,['KEY_W'] = KEY_W,['KEY_X'] = KEY_X,['KEY_Y'] = KEY_Y,['KEY_Z'] = KEY_Z,['KEY_F1'] = KEY_F1,['KEY_F2'] = KEY_F2,['KEY_F3'] = KEY_F3,['KEY_F4'] = KEY_F4,['KEY_F5'] = KEY_F5,['KEY_F6'] = KEY_F6,['KEY_F7'] = KEY_F7,['KEY_F8'] = KEY_F8,['KEY_F9'] = KEY_F9,['KEY_F10'] = KEY_F10,['KEY_F11'] = KEY_F11,['KEY_F12'] = KEY_F12,['KEY_UP'] = KEY_UP,['KEY_DOWN'] = KEY_DOWN,['KEY_RIGHT'] = KEY_RIGHT,['KEY_LEFT'] = KEY_LEFT,['KEY_PAGEUP'] = KEY_PAGEUP,['KEY_PAGEDOWN'] = KEY_PAGEDOWN,['KEY_0'] = KEY_0,['KEY_1'] = KEY_1,['KEY_2'] = KEY_2,['KEY_3'] = KEY_3,['KEY_4'] = KEY_4,['KEY_5'] = KEY_5,['KEY_6'] = KEY_6,['KEY_7'] = KEY_7,['KEY_8'] = KEY_8,['KEY_9'] = KEY_9}
}

local function log(...)
    YAE_S:declare(...)
end

---
---注册按键RPC
---@param data data_keyhandler[]
---@private
function dst_lan:ApplyKey(data)
    for _,v in ipairs(data) do 
        local full_id = string.upper(v.namespace)..string.upper(v.skillid)
        local skill_name = v.namespace..'_'..v.skillid
        local flag_using_skill = 'using_'..skill_name
        if v.fn ~= nil then
            if v.skill_template_type == 'none' then
                AddModRPCHandler(v.namespace, full_id, v.fn)
            elseif v.skill_template_type == 'active_with_builtinCD' and v.skill_template_active_with_builtinCD then
                local cd = v.skill_template_active_with_builtinCD.cd
                AddModRPCHandler(v.namespace, full_id, function(player,...)
                    if player[flag_using_skill] then -- 正在使用技能
                        player[flag_using_skill] = false
                        if v.skill_template_active_with_builtinCD.fn_when_skill_deactivated then
                            v.skill_template_active_with_builtinCD.fn_when_skill_deactivated(player)
                        end
                        if cd then -- 如果有内置cd
                            if player['taskintime_cancel_skill_cd_'..skill_name] == nil then
                                player['taskintime_cancel_skill_cd_'..skill_name] = player:DoTaskInTime(cd,function ()
                                    if v.skill_template_active_with_builtinCD.fn_when_cooldown then
                                        v.skill_template_active_with_builtinCD.fn_when_cooldown(player)
                                    end
                                    if player and player['taskintime_cancel_skill_cd_'..skill_name] then
                                        player['taskintime_cancel_skill_cd_'..skill_name]:Cancel()
                                        player['taskintime_cancel_skill_cd_'..skill_name] = nil
                                    end
                                end)
                            end
                        end
                    else -- 没在使用技能
                        -- 这个task为nil时 表明 cd已转好 
                        if player['taskintime_cancel_skill_cd_'..skill_name] == nil then
                            player[flag_using_skill] = true
                            v.fn(player,...)
                        end
                    end
                end)
            elseif v.skill_template_type == 'normal_with_CD' and v.skill_template_normal_with_CD then
                local cd = v.skill_template_normal_with_CD.cd
                AddModRPCHandler(v.namespace, full_id, function(player,...)
                    if cd then
                        if player['taskintime_cancel_skill_cd_'..skill_name] == nil then
                            player[flag_using_skill] = true
                            v.fn(player,...)
                            player[flag_using_skill] = false
                            player['taskintime_cancel_skill_cd_'..skill_name] = player:DoTaskInTime(cd,function ()
                                if v.skill_template_normal_with_CD.fn_when_cooldown then
                                    v.skill_template_normal_with_CD.fn_when_cooldown(player)
                                end
                                if player and player['taskintime_cancel_skill_cd_'..skill_name] then
                                    player['taskintime_cancel_skill_cd_'..skill_name]:Cancel()
                                    player['taskintime_cancel_skill_cd_'..skill_name] = nil
                                end
                            end)
                        end
                    else
                        player[flag_using_skill] = true
                        v.fn(player,...)
                        player[flag_using_skill] = false
                    end
                end)
            end
        end
        
        AddPlayerPostInit(function(inst)
            inst:DoTaskInTime(0, function()
                local allow_to_use = false
                if v.avatar == nil then
                    allow_to_use = true
                else
                    for _,avatar_prefab in ipairs(v.avatar) do
                        if inst.prefab == avatar_prefab then 
                            allow_to_use = true 
                            break
                        end
                    end
                end
                if allow_to_use then
                    if v.type == 'down' then
                        TheInput:AddKeyDownHandler((type(v.key) == 'string' and self.map[v.key]) or (type(v.key) == 'number' and v.key), function()
                            if inst == ThePlayer and TheFrontEnd:GetActiveScreen() and TheFrontEnd:GetActiveScreen().name == 'HUD' then 
                                if v.client_fn_before ~= nil then
                                    v.client_fn_before(inst)
                                end
                                if v.fn ~= nil then
                                    if v.client_rpc_data ~= nil then
                                        SendModRPCToServer(MOD_RPC[v.namespace][full_id],v.client_rpc_data(inst))
                                    else
                                        SendModRPCToServer(MOD_RPC[v.namespace][full_id])
                                    end
                                end
                                if v.client_fn_after ~= nil then
                                    v.client_fn_after(inst)
                                end
                            end
                        end)
                    elseif v.type == 'up' then
                        TheInput:AddKeyUpHandler((type(v.key) == 'string' and self.map[v.key]) or (type(v.key) == 'number' and v.key), function()
                            if inst == ThePlayer and TheFrontEnd:GetActiveScreen() and TheFrontEnd:GetActiveScreen().name == 'HUD' then 
                                if v.client_fn_before ~= nil then
                                    v.client_fn_before(inst)
                                end
                                if v.fn ~= nil then
                                    if v.client_rpc_data ~= nil then
                                        SendModRPCToServer(MOD_RPC[v.namespace][full_id],v.client_rpc_data(inst))
                                    else
                                        SendModRPCToServer(MOD_RPC[v.namespace][full_id])
                                    end
                                end
                                if v.client_fn_after ~= nil then
                                    v.client_fn_after(inst)
                                end
                            end
                        end)
                    end
                end
            end)
        end)
    end
end


function dst_lan:skill_type_active_with_builtinCD(data)
    
end

---@param data data_keyhandler[]
function dst_lan:main(data)
    self:ApplyKey(data)
end

return dst_lan