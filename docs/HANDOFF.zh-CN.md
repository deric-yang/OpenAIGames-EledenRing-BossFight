# 恸哭沙丘 · Weeping Dunes

## 项目交接文档

- 交接日期：2026-09-27
- 项目目录：`projects/gilded-ruin-boss`
- 项目类型：西幻魂系 Boss Fight 垂直切片
- 当前阶段：场地与战斗白盒已完成，镜头/HUD/基础交互已完成首轮验证；美术资产、真实 WebGL2 导出和正式 Boss 内容尚未完成
- 总体状态：`可运行 / 可继续开发 / 视觉 revise / Web 未就绪`

> 本文严格区分“代码已经实现”“已经通过自动或实机验证”“仍是程序化占位”和“尚未开始”。不能把程序几何、Blender scaffold、Tripo dry-run 或 Godot Compatibility 运行结果描述为正式资产或 WebGL2 通过。

---

## 1. 项目定位与范围

“恸哭沙丘”是一个独立于 `projects/sekiro-combat` 的新项目。旧 Sekiro demo 只提供技术思路参考，不应继续向新项目整体复制场景、Boss 技能表、角色资产或旧设定。

当前切片的视觉目标：

- 近景：沙土、战争遗迹、残墙、武器残骸、旗帜、火炬和烟雾；
- 中景：宽阔、可读的战斗空间，玩家和 Boss 具有明显体型差；
- 远景：巨大衰败黑树、受控旧金色裂隙和半透明帷幔；
- 空气墙：放在远处，由沙丘、雾和遗迹自然隐藏；
- UI：暗红、旧金和羊皮纸色调，地点提示位于右下偏中；
- 镜头：支持自由视角、敌人锁定和大型 Boss 的仰角构图。

当前只把 Boss 当作比例和镜头占位体。Boss 正式外观、正式动作、正式技能和最终 AI 不属于本阶段完成内容。

---

## 2. 当前状态总览

| 子系统 | 当前状态 | 说明 |
| --- | --- | --- |
| Godot 工程启动 | 已完成并验证 | Godot 4.7.2、GL Compatibility、主场景可启动 |
| 程序化场地 | 已接入并可运行 | DunesScenery 已替换旧场地生成逻辑 |
| 玩家移动/疾跑/攻击/翻滚 | 已实现 | 属于白盒战斗逻辑，尚未接入正式动作 |
| Boss 占位追踪/攻击/阶段 | 已实现白盒版本 | 不是最终 Boss AI 或技能系统 |
| HP、受击、胜负流程 | 已实现白盒版本 | 仍需正式战斗数值和动作配合 |
| 自由视角 | 已实现并有原生回归 | 右键拖动、方向键旋转 |
| Tab 锁定 | 已实现并有实机截图 | 支持远距锁定和近距离仰角 |
| 相机碰撞与反馈 | 已实现并验证 | 球体扫掠、地面高度保护、震动、FOV kick |
| HUD/UI | 已实现并有实机截图 | 地点卡、玩家/Boss 血条、阶段文字、锁定标记 |
| 场地正式美术 | 未完成 | 当前仍是程序化代理几何 |
| Tripo 正式资产 | 未完成 | 仅有安全包装器、manifest 和 dry-run |
| Blender 正式运行时资产 | 未完成 | 当前是 procedural scaffold，尚未导出 runtime GLB |
| Godot Web 导出 | 未完成 | 缺少 export presets 和 Web 模板 |
| 浏览器性能验证 | 未开始 | 没有 WebGL2 FPS、GPU frame time 或首屏数据 |
| 音频播放 | 未完成 | 当前只有事件路由和表面反馈边界 |
| 正式 Boss 外观/技能/动作 | 未开始 | 按范围暂缓 |

---

## 3. 已完成并可继续使用的部分

### 3.1 Godot 工程与运行配置

主要文件：

