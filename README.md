# OpenAIGames-EledenRing-BossFight
全 AI 引擎创作的 3A 游戏垂直切片：艾尔登法环boss战


## 当前源码快照

本仓库收录沙丘 Boss 战「古战场遗迹」的 Godot 工程源码、场景定义、Shader、工具、测试与开发文档。详见 [中文项目说明](README.zh-CN.md)。

当前同步为 2026-09-29 正式开发快照：Victor 六句配音与中文字幕、V11 输入缓冲与翻滚保护、胜后自由移动与 R 重开，以及冠冕跪姿衔接、200 点生命、战斗/战前音乐和裂地声音更新。详情见 [本轮同步范围](docs/RELEASE-20260929.zh-CN.md)。

V12.2 独立音效看板中的生成候选尚待用户裁定，未替换正式战斗 SFX。此次 177 项 Godot 回归检查通过；主观音色与混音仍以用户试听为准。

### 资产依赖

模型、动画、贴图、音频以及 Blender 场景文件现已随 `assets/` 同步，大型二进制文件使用 Git LFS。安装 Git LFS 后执行 `git lfs install` 和 `git lfs pull`，再用 Godot 导入 `project.godot`。不包含 Blender 自动备份、构建产物、QA 录像、本地缓存或凭据。部分开发工具仍依赖原本地环境，详见中文文档。
