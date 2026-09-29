## 当前更新：Victor 台词、字幕与已确认战斗版本

六句 Victor 英文配音与中文字幕已接入冠冕、起身、重击、怒吼和胜负事件；台词播放时音乐/环境声平滑降低 9dB。保留 V11 输入、胜后自由移动、R 重开、冠冕过场、200 点玩家生命及已确认的音乐与裂地声音。

[试玩正式版](http://127.0.0.1:8093/?build=voice-victor) · [配音与管线交接](docs/HANDOFF-VICTOR-VOICE-20260929.zh-CN.md) · [本次同步范围](docs/RELEASE-20260929.zh-CN.md)

V12.2 的 64 个战斗音效候选仍在独立看板等待用户裁定，没有替换正式 SFX；客观验证通过不代表最终主观试听验收。

## V11 输入与胜利后自由移动

沿用已确认的 200ms 单指令缓冲、翻滚保护和轻攻击连段宽限。击败 Boss 后可继续走路、疾跑、翻滚并自由调整镜头，胜利播报与「霸王之枪」奖励照常显示；按 R 返回复活符文，重开完整遭遇。

[试玩新版](http://127.0.0.1:8093/?build=input-v11-victory) · [V11 输入交接](docs/HANDOFF-INPUT-V11-20260929.zh-CN.md) · [战后移动说明](docs/POST-VICTORY-V11-20260929.zh-CN.md)

## 冠冕过场衔接、战斗音乐与玩家生命值

Boss 从捧冠跪姿候场，过场结束后起身开战；战斗 BGM 换为用户提供的《The Final Battle》；玩家生命值 100 → 200，血条尺寸不变。

新增 SFX039 两段首波形落石音效，跟随四个裂地招式随机播放；开战前改为增益 30% 的地震低频循环环境音。

[更新说明](docs/CROWN-COMBAT-UPDATE-20260928.zh-CN.md) · [主试玩](http://127.0.0.1:8093/) · [过场预览](http://127.0.0.1:8093/?crown-intro=1)

## V09 战斗与资产基线

已加入推开/怒吼后的有界连招、重新生成并绑骨的无披风骑士、旗枪挂点混合修复、新「霸王之枪」奖励卡、平整复活符文台地。

[本轮说明](docs/iteration-v09/PLAYABLE.zh-CN.md) · [游戏](http://127.0.0.1:8093/) · [审阅页](http://127.0.0.1:8093/v09-review/)

# V08 当前交付：古战场遗迹

[试玩](http://127.0.0.1:8093/) · [Boss 动作看板](http://127.0.0.1:8093/boss-motions/) · [V08 说明与验证](docs/iteration-v08/PLAYABLE.zh-CN.md)

本轮替换黑色裂纹，重做砂石喷流与前戳岩石隆起；加入双方脚步尘土、平滑白色武器气流、短促局部径向模糊。修正跑动持剑姿态，并为 Boss 增加按迈步周期推进的位移。

以下为历史版本记录。

# V07 当前交付：古战场遗迹

[试玩](http://127.0.0.1:8093/) · [Boss 动作看板](http://127.0.0.1:8093/boss-motions/) · [V07 完整说明](docs/iteration-v07/PLAYABLE.zh-CN.md)

恢复完整玩家与披风、修正右手持剑；双方同步 6–10 帧命中冻结；推掌和怒吼零伤害站立击退；重新匹配跑步步频，加入少量起手低吼、推进式砂石裂隙、下砸尘土和短促位移震动。完整 Blender 场景：`assets/processed/battlefield_v07/ancient-battlefield-v07.blend`。

以下为历史版本记录，当前行为以 V07 文档为准。

# 恸哭沙丘 · Weeping Dunes

独立于 `projects/sekiro-combat` 的西幻魂系 Boss Fight 垂直切片。旧项目只提供技术链参考；本项目拥有独立的 Godot 工程、运行时数据、场地资产和 QA 记录。

## 2026-09-27 开发更新

**当前版本 V04**：新银灰骑士与羽饰老将、战旗长枪、起伏沙丘、分散残骸、接地半透明魂幡已接入可玩战场。包含动作重映射、战斗与重生闭环、指定血液/消散特效和音效。入口 [可玩战场](http://127.0.0.1:8093/) / [资产与动作审阅](http://127.0.0.1:8093/asset-review/)。双击 `启动游戏.command` 可原生运行；`打开Blender完整场景.command` 打开完整可编辑场景。操作、资产统计、验证与本版限制见 [V04 说明](docs/iteration-v04/PLAYABLE.zh-CN.md)。

以下是历史版本记录，其中巨剑、白盒和“尚未接入”等描述仅代表当时状态。

**场景装配 v03**：[打开整体场景](http://127.0.0.1:8093/?assembly-v03=1)。玩家、Boss、增粗剑柄后的巨剑、沙丘、树、剑冢、魂幡、篝火和发光复活符文已拼入独立静态预览；按 1–5 检查战场、Boss、握柄、全景和复活点。详见 [场景装配记录](docs/ASSEMBLY-v03.zh-CN.md)。新符文生成消耗 50 credits，余额 915。角色握指、动画与战斗接入尚未完成。

**最新资产修订 v02**：Boss 改为一把厚重直刃巨剑；黄金树造型已获用户认可；新增插剑群、枪戟群、带循环飘动的半透明魂幡，以及本地 Blender 建模的 320×360 米沙丘。详见 [第二轮资产记录](docs/ASSETS-v02.zh-CN.md)，[资产审阅页](http://127.0.0.1:8093/asset-review/) 已撤下旧弯刀并展示新版。本轮新增生成消耗 150 credits，余额 965。

最新状态见 [首轮开发记录](docs/DEVELOPMENT-v01.zh-CN.md)。以下早期阶段说明作为历史保留；本次用户需求优先：玩家改为银灰甲，Boss 外观提前制作，玩家动作允许从 Sekiro 迁移，地点提示改为屏幕中央。

- `启动UI预览.command`：红／绿条、虚血、地点、胜利烟雾和奖励的交互审阅。
- `启动游戏.command`：白盒场景、插剑复活火堆及新版 HUD。
- 已生成银灰骑士、Boss 拆件与场景概念图，位于 `docs/concepts/v01`。
- Web 构建位于 `builds/web`；启动该目录的本地服务后，`?ui=1` 进入 UI 预览。
- 首批 5 件 Tripo 原件已生成并下载：银灰骑士、Boss 主体、巨刀、黄金树、战争残骸。消耗 260 credits，查询余额 1115；静态原件尚未绑骨或接入游戏。
- [资产审阅页](http://127.0.0.1:8093/asset-review/)：逐件旋转查看 GLB 与三视角渲染；记录见 `docs/ASSETS-v01.zh-CN.md`。
- 原生 UI 时序检查 15 项、白盒检查 8 项、相机检查 27 项已通过；Web 完整性能基准仍未完成。

## 当前阶段

当前优先推进场地、UI、镜头构图和浏览器渲染样板：

- 近景：沙土、破碎遗迹、战争残骸、旗帜、火炬和尘雾；
- 中景：宽阔战斗核心、玩家、简单体块 Boss 占位；
- 远景：衰败黑树、金色裂隙、半透明帷幔和远置空气墙；
- UI：右下角“恸哭沙丘”地点提示、玩家血条、Boss 血条和阶段状态；
- 镜头：自由视角、Tab 锁定、巨大 Boss 的仰角构图和冲击反馈。

玩家、玩家武器、遗迹、遗骸、旗帜、火炬和远景资产可以提前通过 Tripo 生成，再经过 Blender 清理、减面、LOD、碰撞代理和运行时导出。Boss 正式形象暂时保持体块占位，不在本阶段冻结 Boss Lore、技能模组或动作库。

## 交接文档

完整的当前状态、已完成能力、验证证据、阻塞项、运行命令、资产管线和后续开发顺序见 [项目交接文档](docs/HANDOFF.zh-CN.md)。

## 运行

使用 Godot 4.7.2：

```sh
godot --headless --path . --editor --import --quit
godot --path .
```

默认控制：WASD 相对镜头移动，Shift 疾跑，鼠标左键或 J 攻击，空格翻滚，R 重置遭遇，Tab 锁定/解除锁定。自由视角按住鼠标右键拖动，或用左右方向键旋转；松开右键/Esc 释放鼠标。

开发操作提示默认隐藏，使用 `godot --path . -- --debug-hud` 显示。地点卡位于右下偏中，文字与装饰一起淡入淡出。

## 可复现检查

```sh
godot --headless --path . --script tests/whitebox_test.gd
godot --path . --fixed-fps 60 --script tests/camera_review.gd -- --qa-output=res://qa/camera-review
python3 -m unittest discover -s tests -p 'test_tripo_pipeline.py' -v
python3 scripts/tripo/generate.py submit --dry-run
GODOT_BIN=/absolute/path/to/Godot python3 tests/web_preflight.py
```

镜头检查加载真实场景，通过物理按键事件测试 Tab 和自由旋转，保存选定稳定帧及 JSON 指标，不生成整段 PNG 电影。部分构图夹具冻结 Boss/玩家逻辑，报告中明确标注；原生运行截图不等于浏览器性能验收。最新结论见 [视觉检查记录](qa/VISUAL-REVIEW.zh-CN.md)。

`tests/web_preflight.py` 会检查 Web 导出预设、Godot Web 模板、浏览器和自动化工具，并把结果写入 `qa/web/readiness.json`。当前报告明确阻塞于缺少 `export_presets.cfg` 和 Godot Web 导出模板，因此尚未生成 WebGL2 包，也不能报告浏览器 FPS、GPU 帧时间或首屏加载。

Tripo 当前尚未在线提交资产任务，现有场地/角色仍是程序化占位，不能视为正式生成资产。离线 dry-run 不读取凭据、不产生费用；在线方式见 [Tripo 管线说明](docs/TRIPO-PIPELINE.zh-CN.md)。

## 设计边界

- 新项目不读取 `sekiro-combat` 的运行时脚本、资产或 `user://` 数据。
- 旧项目仅作为战斗规则、动作适配、镜头和资产流程的参考。
- 当前阶段不做 Boss AI 重构、正式 Boss 技能、动作迁移或骨骼重定向。
- 不直接复制任何现有作品的角色外观、名称、动作、字体或专有 UI 素材。
- Tripo 原始资产、加工资产和运行时资产分离；生成记录、hash、费用和授权状态单独登记。

## 目录

- `docs/`：范围、体验目标、资产、Web 渲染和 QA 记录。
- `scenes/`：Godot 场景入口。
- `scripts/`：遭遇、战斗、镜头、反馈和环境模块。
- `assets/source/`：Tripo/外部原始来源。
- `assets/processed/`：Blender 清理、LOD、碰撞和材质整理结果。
- `assets/runtime/`：Godot/Web 运行时资产。
- `generation-records/`：脱敏的生成任务、hash、费用和许可证记录。
- `qa/`：截图、浏览器性能和人工验收证据。

## 验收原则

代码测试、Godot 实际渲染、真实浏览器性能和人工视觉检查分开记录。首版资产必须经过“生成 → Blender 拼装 → Godot 导入 → 截图 → 视觉检查 → 性能采样”的闭环，不能把第一版生成结果自动标记为完成。