- [`project.godot`](../project.godot)
- [`scenes/boot.tscn`](../scenes/boot.tscn)
- [`scripts/app/boot.gd`](../scripts/app/boot.gd)

当前配置：

- Godot 4.7.2；
- GL Compatibility；
- 1280×720 viewport；
- 1280×720 window override；
- 60 Hz physics；
- WebGL2-compatible renderer baseline；
- 主场景为 `res://scenes/boot.tscn`。

项目代码没有依赖 Sekiro 项目运行时资源。当前使用的 Godot 可执行文件位于旧项目的共享工具路径，只代表本机工具复用，不代表新项目依赖旧项目内容。

### 3.2 程序化场地 DunesScenery

主要文件：

- [`scripts/world/dunes_scenery.gd`](../scripts/world/dunes_scenery.gd)
- [`shaders/world/veil.gdshader`](../shaders/world/veil.gdshader)

DunesScenery 当前负责：

- 起伏沙丘地形；
- 平整战斗核心；
- 连贯锥管网络构成的黑树；
- 金色裂隙；
- 曲面半透明帷幔；
- 边缘遗迹；
- 旗帜；
- 武器残骸；
- 地形碰撞代理；
- 战斗核心碰撞代理；
- 遗迹碰撞代理。

当前空间约定：

- 战斗核心物理尺寸约 22m × 18m；
- 角色活动边界约 x=`[-48, 48]`、z=`[-43, 43]`；
- 黑树根部约位于 `(0, 0, -38)`；
- 外圈空气墙使用独立 collision layer 4；
- 相机只扫描 layer 1，因此不会被空气墙近距离推挤；
- 树、裂隙、帷幔、旗帜和武器残骸不提供硬碰撞。

最近修复：

- 将三支火炬移到战斗核心外围，避免近距离锁定时遮挡玩家/Boss 中轴；
- 降低火焰 emission，减少白色高光球体感；
- 增加平整核心 BoxShape3D，修复角色在起伏地形碰撞上的下沉问题。

当前限制：

- 地形边缘仍偏直；
- 树根和沙丘的融合仍不自然；
- 遗迹和残骸仍明显是方块白盒；
- 烟尘、材质变化、接触阴影和前景层次不足；
- 帷幔仍需继续处理透明排序和 overdraw；
- 场地尚未接入正式 Tripo/Blender runtime 资产。

### 3.3 玩家与 Boss 白盒战斗

主要文件：

- [`scripts/actors/player_controller.gd`](../scripts/actors/player_controller.gd)
- [`scripts/actors/boss_controller.gd`](../scripts/actors/boss_controller.gd)
- [`scripts/encounter/boss_encounter.gd`](../scripts/encounter/boss_encounter.gd)
- [`scripts/encounter/phase_controller.gd`](../scripts/encounter/phase_controller.gd)
- [`scripts/core/combat_event_bus.gd`](../scripts/core/combat_event_bus.gd)

已经实现：

- 相对相机的 WASD 移动；
- 普通移动和 Shift 疾跑；
- 左键/J 攻击；
- 空格翻滚；
- R 重置遭遇；
- 玩家/Boss HP；
- 玩家受击；
- Boss 追踪与定时攻击；
- Phase I/Phase II 阶段切换；
- Boss 归零后的 execution 阶段；
- 玩家死亡和胜利流程；
- 战斗事件广播；
- 表面查询和脚步反馈。

当前战斗实现是白盒版本：

- 玩家攻击使用根节点距离和攻击时间窗口判断命中；
- Boss 攻击使用距离范围判断命中；
- 尚未使用正式方向性 Hitbox、动作蒙太奇或正式技能状态机；
- Boss 的正式技能表、冲击等级、技能节奏和动作表现尚未定稿；
- Boss AI 当前只是可运行的占位决策，不应视为最终 AI。

### 3.4 CameraDirector

主要文件：

