# Changelog

## 2.0.0

### 新增

- 内置打包引擎, 不再依赖任何外部工具:
  - scml 动画编译 → anim zip(多 entity、方向后缀、图集自动裁剪分页)
  - 散图 png → tex + xml(递归子目录, 已有 .tex 跳过)
  - 多图片打包成图集(MaxRects 装箱, 两步选目录, 默认定位 mod/images)
  - 解包图集 xml → 元素 png(多元素出文件夹, 单元素出 png)
- 打包 zip 复选框交互 + 工坊精简/全量预设 + 按 mod 记忆勾选
- 画布扩大/裁剪支持倍数、最大尺寸、裁切留边输入; scml 缺图补 1x1 占位
- 逐文件容错的编译流程: 单个失败不中断, 结束汇总提示
- 冒烟回归套件 tools/smoke(`npm run smoke` 一键全跑)
- modmain 新增 %(avatar_id_to_replace)s 占位符, 注入人物时自动替换为 avatarid 并取消该行导入注释

### 改进

- 代码结构模块化(命令/库/补全分层), 单个功能异常不再影响扩展激活
- Lua 去注释改为状态机, 字符串与长字符串中的 `--` 不再被误删
- 打包输出改用独立输出通道, 失败明细可查
- 语言配置文件迁移至 `~/Documents/dst-lan/`
- 解包(tex/xml → png)从「打包动画」菜单移至「Extra」菜单

### 修复

- 生成 mod 框架时 `scripts/api_skins/modid_skins.lua` 未改名为 `<modid>_skins.lua`, 导致 modmain 导入皮肤 API 失败
### 移除

- 外部打包工具支持(scml.exe / png.exe / 外部 DST Mod Tool 及路径配置)
- fdp 声音工程生成器(重构中, 入口保留 WIP 提示)

## 1.x

见旧仓库(1.0.7 ~ 1.3.12)。
