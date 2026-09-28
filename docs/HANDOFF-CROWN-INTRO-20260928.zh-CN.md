# 给主对话的交接：冠冕归沙实时过场

交接日期：2026-09-28。项目：`/Users/yangjianwen/Documents/aistudio/Gamebench/projects/gilded-ruin-boss`。

## 先看这几条

1. 用户已经认可四格分镜，并明确授权开始实际制作。第一版 **Godot 实时过场已经写入当前共享工程**，可以播放，也接入了接近 Boss 时的战斗前流程。无需从其他目录迁移代码。
2. 化沙的是 **Boss 手里的冠冕**，不是 Boss 本体。这是用户明确选择，不要改回全身消散。
3. 实现复用当前羽披老将、长柄武器、战场和处决跪姿；早期双刀 Boss 设想没有用于本次过场。
4. 独立审阅地址：<http://127.0.0.1:8096/?crown-intro=1>。播放后 **R 重播、P 开战**；长按 **ESC 0.8 秒**跳过。
5. 本次 Web 导出写在 `builds/crown-intro-v01/`，没有由本次工作覆盖 `builds/web/`。主对话同期可能更新了 8093 构建，不能据其时间戳推断它已包含本次最终版本；统一交付前请从当前源代码重新导出主构建。
6. 已通过过场专项 **25 项**、现有战斗回归 **152 项**。浏览器一次完整播放平均 **29.36 FPS**；这是首版可审阅实现，不是已经达到 AI 分镜画质或完成性能优化的最终成片。

## 用户确认的内容与分镜产物

用户要求约 10 秒的开战前过场，重点是冠冕逐渐化为倾泻的沙粒，Boss 跪姿可以复用处决动作；结尾平滑淡黑，并支持按住 ESC 跳过。用户在看过四格分镜后回复：“这四个分镜我很满意，可以开始实际的制作”。用户尚未在本次交接前确认实时首版的最终美术效果。

已确认的分镜资料在：

`/Users/yangjianwen/Documents/aistudio/Gamebench/asset-audition/shared-pool/public/storyboards/20260928-crown-intro-v01/`

| 文件 | 用途 |
| --- | --- |
| `storyboard-v01.png` | 内置 imagegen 生成的四格概念图，用户已认可 |
| `index.html` | 10 秒静帧分镜播放器，供评估镜头时长，不是真实粒子动画 |
| `README.zh-CN.md` | 分镜设计、素材复用和公开技术资料研究 |
| `image-prompt.txt` | 原始生成提示词 |

静帧分镜服务地址为 <http://127.0.0.1:8782/storyboards/20260928-crown-intro-v01/index.html>。不要把这个播放器与 8096 的实时 Godot 版本混淆。

## 这次实际制作了什么

| 时段 | 实时内容 |
| --- | --- |
| 0–2 秒 | 冠冕与双手近景、缓慢推近；开头 0.3 秒淡入，底缘开始掉沙 |
| 2–5 秒 | 老将胸像，显示面容、托冠动作和持续沙流 |
| 5–8.4 秒 | 单膝跪地中景；冠冕消失后双手仍停留，约 7.5 秒开始轻微抬头 |
| 8.4–10 秒 | Boss、战场、巨树广角；8.8–10 秒平滑淡黑 |

全黑时恢复战斗相机、玩家可见性和双方武器姿态，随后再用 **0.45 秒**淡入。自然播放的四镜头本体为 10 秒，交接淡入额外计算。跳过则使用 **0.3 秒**淡黑，并走同一套交接逻辑。

具体制作内容：

- **独立冠冕道具**：本地程序建模，三道环带、十二组树枝叶片、弧形纹饰；旧金属材质在消失前转为粗糙粉化质感。本轮没有使用 Tripo，也没有产生 Tripo 额度消耗。道具网格由代码运行时构建，目前没有独立烘焙 GLB。
- **流沙**：在冠冕三角面上按面积采样 22,000 个出生点，通过同一高度加噪声时间场同步材质消失和粒子释放。22,000 是全段预置总数，不是同时存活量。沙粒离开冠冕后固定在世界空间，受向下重力、少量侧风影响，触地滑动后缩小退出。
- **Compatibility 实现**：采用 `MultiMeshInstance3D` 与 spatial shader，没有逐粒调用 `GPUParticles3D.emit_particle()`，没有引入计算着色器依赖。
- **角色姿势**：保留 `Warden_Kneel_Hold` 的单膝、骨盆和下肢；原处决跪姿低头过深，实机检查中遮住了冠冕，因此过场单独恢复较直立的上身，再用双臂 IK 托冠并调整手部。没有修改原动画资源、角色网格或公共 `DuelAvatar` 实现。
- **镜头与表现**：独立 `Camera3D`、黑边、跳过进度条、局部暖光、轻微暗角和颜色调整；战斗长枪先隐藏，复制一把放到旁边；眼部红光在抬头阶段恢复。
- **声音**：临时使用既有 `assets/runtime/audio/v04/player_steps_loop_0.wav` 细碎摩擦循环，跟随沙流强度变化。它是占位 Foley，不是已经精选完成的正式倒沙音效。浏览器首次键鼠交互前可能没有声音。