- [`scripts/feedback/camera_director.gd`](../scripts/feedback/camera_director.gd)

已经实现：

- 开场镜头；
- 自由视角；
- 右键拖动；
- 左右方向键旋转；
- Tab 物理锁定/解除锁定；
- 玩家/Boss 实际 Mesh 包围盒取景；
- 动态锁定关注点；
- 大型 Boss 近距离仰角；
- 相机球体障碍扫描；
- 地面高度保护；
- 命中震动；
- Boss 落地震动；
- 阶段转场震动；
- FOV kick；
- 重置时清理锁定和震动状态。

锁定相机使用玩家和 Boss 的包围盒共同计算距离，Boss 高度越明显，关注点越向上移动。近距离截图中，玩家和 Boss 都保持在画面内，脚底和血条之间保留了间隔。

已知改进方向：

- 近距离锁定时玩家和 Boss 仍有部分轮廓重叠；
- 可以增加轻微过肩偏置；
- 自由实时机位仍有一定留白；
- 需要继续用正式资产和真实动作检查遮挡；
- 浏览器输入和浏览器窗口缩放仍未验证。

### 3.5 EncounterHUD

主要文件：

- [`scripts/ui/encounter_hud.gd`](../scripts/ui/encounter_hud.gd)

已经实现：

- 玩家血条左上；
- Boss 血条底部；
- 延迟虚血追赶效果；
- PHASE I/PHASE II 文本；
- FIGHT/阶段状态文本；
- Tab 锁定标记；
- 右下偏中的地点卡；
- 地点标题“恸哭沙丘”；
- 地点副标题“风暴遗迹战场”；
- 地点卡淡入、停留和渐隐；
- 开发操作提示通过 `--debug-hud` 控制。

重要说明：

- 窗口标题中的 `(DEBUG)` 是 Godot debug-build/启动环境装饰，不等于 `--debug-hud` 已开启；
- 默认启动不应显示底部开发操作提示；
- 正式验收时应使用 `debug_hud_enabled=false` 的运行清单确认，而不能只看文件名或窗口标题；
- 阶段文字已经切换，但 Boss 血条颜色和装饰强度尚未按阶段完整变化。

### 3.6 Surface、事件和音频边界

主要文件：

- [`scripts/world/surface_query.gd`](../scripts/world/surface_query.gd)
- [`scripts/world/surface_feedback.gd`](../scripts/world/surface_feedback.gd)
- [`scripts/feedback/audio_event_router.gd`](../scripts/feedback/audio_event_router.gd)

当前已实现：

- `sand`；
- `ruin_stone`；
- `wet_sand`；
- 脚步事件；
- 战斗事件；
- SurfaceFeedback 脉冲；
- AudioEventRouter 事件接收边界。

当前没有完成：

- 最终音效文件；
- AnimationPlayer/AnimationTree 音频 cue 绑定；
- 授权音频包；
- `metal_slag`、`wood_debris` 等扩展表面标签。

---

## 4. 已验证的 QA 与实机证据

### 4.1 自动测试

白盒测试：

```text
WHITEBOX_TEST_PASS checks=8
```

相机回归：

```text
CAMERA_REVIEW_PASS checks=27 failures=0
```

非 headless 的历史截图矩阵：

```text
CAMERA_REVIEW_PASS checks=37 failures=0
```

两者差异来自非 headless 模式下额外的截图保存和视觉证据检查。不要把 27 和 37 当成互相矛盾的功能结果。

Tripo 离线测试：

```text
Ran 8 tests
OK
```

相关文件：

- [`tests/whitebox_test.gd`](../tests/whitebox_test.gd)
- [`tests/camera_review.gd`](../tests/camera_review.gd)
- [`tests/test_tripo_pipeline.py`](../tests/test_tripo_pipeline.py)

### 4.2 真实 Godot GUI 证据

主要证据：

