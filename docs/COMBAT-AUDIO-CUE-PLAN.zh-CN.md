# 战斗动作与音频 Cue 规划

状态：动作模组接入前的音频事件设计文档。

本文件先定义事件、资源登记和时间点规则，不在当前阶段复制正式音频、不修改播放器代码，也不绑定尚未接入的动作帧。

关联文件：

- [项目说明](../README.zh-CN.md)
- [资产来源台账](ASSET-LEDGER.zh-CN.md)
- [音频反馈约定](AUDIO-FEEDBACK.zh-CN.md)
- [QA 清单](QA-CHECKLIST.zh-CN.md)
- [UE/FBX/VFX 资产迁移方案](UE-ASSET-MIGRATION-TO-GODOT-WEB.zh-CN.md)
- `scripts/core/combat_event_bus.gd`
- `scripts/feedback/audio_event_router.gd`
- `scripts/encounter/boss_encounter.gd`

---

## 1. 目标和当前边界

本项目首批战斗音频需要覆盖：

- 玩家轻脚步；
- 玩家重脚步；
- Boss 轻脚步和重脚步；
- 攻击命中身体的冲击音；
- 处决启动时的低沉、震撼音；
- 处决完成、Boss 大量喷血时的身体命中音；
- 后续与动作、粒子、摄像机冲击共享同一条可回放时间线。

用户已经 review 的候选语义为：

- `cinematic_deep_low_whoosh_impact_05`：处决动作开始、进入发动段时播放；
- 子弹命中身体类音效：普通攻击命中后的冲击候选，以及处决完成、Boss 大量喷血时的第二个冲击层。

当前 `gilded-ruin-boss` 仍是“只发事件、不播放正式音频”的白盒阶段：

- `CombatEventBus` 已提供统一事件信号和 `event_id`、`encounter_id`、`combat_time`、`type` 等时间线信息；
- `AudioEventRouter` 当前只记录最近事件和计数，没有正式资源字典或播放器；
- 项目暂未接入动作模组、`AnimationPlayer`/`AnimationTree` 动画库和正式音频文件；
- 因此本文件不猜测具体帧数，具体绑定要等主对话完成动作接入后再校准。

---

## 2. 推荐音频架构

保持事件与资源解耦：

```text
角色 / 遭遇 / 动画 cue
        ↓
CombatEventBus
        ↓
AudioEventRouter
        ↓
资源字典 + 变体选择 + 音频参数
        ↓
AudioStreamPlayer3D / 播放器池 / Audio Bus
```

### 2.1 角色脚本不直接加载声音

`PlayerController`、`BossController` 和动作脚本不应硬编码：

```gdscript
load("res://some/path/impact.wav")
```

它们只负责发出语义事件，例如：

```gdscript
{
    "type": "hit",
    "actor": "player",
    "target": "boss",
    "impact_tier": 2,
    "world_position": hit_position,
    "event_id": event_id,
    "combat_time": combat_time
}
```

由 `AudioEventRouter` 根据 `type`、`surface_id`、`impact_tier`、`actor`、`world_position` 和质量档位选择资源。

### 2.2 播放器形式

第一版验证可以使用普通 `AudioStreamPlayer`，但正式战斗反馈更适合：

- 角色和 Boss 脚步：`AudioStreamPlayer3D` 或小型播放器池；
- 命中和处决：以事件的 `world_position` 为播放位置；
- Cinematic 处决音：必要时使用非空间化或弱空间化总线，避免镜头远离 Boss 后关键音效过度衰减；
- 短促重复音：限制并发数量，避免一帧内多个粒子或碰撞产生声音墙；
- 总线至少区分 `SFX`、`Combat`、`Cinematic` 和 `Ambience`，具体实现后再冻结。

### 2.3 脚步只有一个权威入口

当前 `BossEncounter.emit_step()` 会发出脚步事件并触发表面反馈；项目还存在独立的 `footstep_emitter.gd` 参考实现。正式接入前必须选定一个运行时入口，避免同一步产生双重音效。

推荐：

```text
角色移动 / 动作时间线
→ BossEncounter.emit_step()
→ player_step 或 boss_step
→ SurfaceQuery 得到 surface_id
→ AudioEventRouter 选择脚步变体
```

---

## 3. 音效资源登记

每个候选音频进入项目以前，至少记录：

