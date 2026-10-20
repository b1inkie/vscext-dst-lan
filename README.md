# Don't Starve Together Mod Dev Tools & API support library of lua-language-server

![version](https://vsmarketplacebadges.dev/version/lan.dst-lan.png)
![installs](https://vsmarketplacebadges.dev/installs/lan.dst-lan.png)
![downloads](https://vsmarketplacebadges.dev/downloads/lan.dst-lan.png)

## 饥荒mod开发工具 / Don't Starve Together Mod Dev Tools

一站式饥荒 mod 开发插件: 从 mod 框架生成、人物注入, 到动画贴图打包 —— 全部内置, 无需安装任何外部工具.
All-in-one DST modding toolkit: mod scaffolding, character injection, and animation/texture packing — all built-in, no external tools required.

## 命令速查 / Command Reference

`Ctrl+Shift+P` 输入 `dst-lan` 即可看到全部命令 / Type `dst-lan` in the Command Palette.

| 命令 / Command | 说明 / Description |
|---|---|
| `dst-lan: 生成mod框架` (gen-mod) | 输入 modid, 一键生成完整 mod 骨架 / Scaffold a full mod from a modid |
| `dst-lan: 人物模板注入` (inject-avatar) | 向已有 mod 注入新人物全套资源 / Inject a new character into an existing mod |
| `dst-lan: 打包动画` (compiler) | 动画/贴图打包、图集打包 二合一 / Compile & atlas-pack |
| `dst-lan: 制作预制物图` (makeimg) | 提取三张模板图供绘制, 完成后自动注入 inventoryimages / swap / ground 与 scml / Extract 3 template images to draw on, then inject inventoryimages, swap, ground assets and scml |
| `dst-lan: 删除注释` (delete-comments) | 删除当前 Lua 文件的注释与空行(字符串安全) / Strip Lua comments & blank lines (string-safe) |
| `dst-lan: 切换语言` (toggle-language) | 切换中英文 snippets 与界面 / Toggle zh-cn / English snippets & UI |
| `dst-lan: extra` | 工具箱: 打包 zip、画布扩大/裁剪、取色器、解包 / Toolbox: pack zip, canvas expand/crop, color picker, unpack |

### 💊糖 / Sugar

- `p+预制物ID` → 预制物补全(支持中文译名搜索) / `p+prefabID` → prefab completion (searchable by translated name)
- `tag+标签名` → 标签补全 / `tag+tagID` → tag completion

### 🎮插件下载 / Extension Download

- 在 **`VSCode`** 的 **`插件市场`** 中搜索 **`dst-lan`** / Search **`dst-lan`** in the VSCode Extension Marketplace.
- 不再支持 `1.75.0` 以下版本的 `VSCode` / No longer supports `VSCode` below `1.75.0`.
- "Don't Starve Together" 版本 `^619045`.


## lua语言服务支持 / lua-language-server

### 🎮插件下载 / Extension Download

- 在 **`VSCode`** 的 **`插件市场`** 中搜索关键字  **`lua`** 排名第一的插件 [hit me](https://marketplace.visualstudio.com/items?itemName=sumneko.lua)。
In the VSCode Extension Marketplace, search for the keyword lua and select the top-ranked extension [hit me](https://marketplace.visualstudio.com/items?itemName=sumneko.lua).

### 🗼LLS智能识别支持库地址下载 / LLS intelligent recognition support library Download

1. Download From Gitee: https://gitee.com/b1inkie/lsp-dst
2. 配置智能识别库/Configure Intelligent Recognition Library:
    - 打开 LLS 插件设置, 找到 Workspace: Library, 将下载好的库的scripts文件夹的路径,添加进去./Open the LLS plugin settings, find Workspace: Library, and add the path to the scripts folder of the downloaded library.
    - 如果你不想全局设置该库,可以在工作区JSON中配置./If you do not want to set this library globally, you can configure it in the workspace JSON.
    ```json
    {
        "settings": {
            "Lua.runtime.version": "Lua 5.1",
            "Lua.workspace.library": [
			    "D:\\DST_content\\lsp-dst\\scripts"
		    ]
        }
    }
    ```


## 💖lan的话: / words from lan:

- 本插件提供的API补全不再进行更新,请使用 `lua-language-server` 的 `LLS智能识别支持库`。
- 如果您对本插件有任何建议,或者有想要的辅助mod开发的功能,可以向我提交issue或者加qq群@我. 
dst-lan Github: https://github.com/b1inkie/vscext-dst-lan
LSP Gitee: https://gitee.com/b1inkie/lsp-dst
- qq群: `623398781`
