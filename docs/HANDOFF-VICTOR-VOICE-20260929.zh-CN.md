# 给主对话的音效开发交接：Victor 配音、字幕与战斗音效边界

更新日期：2026-09-29。共享开发目录：`/Users/yangjianwen/Documents/aistudio/Gamebench/projects/gilded-ruin-boss`。

本次用户在侧对话明确要求实际生成并接入六句台词，指定 **Victor - Deep, Malevolent and Ancient**。已修改共享源工程并更新本地 Web 入口；未推送 GitHub，未改发布副本。

## 主对话先看这几条

1. **六句 Victor 配音和中文字幕已经实装**，不需要从实验目录搬运，也不需要再次生成。
2. 当前正式 Web 构建是 **voice-victor-20260929**，基于已确认的 V11 输入方案和胜后移动修复；不是退回早期战斗版本。
3. **V12.2 战斗音效看板是另一条开发线**，当前有 64 个新音效候选和 22 个旧素材对照。看板里的候选、实时推子和新增重岩崩裂层尚未复制进正式游戏。不要把“Victor 已实装”理解为“所有 ElevenLabs 音效已实装”。
4. 用户已经确认台词、音色和字幕样式方向，但尚未对生成结果的最终情绪、响度和实战混音做主观试听验收。客观测试通过不代表这一步已完成。
5. 原开发目录目前没有 `.git`。GitHub 发布副本 `/tmp/gilded-ruin-publish-20260928` 本轮未动；后续发布应从共享开发目录同步最新快照，不能从旧发布副本反向覆盖。
6. 本轮只接入声音和字幕，没有更改 Boss 出招、命中、生命值、输入、角色模型或场景。

## 试玩

- 最新入口：<http://127.0.0.1:8093/?build=voice-victor>
- 固定版本：<http://127.0.0.1:8093/index-voice-victor.html>
- 直接过场：<http://127.0.0.1:8093/index-voice-victor.html?crown-intro=1>，播放完成后 R 重播、P 开战。浏览器需要首次键鼠交互才能可靠启用声音。
- 版本标识 `voice-victor-20260929`；`builds/web/build-info.json` 记录包校验值和上一版信息。
- 本次 PCK SHA-256：`f30b4923125f74d179f14323dfafa43ba19ce9210d43f780ca32b48734bde414`。
- `?build=...` 仅用于标记链接，不是服务端版本切换。固定历史版本请使用对应 HTML 入口，不能只更换查询参数。

## 已实现

采用英文配音、中文字幕。全部使用 ElevenLabs 官方接口实际返回的指定 Victor 声音，voice ID `cPoqAvGWCPfCfyPMwe4z`，模型 `eleven_v3`。六句都是用户确认的原台词，表演提示分别为低沉审视、威胁、愤怒、命令、冷漠和疲惫释然。

| 事件 | 中文台词 | 触发规则 |
| --- | --- | --- |
| 冠冕化沙 | 又一双手，想接住这顶冠。 | 过场 0.55 秒开始，语音约 4.1 秒 |
| 实际起身 | 先让我看看……它们能承受多少。 | 过场结束、进入 Warden_Rise 时播放，约 4.5 秒 |
| 随机重击 | 让这战争……教你臣服！ | 独立 RNG 在前 1～3 次伤害不低于 30 的招式里选一个起手时机；如频道忙则等下一个重击；每场最多一次 |
| 怒吼 | 跪下！连死者都未曾获准起身！ | 第一次真实进入 roar 动作时播放，每场最多一次；优先于普通战斗喊话 |
| 玩家死亡 | 又一位觊觎王冠的人……终于俯首。 | 致命命中后 0.65 秒播放，替换旧胜利怪笑 |
| Boss 被击败 | 若你见到他们……就说，可以回家了。 | win() 后 0.65 秒播放，伴随后续消散与胜利 UI |

对应英文原文如下，正式录音只朗读英文，表演标签不属于台词或字幕：