| 字段 | 说明 |
|---|---|
| `asset_id` | 稳定的内部 ID，不直接使用临时文件名 |
| 原始文件名 | 保留来源名称，便于追溯 |
| 来源路径 | Downloads、UE 导出路径或外部来源 |
| 来源提供者/URL | 记录页面、版本和获取日期 |
| 许可证 | 原文、版本、署名和 Web 再分发结论 |
| 原始 hash | SHA-256 |
| 处理 hash | 裁剪、降噪、响度或格式转换后的 hash |
| 格式 | WAV、Ogg 或 MP3 |
| 采样率/声道 | 例如 44.1 kHz、mono/stereo |
| 时长与峰值 | 防止首尾空白和削波影响节奏 |
| 用途 | `footstep`、`impact`、`execution` 等 |
| 事件绑定 | 事件类型、冲击等级和动作 cue |
| 质量档位 | High/Balanced/Low 是否保留 |
| 审核状态 | `approved / revise / reject / deferred` |

“能在电脑上播放”不等于“允许进入公开 Web 包”。Pro Sound、Fab、Mixamo、UE Marketplace/Fab、Tripo 或用户下载素材均须单独确认许可。

---

## 4. 首批事件和 Cue 表

### 4.1 脚步

| 事件 | 触发条件 | 资源选择 | 参数建议 |
|---|---|---|---|
| `player_step` | 玩家脚掌真实接触地面 | `surface_id` + `impact_tier` | 轻脚步优先，低并发，轻微 Pitch 随机 |
| `boss_step` | Boss 脚掌或重足接触地面 | `surface_id` + `impact_tier` | 重脚步、较低 Pitch、较高音量和更长衰减 |
| `player_roll` | 翻滚接触或起身段 | 后续单独的衣料/落地资源 | 不与普通脚步重复播放 |

首批表面标签与当前文档保持一致：

- `sand`
- `ruin_stone`
- `wet_sand`
- `metal_slag`
- `wood_debris`

目前 `SurfaceQuery` 已覆盖 `sand`、`ruin_stone`、`wet_sand`，`metal_slag` 和 `wood_debris` 仍需要实际查询区域或材质注册后再启用对应音效。

脚步变体规则：

- 每个表面至少准备 3 个可互换变体，再逐步增加；
- 轻脚步与重脚步不要只通过音量区分，优先使用不同录音或处理版本；
- 随机 Pitch 建议保持窄范围，例如 `0.96–1.04`，并使用可复现的随机源或事件 ID；
- Boss 重脚步可以附加低频层，但不应让每次脚步都触发大型冲击音；
- 玩家高速移动时需要节流，避免脚步间隔小于素材攻击时间；
- 3D 衰减、最大距离和遮挡效果必须在浏览器实机试听。

### 4.2 普通攻击命中

推荐将攻击事件拆成以下语义，不让音频路由猜测：

```text
attack_started       起手或挥动开始
attack_swing         武器快速通过空气，可选挥空层
attack_hit_confirmed 有效帧命中目标
hit                  伤害/命中结算
impact_vfx           冲击特效
```

如果当前系统暂时只有 `hit`、`player_hit` 或 `boss_landed`，应在动作模组接入后确认这些事件的真实语义。特别是 `boss_landed` 当前可能更接近攻击结算，而不一定表示真实脚底落地，不能未经确认就用它播放 Boss 落地音。

攻击命中身体的子弹命中类音效可以作为：

- 普通轻攻击的短促冲击；
- 普通重攻击的低频增强版本；
- Boss 命中玩家的受击层；
- 处决完成后的最终肉体冲击。

不应把同一个音效同时当作：

- 攻击起手；
- 挥空；
- 命中确认；
- 处决启动；
- 处决完成。

不同语义需要不同 cue 或明确的混音层，避免一个音频文件承担整个动作。

### 4.3 处决启动

事件建议使用：

```text
execution_started
```

但只有在处决动画真正进入发动段时才触发音频，而不是在玩家按键、进入处决窗口或 UI 提示出现时立即播放。

候选映射：

```text
execution_started
→ cinematic_deep_low_whoosh_impact_05
```

表现目标：

- 低沉；
- 有重量；
- 带启动冲击和空间压迫感；
- 可以与短时摄像机冲击、FOV 变化或画面压暗同步；
- 不应随机 Pitch 到破坏 cinematic 节奏；
- 与最终喷血音保持足够间隔，避免两个冲击叠成一个模糊爆音。

推荐参数由实际素材试听后冻结：

- 独立 `Cinematic` 或 `Combat` 总线；
- 固定或极窄的音量变化；
- 固定 Pitch；
- 根据镜头距离选择弱空间化或非空间化；
- 可以有低频限制或总线 ducking，但不得在 Web 浏览器中造成削波。