## 代码接入与状态边界

主要接入文件为 `scripts/battle/playable_encounter.gd`。只在以下位置加了过场逻辑，保留现有战斗实现：

| 接入位置 | 行为 |
| --- | --- |
| 字段及 `_ready()` | 创建 `crown_intro`，设置 `crown_preview`；识别原生 `--crown-intro` 或 Web `?crown-intro=1` |
| `start_crown_preview()` | 把玩家放到 Boss 前约 12 米，并直接开始过场 |
| `reset()` | 调用 `reset_sequence()`；直接审阅模式下会再次启动过场 |
| `_unhandled_input()` | 过场 active 时退出，不让战斗操作进入 |
| `_physics_process()` | 过场 active 时退出，不推进角色、战斗计时、耐力、危险区域或 AI |
| `stage == "approach"` 分支 | 距离小于 14 米、高差小于 6 米，且本次遭遇尚未播放时，先启动过场 |
| 状态文字 | 直接审阅模式结束后显示 R 重播、P 开战提示 |

状态流：

```text
正常游玩：复活点 intro → ready → approach → cinematic → 黑场交接 → fight
直接审阅：--crown-intro / ?crown-intro=1 → cinematic → 黑场交接 → explore
直接审阅结束：R 重播；P 进入 fight
```

`scripts/cinematic/crown_intro.gd` 的关键接口：

- `start()`：清理在场战斗特效、危险区域和挂起命中；保存站位，切换跪姿及过场相机，隐藏玩家与战斗 HUD。
- `sample(time)`：按时间设置冠冕、手势、镜头和淡黑；视觉 QA 用它检查确定的关键帧。
- `advance(delta)`：推进正常时序、ESC 长按、跳过淡黑与交接淡入。
- `handoff()`：幂等黑场交接；恢复演员、武器、相机，释放过场临时场景。
- `finish()`：淡入完成才解除 active；正常模式进入 fight，审阅模式进入 explore；Boss AI 等待 1.4 秒。
- `abort()` / `reset_sequence()`：中断并清理过场，恢复相机处理与输入；reset 会重新允许本次遭遇播放。
- 失焦时暂停过场，清除 ESC 长按状态和进度，暂停流沙音轨。

后续改战斗状态机时，必须保留 active 隔离和黑场内交接。不要只恢复镜头而提前放开 AI，或者让正常结束、跳过走两套不同的站位和武器恢复逻辑。

## 文件清单

以下路径均相对本项目根目录；Godot 导入生成的对应 `.uid` 文件也已在工作区。

| 文件或目录 | 本次改动 |
| --- | --- |
| `scripts/cinematic/crown_intro.gd` | 新增，时序、双臂姿势、镜头、隔离与交接 |
| `scripts/cinematic/crown_prop.gd` | 新增，冠冕造型、表面采样、粒子预置 |
| `shaders/cinematic/crown.gdshader` | 新增，旧金属与同步粉化消散 |
| `shaders/cinematic/crown_grains.gdshader` | 新增，世界空间沙粒运动与退出 |
| `shaders/cinematic/grade.gdshader` | 新增，过场画面颜色与暗角 |
| `scripts/battle/playable_encounter.gd` | 修改，前述少量接入点 |
| `启动冠冕过场.command` | 新增，原生审阅快捷入口 |
| `tests/crown_intro_test.gd` | 新增，行为与交接回归 |
| `tests/crown_intro_review.gd` | 新增，真实场景关键帧渲染 |
| `docs/CROWN-INTRO-v01.zh-CN.md` | 新增，使用与实现说明 |
| `docs/HANDOFF-CROWN-INTRO-20260928.zh-CN.md` | 本交接文档 |
| `qa/crown-intro-v01/` | 新增，回归、渲染、导出、浏览器记录与截图 |
| `builds/crown-intro-v01/` | 新增，独立 Web 导出 |

