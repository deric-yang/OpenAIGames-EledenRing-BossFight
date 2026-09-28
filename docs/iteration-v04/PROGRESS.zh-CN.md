# V04 持续开发记录（中间过程存档）

**以下是早期管线搭建时的过程记录，已由 [V04 可玩版本说明](PLAYABLE.zh-CN.md) 取代。** 角色、动作、场景、指定 VFX/SFX、完整 Blender 文件和 Web 构建均已接入。70 项可玩回归、15 项 UI 检查、8 项 Tripo 管线检查以及 V04 自由巡览/连击重置检查已通过。浏览器已验证移动、翻滚、挥空、实际命中扣血、音效触发、死亡与重开，资产页已验证 12 / 38 个角色动作选项。以下“未完成”清单仅代表写入时的历史状态。

## 用户最新决定

Boss 改为羽饰老将＋带柔性旗布的战旗长枪，替代 V03 巨剑。玩家银灰甲、深灰披风、腰部羽饰和纹章，直剑按参考。黄金树保留。地形增加起伏、地面消除重复、残骸分散、魂幡接地透明。交付目标是完整可编辑 Blender 拼装和浏览器可玩切片，含所选动作、限定特效和具体音效；数值平衡后置。

## 已落地

- 内置 imagegen 生成四张独立建模参考，保存 docs/concepts/v04；对应玩家、老将、直剑、旗枪刚性部分。旗布独立建模与绑骨，避免刚性旗布。
- Tripo 四件源模型成功，人物 rig-check 通过，Mixamo 命名自动绑定成功。生成 4×60＝240，绑骨 2×25＝50 积分。具体任务记录 generation-records/production-v01。
- prepare_characters_v04.py 保留原件、减面、缩图，输出 general.glb 55000 三角面 / knight.glb 31999，2K 贴图；零未绑定顶点。源码 .blend 在 assets/processed/*_rigged/optimized.blend。
- 修复 Blender GLTF 自动生成的骨骼显示辅助 Icosphere 被纳入尺寸/减面的陷阱；导出前移除辅助体。减面放到 Armature modifier 之前。
- selected-motions.json：共享池当前评价中 37 条 keep＋1 条有明确怒吼备注 pending。合计38条，均有已转换GLB。保持用户原始评价不改。
- extract_motion_drivers.gd：删除源角色可见网格与未选动画，保留49个所需片段（38 CombatMaster＋11 Sekiro玩家片段）。资源 assets/runtime/motions/v04。玩家移动实际源名称 Walk_Loop / Jog_Fwd_Loop / Sprint_Loop。
- duel_avatar.gd：UE/UAL/Mixamo骨语义映射、参考姿势校正、保留目标骨长、髋骨高度缩放、移除水平根平移、切片混合。Godot真实窗口已渲染老将怒吼，qa/characters-v04/general-roar.png。AnimationPlayer 必须 active=true 且 manual callback；false 会使 seek 不更新骨姿态。
- collect_audio.mjs：18类事件、23个用户明确指定音效全部找到并复制，assets/runtime/audio/v04/manifest.json 保存原始名称与来源。尚未接入实战。
- assembly_sand.gdshader 改为多尺度世界坐标噪声与域扭曲，局部微弱风纹，不再连续规则条纹。尚未完成场景视觉验收。

## 接下来必须完成（未完成，不宣称可玩）

1. 骑士/老将更多动作形变检查，披风权重和二级运动，武器运行版与手部挂点。
2. 柔性旗布带骨骼和风动，地形 V04、分散残骸与接地魂幡，兼容Web的薄雾/光束。
3. 新可玩入口和控制器、三连/翻滚/起身/受击/死亡/处决；Boss所选动作和备注逻辑。
4. 限定 BloodBurst/BloodSplash/NS Basic SKM 的游戏版适配（现有库地面y=0，SKM默认审阅人偶，需要替换为实际角色，不能直接套替身）。挥舞音效总播放，血液仅命中触发。
5. 完整可编辑可移动 Blender 场景和角色骨架/动画；浏览器导出实测，视觉QA和限制记录。

## 技术依据

Godot Compatibility 不支持原生体积雾；使用兼容薄雾层与光束近似，不能宣称原生体积光。
https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html
Tripo rig-check 与 rig 文档已核实，双足默认 v1.0-20240301，mixamo spec。
https://developers.tripo3d.ai/en/docs/animations-rig