| ID / 文件名 | 英文 | 对齐记录中的语音结束时间 |
| --- | --- | --- |
| `crown` | Another pair of hands, reaching for the crown. | 4.080 秒 |
| `challenge` | First, let me see… how much they can bear. | 4.485 秒 |
| `heavy` | Let this war… teach you obeisance. | 3.920 秒 |
| `roar` | Kneel! Even the dead have not been granted leave to rise! | 6.885 秒 |
| `player_fallen` | Another claimant to the crown… bows at last. | 5.440 秒 |
| `warden_fallen` | Should you find them… tell them they may go home. | 5.446 秒 |

表中时间来自 API 字符对齐，不等于 MP3 容器的精确时长，也不用于硬截音频。运行时以真实播放完成信号结束台词。

字幕为独立 CanvasLayer 95，不受过场隐藏 HUDRoot 的影响。位置在 Boss 血条下方，屏幕高度 92.3%～96.8%；灰白宋体、细轮廓与阴影，无额外字幕框，使用完整覆盖这六句话的 95 字符 Noto Serif SC 子集。字号随宽高较小缩放系数适应窗口。

语音由 AudioStreamPlayer 播放，无距离衰减或随机音高。播放中音乐与环境声平滑降低 9 dB，结束后平滑恢复。Boss 原有吼叫、发力、受击人声在台词期间避让，兵器与裂地效果仍保留。短语音全部明确禁用循环。声音与字幕不受命中顿帧影响；失焦时一起暂停。语音结束由真实 finished 信号清理，字幕再淡出 0.35 秒。

跳过或中断过场会清掉冠冕台词，实际起身仍播放挑战句。重开清理活动语音、待播放语音、字幕及每场次数；胜负台词能打断战中句子并阻止新战斗台词插入。独立语音 RNG 不影响 Boss 既有出招序列。未改输入、伤害、生命值、动作、消散时间或胜后可移动逻辑。

“每场一次”在录音实际开始时记账。若重击句被怒吼或胜负台词打断，本场不再重播；重击次数不足或一直没有空闲频道时，该场可能不触发重击句。第二次及之后的怒吼保留原怪物吼声，但仍须避让正在播放的台词。没有用延长攻击动作的方式等待一句话说完。

## 文件

- `scripts/presentation/warden_dialogue.gd`：语音、字幕、次数和优先级。
- `assets/runtime/dialogue/warden-victor.json`：中英文台词、表演提示、音频路径。
- `assets/runtime/audio/voice-victor/*.mp3`：六句实录生成资产，共约 0.49 MB。
- `assets/runtime/fonts/WardenDialogueSerifSC.ttf`：独立字幕字体；OFL 许可沿用字体目录内文件。
- `scripts/presentation/battle_audio.gd`：音乐避让、旧 Boss 人声避让。
- `scripts/battle/playable_encounter.gd`、`battle_actor.gd`、`scripts/cinematic/crown_intro.gd`：最少事件接入点。
- `tools/audio/generate_warden_voice.py`：可恢复生成脚本，隐藏输入凭据或读取 ELEVENLABS_API_KEY，不自动重试收费请求。
- `tools/audio/verify_warden_voice.py`：Scribe v2 转写核对。
- `generation-records/voice-victor/`：请求参数、字符对齐、转写结果；不进入 Web 导出。

用户提供的 API key 仅传入本轮进程内存，没有存入 .env、源码、生成记录或 Web 包。下次生成需重新提供环境变量或隐藏输入。运行时完全离线播放，无需用户持有 API key。

## 音频生成与复现

生成脚本复用项目现有 ElevenLabs 官方调用方式，先核对音色详情和可用 TTS 模型，再逐条生成。请求端点是 `POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/with-timestamps?output_format=mp3_44100_128`，鉴权头为 `xi-api-key`。

- `model_id=eleven_v3`，`language_code=en`。
- `stability=0.5`、`similarity_boost=0.78`、`speed=0.94`。
- 六句各有表演标签，完整提示保存在台词 JSON 的 `performance` 中；中文表演说明在 `direction` 中。
- seed 从 `929013` 按台词顺序递增；seed 不是跨服务版本逐字节可复现的承诺。
- 格式为 MP3 44.1kHz / 128kbps，六个文件共 **490,945 字节**。
- 六次 TTS 成功请求返回的 `character-cost` 合计 **160**；这是接口记录值，不是货币金额，亦不含另外六次 Scribe 转写的计费。
- 本次没有额外归一化或改变录音音高；保留原始文件，运行时统一增益 −2 dB。