- [`qa/live-v2/06-reset-location.png`](../qa/live-v2/06-reset-location.png)：真实地点卡和开场构图；
- [`qa/live-v2/10-postfix-free.png`](../qa/live-v2/10-postfix-free.png)：火炬移到外围后的自由视角；
- [`qa/live-v2/12-postfix-lock-explicit.png`](../qa/live-v2/12-postfix-lock-explicit.png)：明确 Tab 锁定状态；
- [`qa/live-v2/13-final-flame-intro.png`](../qa/live-v2/13-final-flame-intro.png)：最终火焰调校后的开场；
- [`qa/live-v2/14-final-lock.png`](../qa/live-v2/14-final-lock.png)：最终火焰调校后的锁定画面；
- [`qa/live-v2/encounter-input-review-final.mov`](../qa/live-v2/encounter-input-review-final.mov)：约 7.95 秒真实窗口录制；
- [`qa/live-v2/run-manifest.json`](../qa/live-v2/run-manifest.json)：脱敏运行清单。

最终录制信息：

- 分辨率：1504×1008；
- 时长：约 7.95 秒；
- 输入序列记录为 Tab、移动、翻滚和解除锁定；
- 证明真实窗口捕获完成；
- 不替代逐帧自动化输入断言，也不代表浏览器输入验证完成。

### 4.3 场地和 Blender 证据

主要证据：

- [`qa/scenery/dunes_scenery_validation.txt`](../qa/scenery/dunes_scenery_validation.txt)
- [`qa/blender/blender_review_summary_v004.json`](../qa/blender/blender_review_summary_v004.json)
- [`qa/blender/mcp_inspect_final.json`](../qa/blender/mcp_inspect_final.json)
- [`qa/blender/weeping_dunes_final_v004.png`](../qa/blender/weeping_dunes_final_v004.png)

Blender 当前记录：

- 场景：`WeepingDunes_Assembly`；
- 自有对象：98；
- 一台 review camera；
- 五个项目灯光；
- Blender 原生 Z-up；
- `negative_determinant_mapping=false`；
- 没有项目自有 `.001/.002` 重复对象；
- 状态：`procedural_scaffold_needs_Tripo_visual_replacement`；
- runtime export：未完成，等待视觉和性能审计。

---

## 5. 尚未完成、部分完成与阻塞项

### 5.1 正式美术资产

当前没有正式 Tripo runtime 资产进入项目。

尚未完成：

- 黑树正式模型；
- 树根和岩土连接件；
- 遗迹模块；
- 战场残骸；
- 武器残骸；
- 战旗；
- 帷幔正式低模/透明版本；
- 烟尘和灰烬资产；
- 玩家高模和正式武器；
- Boss 正式外观。

当前场景中的几何全部应视为程序化白盒或 Blender procedural scaffold。

### 5.2 Tripo 管线

已经完成：

- 八项资产 manifest；
- dry-run；
- 安全环境变量读取；
- 原子 request marker；
- 重复提交保护；
- HTTPS signed URL 校验；
- signed URL 不进入 argv/记录；
- GLB v2 校验；
- 失败响应脱敏；
- `curl -q` 防止读取用户级配置；
- 8/8 离线测试。

尚未完成：

- 真实 API schema 核验；
- 余额查询；
- 任务提交；
- task ID；
- 费用记录；
- GLB 下载；
- hash；
- 许可证审核；
- Blender 清理和运行时导出。

项目内目前只有内部管线说明 [`docs/TRIPO-PIPELINE.zh-CN.md`](TRIPO-PIPELINE.zh-CN.md)，没有核实到独立官方离线 API 文档副本。当前 `BASE_URL`、endpoint、request schema、response schema 和模型字段不能视为已由官方文档确认。

### 5.3 Blender/MCP

Blender scaffold 已建立，但正式拼装链没有闭环。

当前需要外部条件：

```sh
export BLENDER_MCP_COMMAND=/absolute/path/to/mcp-for-blender
```

