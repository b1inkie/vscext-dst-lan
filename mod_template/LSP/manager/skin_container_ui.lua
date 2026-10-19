---@meta

---@class (exact) data_skin_containerwidget_scaleandpos # 容器的背景动画的缩放和偏移量
---@field [1] number # 水平缩放
---@field [2] number # 垂直缩放
---@field [3] number # 水平偏移
---@field [4] number # 垂直偏移

---@class data_skin_containerwidget_unit # 容器的单个UI皮肤
---@field ui_build string # UI的build
---@field scaleandpos data_skin_containerwidget_scaleandpos|nil # 容器的背景动画的缩放和偏移量
---@field slot_xml string|nil # 槽位xml完整路径
---@field slot_tex string|nil # 槽位tex

---@class data_skin_containerwidget # 容器的UI皮肤总表
---@field default_box_build string # 容器本身的默认皮肤的build
---@field default_scaleandpos data_skin_containerwidget_scaleandpos # 容器本身的默认皮肤的缩放和位置 <br> 水平缩放,垂直缩放,水平偏移,垂直偏移
---@field skins table<string,data_skin_containerwidget_unit> # 注意: 键为容器本身的皮肤的完整build名字(不是皮肤名字,所以建议皮肤和build同名,我一早就说过)