---@meta

-- exported/custom_status_meter_01
-- ├── bg 背景(可自行更换)
-- ├── frame_circle badge相框的基础样式
-- ├── level *勿动(计量条)
-- ├── power_stage 用于增加badge相框的样式,可自行添加,s1为基础样式
-- └── custom_status_meter.scml animzipname

-- 一般来说,badge显示的肯定是和prefab有关的某个属性,所以一般会写一个组件,用于处理这个属性,以及一个客机组件,用于同步badge显示的数值

---@class data_badge # UI徽章
---@field animzipname string # anim.zip name
---@field meter_color RGBA # 计量表颜色
---@field meter_maxnum number # 计量表最大值
---@field nobackgroud boolean|nil # 计量表没有背景,默认有
---@field owners string[] # 哪些角色拥有,不填则全部角色
---@field badgeid string # 徽章id
---@field pos pos_xy # 徽章相对位置,建议{-125,35} 
---@field eventname string # 绑定的事件名
---@field eventfn fun(badge:custom_badge,owner:ent) # 事件的回调函数,注意事件是客机事件,函数也应是客机,组件请用replica
---@field hide_at_first boolean|nil # 是否初始时隐藏, 默认不隐藏
---@field drag_enable boolean|nil # 是否可右键拖动, 默认不可拖动
---@field drag_hint string|nil # 右键拖动提示文本,不填则默认用 `右键拖动`

---@class custom_badge
local custom_badge = {}

---设置计量表的值
---@param val number # 当前值
---@param max number|nil # 最大值
---@param penaltypercent number|nil 
function custom_badge:SetPercent(val,max,penaltypercent)end

---设置badge相框的样式
---@param stage number # 样式索引
function custom_badge:SetStage(stage)end

---@class pos_xy # x,y 坐标
---@field [1] number # x 坐标
---@field [2] number # y 坐标