项目自带 launcher 会在没有这个变量时明确失败。当前环境没有确认到可直接使用的外部 Blender MCP command、Blender MCP Python 依赖或最终 runtime export 环境。

只读检查命令：

```sh
cd projects/gilded-ruin-boss
export BLENDER_MCP_COMMAND=/absolute/path/to/mcp-for-blender
python3 tools/blender-mcp/client.py tools/blender-mcp/inspect_scene.py
```

不要在依赖未准备好时运行 build/export 脚本，也不要把 procedural `.blend` 直接当成 runtime 资产。

### 5.4 WebGL2 与浏览器

当前 Web readiness 为未通过。

阻塞项：

- 缺少 `export_presets.cfg`；
- 缺少 Godot Web export templates；
- `builds/` 没有 Web 构建；
- 没有 Playwright、Selenium 或 Pyppeteer；
- 没有真实 Chrome/Edge/Firefox/Safari 操作矩阵；
- 没有 FPS、GPU frame time、首屏加载时间、纹理内存或透明 overdraw 数据；
- 没有 Web High/Balanced/Low 三档验收。

当前原生 Compatibility 指标只能作为本机 OpenGL 基线，不能替代 WebGL2 性能报告。

预检命令：

```sh
cd projects/gilded-ruin-boss
GODOT_BIN=/absolute/path/to/Godot python3 tests/web_preflight.py --strict
```

本机已知 Godot 路径示例：

```text
/Users/yangjianwen/Documents/aistudio/Gamebench/projects/sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot
```

这个路径是共享工具路径，不代表新项目依赖 Sekiro 代码或资产。

### 5.5 正式战斗内容

以下内容还没有进入正式制作：

- 正式 Boss 外观；
- 正式 Boss 技能表；
- 正式动作；
- 动作重定向；
- 骨骼重定向；
- Boss 正式 AI 决策表；
- 正式受击动画；
- 正式冲击等级反馈；
- 最终数值平衡；
- 正式处决表现；
- 正式音效和音乐。

旧项目中的翻滚、疾跑、攻击窗口、HP、受击、冲击反馈和事件总线思想可以继续复用，但不能直接复制旧 Boss 技能表或旧场景结构。

---

## 6. 推荐后续开发顺序

### P0：保持当前切片可交接

1. 保留当前 Godot 回归和实机证据；
2. 不把程序白盒标记为正式资产；
3. 继续保留 Tripo key 只通过 `TRIPO_API_KEY` 注入的规则；
4. 对已经在聊天中暴露的 key 进行轮换；
5. 不进行未经文档核实的真实 Tripo 提交。

### P1：补齐工具和资产生产闭环

1. 获取不包含凭据的官方 Tripo 离线 API 文档；
2. 核对 endpoint、认证、request 和 response schema；
3. 在可信的本地终端先执行只读余额检查；
4. 只提交一个代表性资产进行验证；
5. 保存 task ID、费用、hash、许可证和处理记录；
6. 在 Blender 中完成减面、LOD、UV2、材质整理和碰撞代理；
7. 导出一个 runtime GLB 并在 Godot 中验证；
8. 重新进行截图、性能和人工视觉检查。

### P2：替换白盒场地

1. 优先替换黑树和树根；
2. 替换遗迹模块；
3. 替换前景残骸、旗帜和武器；
4. 将帷幔收敛为低面数透明运行时版本；
5. 增加沙土材质变化、接触阴影和轻量烟尘；
6. 重新调整自由视角留白和近锁定过肩偏置；
7. 检查资产是否遮挡玩家、Boss、脚底和武器轨迹。

### P3：建立 WebRenderLab 与 Web 导出