如需生成新的台词版本，在终端进入共享开发目录后使用：

```sh
cd /Users/yangjianwen/Documents/aistudio/Gamebench/projects/gilded-ruin-boss
python3 tools/audio/generate_warden_voice.py
python3 tools/audio/verify_warden_voice.py
```

两个命令会读取已有 `ELEVENLABS_API_KEY` 环境变量；未设置时使用隐藏输入。不要把密钥直接写进命令行、交接文档或网页。

**现有脚本会跳过“音频和生成记录都已存在”的条目，不会因为改了提示词就自动重做。** 需要修改某句时，先保存该句现有音频与同名生成记录的版本副本，再有针对性地生成；转写脚本也会复用已有 `*-transcript.json`，换音频后必须更新对应转写记录，不能拿旧转写证明新音频正确。生成请求失败或结果不明时，先核对已有文件和服务记录，脚本没有自动重试收费请求。

改动中文字幕后，需要重新扩展 `WardenDialogueSerifSC.ttf` 字库；完整源字体在 `tools/cache/NotoSerifSC.ttf`，fontTools 环境在 `tools/font-venv/`。不必改动原有 HUD 字体。

## 与现有正式音效、V12.2 看板的边界

以下状态依据交接时读取到的代码和独立看板 README；V12.2 的素材制作和测试不属于本侧对话的执行成果。

| 声音部分 | 当前正式游戏状态 | 后续注意事项 |
| --- | --- | --- |
| Victor 六句台词 | 已实装 | 保留单频道、每场限制、重开清理和音乐避让 |
| 玩家/Boss 脚步声 | 仍禁用 | `BattleAudio.cue()` 对四个脚步 ID 直接返回，不要把恢复脚步声当作本轮要求 |
| 战斗 BGM | 仍为 `v10/final_battle.ogg` | 原基础增益 −3 dB；语音期间额外压低 9 dB |
| 战前氛围 | 仍为 `v10/prebattle_earthquake.ogg` | 素材已预处理到原振幅 1.3 倍；运行时基础增益 0 dB，勿再叠一次 30% |
| 正式裂地声 | 仍为 Rock Drop A01/A02 首段，随机选择 | `fracture()` 仅处理 `fissure` / `eruption`，前戳按特效延迟触发 |
| 进场、死亡、胜利播报冲击声 | 保留 `v06/announcement.wav` | 每个事件每场一次，与台词是不同声层 |
| 玩家死亡刀剑落地声 | 保留现有一次性处理 | `player_death` 计数防重复，WAV/OGG one-shot 禁止素材元数据循环 |
| V12.2 新战斗音效 | 仍只在独立看板 | 不自动全量替换正式 SFX；依用户审阅结果合入 |

独立看板目录：`/Users/yangjianwen/Documents/aistudio/Gamebench/experiments/gilded-ruin-audio-v12-20260929`。
入口：<http://127.0.0.1:8795/>。详情见该目录下 `README.zh-CN.md`。

读取到的最新状态是 **V12.2**：26 个动作，64 个新候选，22 个旧素材，合计 86 个素材。V12.1 将 B 版砂石层默认降为原振幅 50%（−6.0206 dB），并支持独立实时推子；V12.2 新增四个重岩崩裂候选，仅用于四个裂地动作，前戳仍保留 850ms 延迟。浏览器审阅可导出 `warden-audio-review-v12.json`。本轮没有修改该看板、读取或代替用户作出素材选择。

该 README 中较早的“正式版是 input-v11”描述已落后于当前 `builds/web/build-info.json`；不能据此回退正式入口。看板的 `game-source/` 是独立动作预览副本，也不能反向覆盖现在的正式战斗工程。

后续合入战斗音效时仍需保留：空挥必有破空声；命中才有血肉/碰撞层；零伤害推开和战吼没有血肉层；裂地声对齐地面特效事件，而不是一律提前到招式起手。看板没有复现正式游戏的 BGM、3D 距离衰减和台词避让，实装后要重新核对整场混音。