### 4.4 处决完成和大量喷血

处决完成必须是独立 cue，不与 `execution_started` 共用时间点：

```text
execution_impact_confirmed / execution_blood_peak
→ 子弹命中身体类音效
→ 血液 VFX 峰值
→ 最终命中反馈 / 摄像机冲击
```

当前项目是否已有 `execution_impact_confirmed` 或 `execution_blood_peak` 事件，需要等动作模组接入后确认。如果没有，建议在统一的 AttackDefinition 或动画通知中增加语义事件，而不是让 `AudioEventRouter` 根据 `combat_time` 猜测。

表现目标：

- 音效应跟随最终命中和大量喷血的视觉峰值；
- 可以比普通命中更响或更宽，但不应覆盖 `cinematic_deep_low_whoosh_impact_05` 的启动识别；
- 处决结束、Boss 死亡和遭遇胜利的音乐/环境反馈应作为独立事件，不能全部堆叠在同一帧。

---

## 5. 动作绑定时间线

### 5.1 当前只登记相对 cue

动作模组尚未由主对话接入前，只登记：

```text
cue_id
触发事件
相对动作阶段
允许误差
视觉/战斗关联
```

示例：

| `cue_id` | 事件 | 相对动作阶段 | 当前状态 |
|---|---|---|---|
| `footstep_light` | `player_step` | 脚掌接触地面 | 待动作帧校准 |
| `footstep_heavy` | `boss_step` | 重足接触地面 | 待 Boss 动作校准 |
| `body_impact_light` | `hit` | 有效帧命中确认 | 待攻击时间线校准 |
| `execution_whoosh` | `execution_started` | 处决发动段起始 | 使用候选素材，待试听 |
| `execution_blood_impact` | `execution_blood_peak` | 最终命中/喷血峰值 | 待处决动作接入 |

### 5.2 动作接入后的校准顺序

主对话完成动作模组后，按以下顺序绑定：

1. 在 Godot 中确认实际动画名称、clip 数量、FPS、首尾帧和循环设置；
2. 在动作检查板中逐帧查看脚掌、武器、目标身体和血液 VFX 的相对位置；
3. 记录攻击的 `attack_id`、起手、有效、收招、处决启动和处决完成时间；
4. 优先将命中和处决 cue 绑定到统一 AttackDefinition/动画通知，而不是在音频脚本中写帧号；
5. 将 `event_id`、`combat_time` 和动画时间写入 QA 日志；
6. 试听 0.5x、1x 和 2x 播放速度，确认音频不会提前或滞后；
7. 在 30/60/120 FPS 或目标浏览器帧率下重复验证；
8. 再校准摄像机冲击、粒子峰值和 UI 反馈；
9. 锁定 cue 时间后再做最终音量、衰减和混音。

### 5.3 允许误差

第一轮校准可以用相对误差记录，不要在没有实测前写死固定毫秒数。建议记录：

- 脚步：脚掌接触可视瞬间附近；
- 普通命中：有效帧和冲击 VFX 峰值附近；
- 处决启动：动作进入发动段的同一拍；
- 处决完成：最终伤害确认和大量喷血峰值附近。

实际误差阈值由素材瞬态、动作速度和浏览器音频调度共同决定，最终以 QA 试听和录屏为准。

---

## 6. 资源变体、音量和空间化

### 6.1 变体选择

资源字典的选择维度建议为：

```text
event.type
+ actor
+ surface_id
+ impact_tier
+ quality_tier
```

例如：

```text
player_step / sand / light
boss_step / ruin_stone / heavy
hit / body / medium
execution_started / cinematic
execution_blood_peak / body / finisher
```

变体选择应支持：

- 随机但可控；
- 不连续重复同一个文件；
- 质量档位减少变体数量但不丢失事件语义；
- 对处决和剧情音效使用固定资源或窄范围选择；
- 记录最终选择的资源 ID，便于 QA 复现。

### 6.2 音量和 Pitch

建议采用“事件基础音量 + 变体微调”的方式：

- 脚步：按表面、角色体型和冲击等级调整；
- 普通命中：按轻/中/重等级调整；
- Boss 重脚步：增强低频存在感，但限制峰值；
- 处决 whoosh：固定音高和较稳定响度；
- 处决血液冲击：允许比普通命中更强，但必须检查削波和与 whoosh 的叠加。

所有最终增益以实际素材的峰值和响度为准，不能仅凭文件名判断应该加多少 dB。

### 6.3 3D 衰减