1. 添加 `export_presets.cfg`；
2. 安装 Godot Web templates；
3. 导出第一个 WebGL2 build；
4. 使用 Chrome 完成启动和输入；
5. 采样 FPS、GPU frame time、draw calls、三角形、纹理内存、首屏加载；
6. 处理帷幔透明 overdraw；
7. 建立 Web High/Balanced/Low；
8. 再扩展到其他浏览器。

### P4：正式角色与 Boss

只有场地、UI、镜头和 Web 基线通过后，再开始：

1. 玩家高模和武器；
2. 玩家动作重定向；
3. 正式三连击；
4. Boss 正式外观；
5. Boss 正式动作和技能；
6. 正式 AI；
7. 冲击等级与镜头反馈；
8. 数值平衡和完整遭遇流程。

---

## 7. 常用运行与验证命令

以下命令均在项目目录执行：

```sh
cd projects/gilded-ruin-boss
```

启动真实 Godot：

```sh
GODOT_BIN=/absolute/path/to/Godot
"$GODOT_BIN" --single-window --path . --resolution 1280x720
```

启动并显示开发提示：

```sh
"$GODOT_BIN" --single-window --path . --resolution 1280x720 -- --debug-hud
```

Godot 白盒测试：

```sh
"$GODOT_BIN" --headless --path . --script tests/whitebox_test.gd
```

Godot 相机回归：

```sh
"$GODOT_BIN" --headless --path . --script tests/camera_review.gd
```

Tripo 离线测试：

```sh
python3 -m unittest discover -s tests -p 'test_tripo_pipeline.py' -v
```

Tripo dry-run：

```sh
python3 scripts/tripo/generate.py submit --dry-run
```

Web 预检：

```sh
GODOT_BIN=/absolute/path/to/Godot python3 tests/web_preflight.py --strict
```

Godot 编辑器导入检查：

```sh
"$GODOT_BIN" --headless --path . --editor --import --quit
```

---

## 8. 交接时的安全规则

1. 不在文档、命令参数、日志、场景资源、GDD 或公开仓库中写入 Tripo API key。
2. 不复制或输出已经出现在聊天记录中的 key；该 key 应立即轮换。
3. Tripo wrapper 只允许从进程环境 `TRIPO_API_KEY` 读取凭据。
4. 不把 signed download URL 写入 argv、日志或审计记录。
5. 不保存完整私密 Tripo response。
6. 不把 Tripo 生成资产自动标为 CC0。
7. 每个资产必须记录 prompt、negative prompt、模型、面数限制、纹理质量、seed、task ID、费用、hash、许可证和人工审核结果。
8. 未经视觉、性能和许可证审核的资产不得进入 `assets/runtime/`。
9. 不要把 native Compatibility draw calls 当作 WebGL2 性能。
10. 不要把 Blender procedural scaffold 当作正式资产。
11. 不要把 Tripo dry-run 当作真实任务提交。
12. 不要把“Godot 窗口标题包含 DEBUG”当作 `--debug-hud` 已开启的证据。

---

## 9. 交接验收结论

当前可以交接的是一套可运行的场地与战斗白盒基础：

- 项目可以启动；
- 场地结构已经建立；
- 玩家和 Boss 可以进行基础遭遇；
- 相机自由/锁定/仰角逻辑已经建立；
- HUD 已经建立；
- 原生 Godot 回归和真实窗口截图/短录制已有证据；
- Tripo 安全 dry-run 管线已有测试；
- Blender procedural scaffold 已保留。

当前不能交接为“最终完成”的部分：

- 正式场地美术；
- 正式角色与 Boss 资产；
- 正式 Boss 技能和 AI；
- 最终音频；
- Tripo 真实资产生成；
- Blender runtime GLB 导出；
- Godot Web 导出；
- 浏览器性能与跨浏览器验证；
- Web High/Balanced/Low 质量档位；
- 最终视觉验收。

下一位开发者应先完成工具链和一个代表性正式资产的闭环，再批量替换场地白盒，不建议立即进入 Boss 技能或完整 AI 重构。
