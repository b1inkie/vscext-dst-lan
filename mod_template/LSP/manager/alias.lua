---@meta

-------------------------------------
--//*Alias: 组件 --------------------
-------------------------------------
---@alias componentID_mod string
---| '%(modid)s_brain' # 组件脑子 不建议使用 除非你知道自己在做什么
---| '%(modid)s_brainbase' # 组件脑子 基类
---| '%(modid)s_cd_in_itemtile' # 这个组件是为 物品栏数字cd 服务的
---| '%(modid)s_dmg_modifier' # 这个是给玩家的组件 用于修饰 伤害
---| '%(modid)s_ent_bind_child' # 实体绑定组件(child)
---| '%(modid)s_ent_bind_master' # 实体绑定组件(master)
---| '%(modid)s_killability' # 用于 击杀获取能力模板 的组件
---| '%(modid)s_player_addequiptag' # 这个组件是添加给玩家的,调用add方法,添加装备才有的tag,也能让玩家有装备时的效果,例如夜视 护目镜等
---| '%(modid)s_tradeable' # 不用管我(这个组件是为 通用交易 功能服务的 )
---| '%(modid)s_trader' # 这个组件是为 通用交易 功能服务的 <br> 禁止自己添加这个组件, 方法可以调用

-------------------------------------
--//*Alias: tag ---------------------
-------------------------------------
---@alias tagID_mod string

-------------------------------------
--//*Alias: prefabID ----------------
-------------------------------------
---@alias PrefabID_mod string

-------------------------------------
--//*Alias: eventID -----------------
-------------------------------------
---@alias eventID_mod string