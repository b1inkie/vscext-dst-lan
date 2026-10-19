---@meta

---@alias data_dish table<string, single_dish> # 料理数据表

---@class single_dish # 料理数据
---@field test fun(potprefab:string,names:table,tags:dish_tags):boolean
---@field weight number # 权重
---@field priority number # 优先级 @Runar: 料理优先级，严格的测试函数配合设定合理的料理优先级才能铸就好的料理。无端99还条件简单的无疑是给自己和其他模组添麻烦
---@field foodtype any # 食物类型
---@field perishtime number # 腐烂时间/天
---@field hunger number # 饥饿度
---@field sanity number # 精神
---@field health number # 生命
---@field cooktime number # 烹饪时间/s
---@field floater prefab_floater # 漂浮水面数据表
---@field potlevel string|nil # 动画在烹饪锅的位置高低,建议一个mod中所有料理固定一个值
---| 'low'
---| 'med'
---| 'high'
---@field tags string[]|nil # 将被添加到预制物的tags
---@field oneat_desc string|nil # 吃的时候的描述
---@field oneatenfn fun(inst:ent,eater:ent)|nil # 食用后执行的函数，在此实现buff
---@field card_def dish_card_def|nil # 食谱小卡片
---@field imagename string|nil # 贴图,不写则用prefab名
---@field atlasname string|nil # 图集路径,不写则用inventoryimages
---@field cookbook_tex string|nil # 烹饪指南中显示的图片名,不写则用prefab名
---@field cookbook_atlas string|nil # 烹饪指南中显示的图片图集,不写则用inventoryimages
---@field isMasterfood boolean|nil # 是否大厨料理
---@field maxstacksize number|nil # 最大堆叠数量
---@field onperishreplacement string|nil, # 腐烂产物，默认为腐烂物
---@field perishfn function|nil # 腐烂时的回调函数
---@field name string|nil # 料理名
---@field basename string|nil # 设置调味料理基础名
---@field overridebuild string|nil # 设置料理锅上动画（贴图）所在的build压缩包（有时build名不一定为压缩包名）
---@field mod_%(modid)s boolean|nil # 确定为模组料理便于本模组内进行调味处理，换个名也可
---@field lan dish_custom_attr # 自定义

---@class dish_tags
---@field dairy number|nil # 乳制品度
---@field decoration number|nil # 装饰度
---@field egg number|nil # 蛋度
---@field fat number|nil # 油脂度
---@field fish number|nil # 鱼度
---@field fruit number|nil # 水果度
---@field inedible number|nil # 不可食用度
---@field magic number|nil # 魔法度
---@field meat number|nil # 肉度
---@field monster number|nil # 怪物度
---@field seed number|nil # 种子度
---@field sweetener number|nil # 甜味剂度
---@field veggie number|nil # 蔬菜度

---@class prefab_floater table # 漂浮数据
---@field [1] prefab_floater_size # 漂浮大小
---@field [2] number|nil # 偏移
---@field [3] number|nil # 缩放比

---@alias prefab_floater_size
---| 'small' # 小
---| 'med' # 中
---| 'large' # 大

---@class dish_card_def # 菜谱卡定义
---@field ingredient table<string,number>[]


---@class dish_custom_attr # 自定义料理属性表
---@field noedible boolean|nil # 没有edible组件
---@field nostackable boolean|nil # 没有堆叠组件
---@field noperishable boolean|nil # 没有新鲜度组件
---@field nospiced boolean|nil # 不能调味
---@field noburnable boolean|nil # 不能燃烧
---@field functional_medal_cook_certificate_consume integer|nil # 能力勋章: 该料理消耗多少烹饪勋章的耐久