`qa/crown-intro-v01/playable_encounter.before.gd.txt` 是本次接入前快照，用于看本轮差异。**不要把它直接覆盖回当前脚本**：主对话同期也在共享工作区开发，整文件回退可能丢失其他改动。本次没有创建 Git commit 或 PR，也没有修改 `project.godot`、导出预设或公共角色动画资源。

运行已有战斗测试时，该测试自身会写 `qa/iteration-v09/core-regression.json`；本轮控制台结果另存到 `qa/crown-intro-v01/combat-regression.log`。

## 验证证据与限制

| 检查 | 结果与证据 |
| --- | --- |
| 过场专项 | 25 项通过：`qa/crown-intro-v01/regression.json`、`test.log` |
| 现有战斗回归 | 152 项通过：`qa/crown-intro-v01/combat-regression.log` |
| 原生实际渲染 | 六张 PNG：冠冕、胸像、沙流、空手、广角、半淡黑；`review.json` 记录时间、机位、手部目标误差 |
| Web 导出 | 成功，见 `export.log` |
| 浏览器运行 | 见 `web-smoke.json`：观察到实际首镜头、自然结束、审阅结束不攻击及 R 重播，检查时控制台无错误或警告 |
| 浏览器采样 | 一次播放平均 29.3623 FPS，含交接约 10.5918 秒；非跨设备基准 |

专项测试覆盖了：过场期间的玩法冻结、镜头边界、双手到达目标点、9.4 秒半淡黑、自然结束、短按取消、长按跳过、重复交接不重复完成、恢复站位/武器/相机、失焦清理、reset、真实 approach 触发、恢复普通角色更新、动作看板不触发过场。

明确尚未完成的部分：

- 手指贴合和冠冕重量感仍需美术打磨；IK 腕部到点通过不等于指尖已无任何穿插。
- 目前主体是实体沙粒，尚没有完成参考图中浓密连续的细尘、沙帘和沉积层次；不要把程序颗粒数量当成最终视觉验收。
- 冠冕为本地原创程序网格，若后续替换成 Tripo/Blender 模型，需要重做表面采样并同步材质与粒子的时间场。`crown_prop.gd.release_time()` 与 `crown.gdshader` 的对应公式必须保持一致。
- 临时声音需替换或由用户审阅。
- ESC 的阈值、松开和失焦通过 Godot 输入事件检查；尚未在各浏览器逐一验证实体键长按、全屏退出或鼠标锁定的交互。
- Web 中文子集字体缺少跳过提示需要的字，因此提示暂用已有拉丁字体显示 `HOLD ESC TO SKIP`；如改回中文，应扩充字体子集。
- Web 首包约 200 MB PCK 加 38 MB WASM；尚未裁剪过场专用资源、做低配/移动端验证或保证稳定 60 FPS。
- 原生关键帧 QA 冻结玩法并按时刻采样，只证明对应画面的渲染；完整播放的证据来自另行进行的浏览器检查。

## 复现命令

在项目目录运行，Godot 复用仓库内已有工具，不依赖旧 Sekiro 运行时内容：

```sh
cd /Users/yangjianwen/Documents/aistudio/Gamebench/projects/gilded-ruin-boss

# 原生实时审阅
./启动冠冕过场.command

# 专项行为测试
../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script tests/crown_intro_test.gd

# 六个关键帧：需要实际渲染，不能改成 headless
../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot \
  --path . --resolution 1280x720 --script tests/crown_intro_review.gd

# 更新独立审阅构建
../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot \
  --headless --path . --export-release Web builds/crown-intro-v01/index.html

# 只有 8096 服务未运行时才启动；无需重复占用端口
python3 -m http.server 8096 --bind 127.0.0.1 --directory builds/crown-intro-v01
```

## 建议主对话接下来做什么

先让用户通过 8096 审阅实时效果，收集手势、沙流密度和镜头距离的意见。随后优先补细尘与连续沙流、手指贴合、正式音效，再做浏览器性能优化。要把它合入统一试玩交付时，保留这些源代码接入点，重新导出主 Web 构建，并从复活点实际走到 Boss 验证正常流程；不要只测试 `?crown-intro=1` 的直接审阅入口。

公开技术资料与分镜研究链接保存在分镜 README 和 `docs/CROWN-INTRO-v01.zh-CN.md` 中；运行时代码为本地新写，没有下载或集成第三方插件代码。
