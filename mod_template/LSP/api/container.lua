---@meta

---@class single_containerUI # 容器UI表
---@field widget container.widget
---@field type string # 容器类型,同类型容器只能打开一个
---| 'pack' # 背包
---| 'chest' # 箱子
---@field acceptsstacks nil|boolean # 是否接受堆叠物品,不填默认为true
---@field issidewidget boolean|nil # 开启,则会在融合背包布局时融合
---@field usespecificslotsforitems boolean|nil # 是否使用特定的槽位,不填默认为false <br> 这个填true的时候,`container:GetSpecificSlotForItem` 会在 `shift+左键` 时触发, 返回的数值就是物品应该去的槽位 <br> 可以通过勾上述方法或者写itemtestfn, 来实现对槽位的控制, 比如写翻页容器时会用到这一点
---@field itemtestfn nil|(fun(container:replica_container, item:ent, slot:integer|nil): boolean) # ------------------ <br> 想要精准控制物品进入哪个槽位,要先设置 `usespecificslotsforitems = true` <br> shift左键会按顺序给每个格子判断,并使用返回true的格子 <br> 注意:如果有多个格子可以接受同类但不相同物品,要先判断该格子有没有物品,有的话继续判断下一个格子,直到判断完 <br> slot有可能是nil, 首先固定写 if slot == nil then return true end

---@class container.widget
---@field animbank string
---@field animbuild string 
---@field slotpos Vector3[] 
---@field slotbg atlasANDimage[]|table
---@field pos Vector3
---@field dragtype_drag string|nil # 设置拖拽,和widget名字保持一致
---@field unique string|nil # 唯一标识,用于花活
---@field buttoninfo container.widget.buttoninfo|nil

---@class container.widget.buttoninfo
---@field text string # 按钮文字
---@field position Vector3
---@field fn fun(inst:ent, doer:ent)|nil # 客机:按钮点击

---@class (exact) atlasANDimage
---@field atlas string
---@field image string

---@alias data_containerUI table<string, single_containerUI> # 自定义堆叠表