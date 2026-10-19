---@diagnostic disable: lowercase-global, undefined-global, trailing-space

---@type data_badge[]
local data = {
    {
        animzipname = 'custom_status_meter',
        meter_color = {.2,.1,.6,1},
        meter_maxnum = 100,
        badgeid = 'power_badge',
        pos = {-200,35},
        eventname = 'on_power_change',
        eventfn = function(badge,owner)
            
        end,
        owners = {"webber"},
    }
}


return data