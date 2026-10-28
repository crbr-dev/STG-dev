# ESP Ra.De. — HD Chapters 1.0.0

五关纵向弹幕射击同人游戏。三名角色拥有各自的普通射击、集中攻击与强化攻击，支持键盘和 Xbox 兼容手柄。

## 运行

Windows 10/11 64位，需要支持 OpenGL 3.3 的显卡和驱动。解压完整游戏目录后运行 `ESP-RaDe.exe`，保持 `ESP-RaDe.pck` 与程序在同一目录。无需安装 Godot、Python 或其他运行工具，也无需联网。

## 操作

| 功能 | 键盘 | 手柄 |
|---|---|---|
| 移动／菜单选择 | 方向键、WASD | 左摇杆、十字键 |
| 普通射击／确认 | Z、空格；菜单也可 Enter | A |
| 慢速移动／集中射击 | Shift | LB、LT |
| 强化攻击 | C | X、RT |
| 全屏攻击 | X | B |
| 暂停／继续 | Esc | Menu |
| 重开当前关 | R | 暂停后 Y |
| 切换全屏 | F11 | — |

标题界面使用左右方向或数字1–5选择关卡。第四、五关可选择三名角色；前三关使用对应角色。射击需要持续按住按键，松开即停止。前三关开场影片不可跳过；最终通关影片结束并停留3秒后可返回标题。

每关开始恢复3条生命。第一至第五关的初始普通弹幕分别为 **2、4、4、5、5列**，P收集进度清零；连续通关保留分数和能量。前三关每3个P升一级，后两关每个P升一级。集中射击与角色专属攻击使用各自的发射规则。

## 从源码启动

源码目录包含全部必要资产和 GDScript，不需要额外下载素材。安装 **Godot 4.7.2 标准版**，导入目录中的 `project.godot`，完成资源导入后按 F6 运行当前场景，或按 F5 运行项目。

也可在源码目录运行：

```powershell
godot --editor --path .
godot --path .
```

Godot 下载地址：https://godotengine.org/download/

## 构建 Windows 发布包

在 Godot 的「编辑器 → 管理导出模板」安装 **4.7.2.stable** 导出模板。在 Windows PowerShell 中运行：

```powershell
.\build.ps1 -GodotPath 'C:\path\to\godot.exe'
```

生成结果位于 `build/Windows/`。也可在 Godot「项目 → 导出」选择 `Windows Desktop` 并导出发布版。源文件目录中的 `assets/` 为最终运行资产，`scripts/` 为玩法与界面代码，`data/` 为五关配置，`shaders/` 为着色器。

## 许可

本项目贡献者可授权的代码、图标及原创资产采用 **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International（CC BY-NC-SA 4.0）**，完整文本见 `LICENSE`。再分发请注明本项目名称和贡献者、保留许可、标明修改，仅作非商业用途，并以相同许可分享衍生作品。

这是非官方同人作品。原作名称、人物设定及相关权利属于各自权利人，不因本项目许可而转让或获得额外授权。Godot及其所含第三方组件保留各自许可，见 `GODOT-LICENSES.txt`。

许可说明：https://creativecommons.org/licenses/by-nc-sa/4.0/