- 脚步和普通命中优先使用 3D 空间化；
- 处决启动音根据镜头距离选择弱空间化或非空间化；
- Boss 远距离重脚步可以保留低频层，但不应穿透整个场景；
- 衰减曲线、最大距离和遮挡应在 Chrome、Safari 等目标浏览器实测；
- 低档位可以减少空间化实例和并发，而不是静默所有战斗反馈。

---

## 7. 浏览器格式和导入建议

推荐保留三层文件：

```text
assets/source/audio/       原始 WAV、UE 导出物和许可记录
assets/processed/audio/    裁剪、响度、去空白和格式处理结果
assets/runtime/audio/      Godot 使用的 WAV/Ogg/MP3
```

建议：

- 短促关键音效可以先用 WAV 验证瞬态和兼容性；
- 大量脚步和环境音评估 Ogg/MP3 以降低 Web 包体；
- 保留未压缩源文件和 hash，不要只保留压缩后文件；
- 检查导入后的时长、声道、循环标志和加载方式；
- 处决启动和最终命中必须测试首载延迟，不能第一次播放才触发明显卡顿；
- 低质量档位只减少次要变体、环境层和空间实例，不移除处决核心 cue。

Godot 音频导入参考：[Importing audio samples](https://docs.godotengine.org/en/4.5/tutorials/assets_pipeline/importing_audio_samples.html)。

---

## 8. QA 清单

### 8.1 资源

- [ ] 每个音频候选有来源、原始路径、hash 和许可证记录。
- [ ] 已区分源 WAV、处理版本和运行时版本。
- [ ] 未核验许可的 Pro Sound/UE/Fab 音频没有进入公开 Web 构建。
- [ ] 采样率、声道、时长、峰值、循环和格式已记录。
- [ ] 音频导入后没有削波、首尾空白或异常速度。

### 8.2 事件

- [ ] `player_step` 和 `boss_step` 不会重复播放。
- [ ] 脚步按表面和轻/重等级选择资源。
- [ ] 普通攻击起手、挥空和有效命中没有混用同一事件。
- [ ] `hit`、`player_hit`、`boss_landed` 的实际语义已核对。
- [ ] `execution_started` 只在处决动作发动段触发。
- [ ] 处决启动 whoosh 与最终喷血冲击是两个独立 cue。
- [ ] 处决最终 cue 与血液 VFX、伤害结算和摄像机冲击时间一致。

### 8.3 动作绑定

- [ ] 动画 clip、FPS、首尾帧和 root motion 已确认。
- [ ] 动作时间线有 `attack_id` 和起手/有效/收招段。
- [ ] 具体音频绑定使用动画通知或统一 AttackDefinition，而不是散落帧号。
- [ ] 0.5x、1x、2x 播放速度下 cue 不明显提前或滞后。
- [ ] 目标浏览器帧率变化不会产生重复或漏播。
- [ ] QA 日志保留 `event_id`、`combat_time`、动画时间和资源 ID。

### 8.4 Web 运行

- [ ] Chrome、Edge、Firefox、Safari 至少试听并操作一次。
- [ ] 近距离、远距离、镜头锁定和解除锁定下空间化可接受。
- [ ] 连续脚步、连续命中和多个粒子同时触发时没有声音墙。
- [ ] 首次播放没有明显解码卡顿。
- [ ] Web High/Balanced/Low 都保留核心命中和处决反馈。
- [ ] 音频总线、音量和浏览器静音策略经过实际测试。

---

## 9. 后续实现顺序

主对话完成动作模组后，建议按以下顺序执行：

1. 先在动作检查板中确认 FBX/GLB 的真实骨架、clip 和时间线；
2. 选一套轻脚步、重脚步和身体命中候选，完成来源/许可证/hash 登记；
3. 将音频放入 `assets/source/audio/` 和 `assets/runtime/audio/` 的正式路径；
4. 在 `AudioEventRouter` 中建立资源字典和变体选择；
5. 先接 `player_step`、`boss_step` 和普通 `hit`；
6. 再接 `execution_started` 的 `cinematic_deep_low_whoosh_impact_05`；
7. 增加处决最终命中/喷血峰值事件，再接身体命中音；
8. 用动作时间线、粒子峰值和摄像机冲击做同步校准；
9. 保存浏览器试听、截图/录屏、事件日志和性能结果；
10. 最后冻结正式音频资产和质量档位。

本文件到此只完成设计和验收约定。动作模组真正落地后，再根据实际动画帧和事件实现具体绑定。
