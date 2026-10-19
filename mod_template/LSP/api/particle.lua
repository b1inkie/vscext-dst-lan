---@meta

---@class data_particle # 粒子数据表
---@field prefab string # 粒子prefab
---@field is_mod_texture boolean # 是自定义材质还是官方材质
---@field texture string # 粒子材质路径,所有材质建议放在一行,单个粒子材质建议使用64x64
---@field texture_num_col integer # 粒子材质 列数
---@field texture_num_row integer # 粒子材质 行数 
---@field enable_envelope_colour boolean # 是否启用颜色包络线
---@field enable_envelope_scale boolean # 是否启用缩放包络线
---@field envelope_colour envelope_colour.unit[][] # 所有的颜色包络线
---@field envelope_scale envelope_scale.unit[][] # 所有的缩放包络线
---@field custom_every_particle_style boolean # 是否自定义每种粒子样式
---@field custom_every_particle_style_use_same_envelope boolean|false # 所有粒子都使用同一种包络线(即0号包络线)(当我希望只是生成不同材质的粒子时)
---@field custom_every_particle_style_true particle_type[]|nil # 所有的自定义粒子样式
---@field custom_every_particle_style_false particle_type|nil # 定义一个统一的有规则的粒子样式 颜色包络线、缩放包络线、uv采样 数量一致
---@field emitter_type emitter_type # 自定义发射器类型
---@field emit_when_spawn boolean|true # 是否在生成时立即发射
---@field emit_fn fun(inst:ent) # 发射器函数(用emitParticle方法发射单个粒子) <br> 主机传数据方法: inst:particle_send_data_to_client(...) <br> 发射时索引 `inst.particle_data` 这张表即可
---@field hasnetvar boolean|nil # 是否需要设置网络变量, 不填则不设置, 如果设置, 则字段为 `_dst_lan_particle_data`, 类型为 `string`

---@class (exact) envelope_colour.unit # 颜色包络线单元
---@field [1] number # 归一化时间点
---@field [2] RGBA # 颜色

---@class (exact) envelope_scale.unit # 缩放包络线单元
---@field [1] number # 归一化时间点
---@field [2] envelope_scale.scale_unit # 缩放比例

---@class (exact) envelope_scale.scale_unit
---@field [1] number # x轴缩放
---@field [2] number # y轴缩放

---@class particle_type # 粒子样式
---@field rotationstatus boolean|true # 是否启用旋转
---@field maxnum integer # 最大粒子数量
---@field life number # 粒子生命周期(单位:秒)
---@field colour_envelope integer|nil # 使用哪一个颜色包络线(序号从0开始)
---@field scale_envelope integer|nil # 使用哪一个缩放包络线(序号从0开始)
---@field blendmode any # 渲染模式
---@field enablebloompass boolean # 是否启用光效
---@field sort_order integer # 渲染顺序
---@field sort_offset number # 渲染偏移
---@field enable_ground_physics boolean # 是否启用地面碰撞
---@field acceleration acceleration # 三个方向的加速度
---@field dragcoefficient number # 空气阻力

---@class (exact) acceleration # 粒子加速度
---@field [1] number # x轴加速度
---@field [2] number # y轴加速度
---@field [3] number # z轴加速度

---@class (exact) emitter_type # 发射器类型
---@field type string # 类型
---| '鲵鱼' # (默认)每帧都生成粒子
---| 'delay' # 自定义间隔生成粒子,单位:秒
---| 'move' # 移动时才生成粒子
---| 'once' # 只生成一次
---@field delay number|nil # 延迟时间,单位:秒