## 验证

- 语音专项 **50 项**：六个资源、全部中文字符、真实播放结束、真实事件、随机重击、每场限制、音乐避让、跳过、失焦、死亡和重开清理。
- 既有冠冕/生命/BGM **44 项**、输入 **19 项**、胜后移动 **21 项**、裂地音频 **43 项**，全部通过。
- 六条 Scribe v2 转写与用户英文逐词一致；未读出表演提示。
- 原始音频响度约 −21.5～−17.5 LUFS，保留轻声与怒吼差异；运行时增益 −2 dB，最高单条语音真峰值约 −2.69 dBFS。未把该数值冒充全游戏混音峰值。
- 五张原生截图目视检查通过，覆盖冠冕、起身、怒吼、胜利、死亡字幕；浏览器实际起身字幕可见，过场自然播放及重播正常，检查时控制台无错误或警告。
- 证据：`qa/dialogue-victor-20260929/`，含测试日志、五张 PNG、音频电平记录、导出日志和修改前的少量文件备份。

以上共 **177 项 Godot 检查**，另有六条音频的逐词转写核对。本轮没有重跑 V12.2 看板的音频测试，不能把另一条开发线的测试数量累计进这里。

本轮对应测试脚本：

| 脚本 | 项数 |
| --- | --- |
| `tests/warden_dialogue_test.gd` | 50 |
| `tests/crown_intro_test.gd` | 44 |
| `tests/player_input_v11_test.gd` | 19 |
| `tests/post_victory_movement_test.gd` | 21 |
| `tests/ground_audio_update_test.gd` | 43 |

复现专项验证和截图：

```sh
cd /Users/yangjianwen/Documents/aistudio/Gamebench/projects/gilded-ruin-boss

../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot \
  --headless --path . --script tests/warden_dialogue_test.gd

# 目视检查必须使用真实渲染，不能加 --headless。
../sekiro-combat/tools/godot/Godot.app/Contents/MacOS/Godot \
  --path . --resolution 1280x720 --script tests/warden_dialogue_review.gd
```

浏览器检查已覆盖正式出生画面、冠冕过场自然结束及重播、实际起身字幕；其他事件的覆盖证据来自原生渲染与事件测试，未声称在浏览器中完整打通一场战斗并逐项人工听审。

英文录音和中文字幕目前是一句对应一行，没有逐词高亮、双语同时显示或口型驱动。用户尚未对 Victor 六句的最终情绪和混音做主观试听确认。

## 回退与后续

`qa/dialogue-victor-20260929/before/` 保存本轮修改前的四个脚本与主页/构建信息。上一版 Web 的 `index-input-v11-victory.*` 资源仍在。回退源代码时先比较其他线程后续改动，不能整文件覆盖；只要保留本轮事件接入和新资产，下次从共享源工程导出便会包含配音。

建议主对话下一步：

1. 先用最新入口试听 Victor 配音与 BGM 的关系，确认语速、怒吼强度、临终情绪及字幕字号。按用户反馈修改具体台词，不必重生成整套。
2. 继续独立看板的战斗 SFX 审阅；取得实际审阅 JSON 后再按选定的动作和声层接入正式游戏，保留本轮台词优先级。
3. 音频或源代码变更后重新导入并导出 Web，用新的资源版本名避免浏览器缓存。仅修改源码不会更新正在运行的 PCK。
4. 更新 `builds/web/index.html` 指向新包时，一并更新 `build-info.json`，先确认没有覆盖其他线程刚产出的主页；保留当前固定入口便于比较。

本次 Web 导出使用项目现有 Web preset，文件名为 `builds/web/index-voice-victor.html`；没有修改 Godot 版本或导出 preset。

官方资料：[Victor 音色](https://elevenlabs.io/app/voice-library?voiceId=cPoqAvGWCPfCfyPMwe4z)、[TTS 与时间对齐](https://elevenlabs.io/docs/api-reference/text-to-speech/convert-with-timestamps)、[语音转写](https://elevenlabs.io/docs/api-reference/speech-to-text/convert)。
