# UE / FBX / GLB / VFX 资产迁移到 Godot Web

状态：资产迁移技术方案，面向 `Gilded Ruin Boss` 浏览器版本。

适用基线：Godot 4.7.2、`GL Compatibility`、WebGL 2.0。

关联文件：

- [项目说明](../README.zh-CN.md)
- [浏览器端渲染技术推荐](WEB-RENDERING-TECH-RECOMMENDATION.zh-CN.md)
- [资产来源台账](ASSET-LEDGER.zh-CN.md)
- [QA 清单](QA-CHECKLIST.zh-CN.md)
- [战斗音频 Cue 规划](COMBAT-AUDIO-CUE-PLAN.zh-CN.md)

---

## 1. 结论先行

`Downloads` 中的资源不是同一种格式，不能采用“全部复制到 Godot 项目”或“把扩展名改成 Godot 能识别的格式”的方式处理。

当前应分成四条迁移路径：

```text
Mixamo 风格 FBX 动作
→ Blender 验证 / 重定向 / 清理
→ GLB/glTF 或 Godot 可导入动画
→ AnimationLibrary / AnimationTree

GLB + JPEG 环境资产
→ 资产检查 / 拆分 / 减面 / UV2 / 碰撞
→ StandardMaterial3D + LightmapGI
→ Godot Web 运行时

UE .uasset / .umap / Blueprint / Niagara / UE Material
→ 合法 UE Editor 导出可交换资源
→ Godot 重建材质、粒子、场景和逻辑
→ Web 性能验收

UE SoundWave / 外部音频
→ 合法导出 WAV/PCM 或获得原始音频
→ Godot 导入 WAV/Ogg/MP3
→ AudioEventRouter 事件绑定
```

必须保持以下边界：

- `.uasset`、`.umap`、Blueprint、Niagara、UE Material Graph、SoundCue 和 AnimBP 不是 Godot 可直接导入的运行时格式；
- `.uasset` 不能通过改名成为 PNG、FBX 或 WAV；
- 资产“能够提取”不等于“允许商业使用或 Web 再分发”；
- 不绕过加密、签名、AES key、Pak/IoStore 保护或服务条款限制；
- `Downloads` 原始文件只读保留，不在原目录重命名、覆盖、删除或批量改写。

本机已发现 Unreal Engine 5.8 的编辑器、FBX/纹理/音频导出器源码以及 GLTF Exporter 插件文件，但本轮没有启动 UE、没有执行导出，也没有证明 UE 5.8 可以无修改加载当前标记为 UE 4.27 或 UE 5.0+ 的资源。实际导出前仍需验证版本、插件、依赖和许可证。

---

## 2. 资产隔离和目录约定

按照项目 README 的三层资产约定，正式接入时使用：

```text
assets/source/
├── motion/       外部 FBX、原始 GLB、原始贴图和音频
├── environment/
├── vfx/
└── audio/

assets/processed/
├── motion/       Blender 清理、重定向和导出中间文件
├── environment/ 减面、拆分、UV2、碰撞和材质整理结果
├── vfx/          Godot 重建所需的序列帧和贴图
└── audio/        裁剪、响度和格式处理结果

assets/runtime/
├── motion/       Godot 使用的 GLB、动画库或其他运行时文件
├── environment/
├── vfx/
└── audio/
```

每项资产进入 `assets/runtime/` 前，必须在 `docs/ASSET-LEDGER.zh-CN.md` 约定的台账中登记：

- `asset_id`、类别、用途和来源；
- 原始路径、运行时路径和 SHA-256；
- 导出工具、版本和处理日期；
- Blender 文件、处理步骤和导出参数；
- 面数、三角形、材质槽、纹理尺寸、动画数量和时长；
- UV2、碰撞代理、LOD 和 Web 包体积；
- 许可证、署名要求、是否允许公开 Web 再分发；
- 视觉审核、性能审核和替代版本关系。

临时签名 URL、API key、Authorization Header、私密凭据和未脱敏服务响应不得进入项目文档、运行时资源或公共仓库。

---

## 3. UE 资产的正确出口

### 3.1 优先使用有授权的 UE Editor

对于真正位于 UE 内容目录中的资源，优先在拥有合法访问权限的 UE Editor 中处理：

1. 使用与资产来源声明匹配的 UE 版本打开项目或迁移副本；
2. 确认插件、依赖材质、骨架和引用资源完整；
3. 在 Content Browser 中使用 `Asset Actions → Export`；
4. 根据资产类型选择 glTF/GLB、FBX、PNG/TGA/EXR、WAV 等交换格式；
5. 保存导出日志、工具版本、原始资产路径和 hash；
6. 导出结果先进入 `assets/source/`，通过 Blender 和 Godot 验证后才进入 `processed/` 或 `runtime/`。

Epic 的参考资料：

- [Working with Assets in Unreal Engine](https://dev.epicgames.com/documentation/unreal-engine/working-with-assets-in-unreal-engine)
- [How the glTF Exporter Handles Unreal Engine Content](https://dev.epicgames.com/documentation/unreal-engine/how-the-gltf-exporter-handles-unreal-engine-content)
- [UAnimSequenceExporterFBX](https://dev.epicgames.com/documentation/unreal-engine/API/Editor/UnrealEd/UAnimSequenceExporterFBX)
- [UTextureExporterTGA](https://dev.epicgames.com/documentation/unreal-engine/API/Editor/UnrealEd/UTextureExporterTGA)
- [USoundExporterWAV](https://dev.epicgames.com/documentation/unreal-engine/API/Editor/UnrealEd/USoundExporterWAV)

这些文档说明导出能力和 API，不替代具体资产的许可证核验，也不证明旧 UE 版本资产可以直接在本机 UE 5.8 中加载。

### 3.2 不能直接导出的情况

以下情况不应通过第三方破解或猜测格式处理：

- 只有加密或签名的 cooked 内容；
- 只有 Pak/IoStore 容器而没有授权的源项目；
- 缺少 AES key、插件或依赖资源；
- 资产条款禁止导出、编辑或 Web 再分发；
- 商品只提供 UE 内容，但实际授权条款尚未确认。

如果不能合法获得交换格式，该资产应在台账中标记为 `Blocked` 或 `Deferred`，使用 Godot 重新制作的替代资源，不要把不可用文件放进运行时目录。

---

## 4. FBX 攻击动作迁移

### 4.1 当前 Downloads 文件判断

以下动作文件被识别为 FBX 7700，并出现 `mixamo.com`、`mixamorig:Hips`、`MotionOnlyScene`、`Retargeted Clip`、`AnimationStack` 等字符串：

- `Armada To Esquiva.fbx`
- `Au.fbx`
- `Chapa 2.fbx`
- `Flying Kick.fbx`
- `Great Sword Casting.fbx`
- `Great Sword Jump Attack.fbx`
- `Great Sword Slash.fbx`
- `Jump Attack.fbx`
- `Knee Jabs To Uppercut.fbx`
- `Leg Sweep.fbx`
- `Meia Lua De Compasso.fbx`
- `Surprise Uppercut.fbx`

这说明它们更像 Mixamo 或 Mixamo 风格的重定向动作 FBX，而不是只能在 Unreal 中使用的 `.uasset` 动画资源。这是迁移上的有利条件，但仅凭文件字符串不能证明来源授权，也不能证明动作与当前玩家或 Boss 骨架兼容。

### 4.2 推荐流水线

```text
Downloads/*.fbx
→ 只读盘点、hash 和许可记录
→ assets/source/motion/
→ Blender 检查 Skeleton / Action / 帧率 / 单位 / 方向
→ 必要时重定向到目标角色骨架
→ 处理 root motion、武器握点和动作命名
→ 导出 GLB/glTF 或保留可验证的 FBX 中间文件
→ Godot 导入并检查 AnimationPlayer / AnimationLibrary
→ 建立 AttackDefinition 和动作时间线
→ 浏览器运行和性能验收
```

### 4.3 Blender 检查项

每个 FBX 必须单独记录，不允许假设所有文件结构相同：

- 场景中是否存在 `Armature` 和 `Skeleton`；
- 骨架根节点、髋骨和脚部骨骼名称；
- 是否为 `mixamorig` 命名，是否存在缺失骨骼或额外辅助骨骼；
- 实际 Action/Animation Clip 数量，不能默认取第一个片段；
- 帧率、起始帧、结束帧、时长和采样密度；
- 角色朝向、上轴、前轴和世界单位；
- 是否带 T-pose、静止帧或错误的初始姿态；
- 髋骨平移、根骨平移和脚底漂移；
- 双手武器的握点、挂点和武器方向；
- 是否包含不应导出的控制器、约束或辅助对象。

### 4.4 Root Motion 和战斗权威

动作里的根位移不能直接等同于游戏中的角色移动。每个动作需要明确选择：

- 保留 root motion，由角色移动系统消费；
- 提取水平位移并写入攻击/位移定义；
- 移除水平位移，只保留原地动作；
- 保留 `root_samples` 供调试，但由战斗和碰撞系统决定实际位移。

`Gilded Ruin Boss` 应继续保持“战斗规则与视觉动作分离”：

- 伤害、Hurtbox、武器轨迹和攻击有效窗由战斗时间线决定；
- 动画只表达视觉姿态、动作段和通知；
- 不能因为一个 FBX 看起来更重，就在动画脚本中暗中提高伤害；
- Root Motion 的处理必须在 30/60/120 FPS 或项目实际目标帧率下验证确定性。

### 4.5 重定向和 Godot 接入

如果 `mixamorig` 骨架与玩家/Boss 骨架不一致：

1. 在 Blender 中建立明确的源骨架到目标骨架映射；
2. 校正 T-pose、骨骼朝向、骨长和手脚基准；
3. 重定向后检查肩、肘、腕、髋、膝和脚踝极端姿势；
4. 检查武器握点和攻击轨迹；
5. 导出带目标骨架的 GLB/glTF；
6. 在 Godot 中检查 `AnimationPlayer`、`AnimationLibrary`、`AnimationTree` 和动画切换；
7. 再把攻击动作与 `attack_id`、起手/有效/收招窗口绑定。

不要在 `PlayerController` 或 `BossController` 中用临时骨骼名称补丁代替正式重定向。仓库旧 `sekiro-combat` 的 Blender/GLB 和逐帧动作处理脚本只能作为技术参考，不直接复制旧角色、场景或运行时资源。

Godot 参考：

- [Importing 3D scenes](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_3d_scenes/index.html)
- [Available 3D formats](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)
- [Import configuration](https://docs.godotengine.org/en/latest/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html)
- [AnimationTree](https://docs.godotengine.org/en/latest/tutorials/animation/animation_tree.html)
- [AnimationMixer root motion](https://docs.godotengine.org/en/latest/classes/class_animationmixer.html)

---

## 5. GLB 环境资产和 PBR 贴图

`fantasyenvironment.zip` 内含一个约 59 MB 的 GLB 和 JPEG 纹理，是当前 Downloads 中最适合优先验证的环境候选。它仍不能未经检查直接进入最终 Web 包。

### 5.1 检查清单

- GLB 文件大小、节点层级和外部/嵌入纹理情况；
- 总三角形、子网格、材质槽和重复材质数量；
- 是否可以拆分为近景、中景、远景和不可见背面；
- Base Color、Normal、ORM 文件名与实际通道是否一致；
- Base Color 是否按 sRGB 导入；Normal、Roughness、Metallic、AO 是否按线性数据处理；
- 法线方向、切线、UV1 和 UV2/lightmap UV；
- 世界尺度、碰撞代理、LOD 和实例化方式；
- 2K/1K/图集降级后是否仍保留材质区分；
- 资产是否可以在项目的中性材质和 WebRenderLab 场景中通过校准；
- 来源、服务条款和 Web 再分发权是否已登记。

### 5.2 Godot 接入建议

优先使用 GLB/glTF + `StandardMaterial3D`。不要为了快速看到模型而把全部贴图接入自定义 Shader。正式场景应按以下顺序处理：

1. 导入 GLB 并检查模型、材质和动画资源；
2. 在 Blender 或 Godot 中拆分过大的一体化场景；
3. 清理不可见面、生成碰撞代理和 LOD；
4. 生成或修正 UV2；
5. 核对 ORM 通道，不假设文件名就代表 Godot 所需顺序；
6. 用中性灯光检查 PBR，再加入项目冷色主光、暖色局部光、LightmapGI、SSAO、ReflectionProbe 和雾；
7. 记录导入体积和真实浏览器性能。

Godot Web 只能以 Compatibility/WebGL2 为基线。具体材质、光照和质量档位遵循 [WEB-RENDERING-TECH-RECOMMENDATION.zh-CN.md](WEB-RENDERING-TECH-RECOMMENDATION.zh-CN.md)。

---

## 6. UE VFX 到 Godot 的替代路径

### 6.1 Transformation VFX Pack

当前包主要包含 UE `.uasset`、`.umap`、Blueprint、材质、角色骨骼、动画、Rig 和纹理资源。

不能直接迁移的部分：

- Blueprint 图和组件逻辑；
- Niagara 系统、Emitter、Module 和参数曲线；
- UE Material、Material Function 和 Material Instance；
- UE 场景、Demo Mannequin、AnimBP、Notify 和 Rig；
- 依赖特定 UE 插件或引擎版本的引用关系。

可以作为 Godot 输入的部分，必须先经合法导出并单独登记：

- PNG/TGA/EXR 等纹理；
- GLB/glTF 或 FBX 网格；
- 序列帧或烘焙后的贴图；
- WAV/Ogg/MP3 音频；
- 手工重建所需的粒子参数和截图参考。

### 6.2 Realistic Blood VFX

Niagara 血液/子弹命中特效不能直接复制到 Godot。建议先拆解为一份效果规格：

- 发射器类型和初始粒子数量；
- 粒子朝向、冲击法线和速度范围；
- 生命周期、重力、阻力和碰撞；
- 大小、旋转、颜色和透明度曲线；
- flipbook/序列帧的帧数、布局和播放速度；
- 粒子是否需要拖尾、贴地或粘附；
- 是否需要屏幕空间冲击、Decal 或短时闪光。

在 Godot 中按成本从低到高选择：

1. `GPUParticles3D` + Quad/Sprite3D；
2. 序列帧材质或 `AnimatedTexture`；
3. 小型 Decal/贴地血迹；
4. 轻量 Spatial Shader；
5. 只有在 Web 基准允许时才增加额外透明层和扭曲。

必须控制透明 Overdraw、粒子总数、纹理尺寸、Shader 采样和屏幕覆盖面积，并为 Web High/Balanced/Low 提供降级：低档位优先保留命中方向、颜色和短时冲击，不保留所有粒子细节。

### 6.3 UE 材质和高级特性

UE Material Graph 不会自动变成 Godot `ShaderMaterial`。Nanite、虚拟纹理、Lumen、体积雾和 Forward+/专用后处理也不能作为浏览器基线。可迁移的做法是：

- 烘焙到 Base Color、Normal、Roughness、Emission 或序列帧；
- 用 `StandardMaterial3D` 重建主要 PBR；
- 只为明确视觉收益编写轻量 Spatial Shader；
- 提供 StandardMaterial3D 或低采样版本回退；
- 通过真实浏览器而非编辑器截图决定是否保留效果。

---

## 7. 音频资产迁移边界

独立音频或合法导出的 UE `SoundWave` 应走：

```text
原始音频 / SoundWave
→ WAV/PCM 导出并保留原始 hash
→ 裁剪、响度和首尾检查
→ Ogg/MP3 Web 版本（如需要）
→ assets/runtime/audio/
→ AudioEventRouter 事件映射
```

需要在 Godot 中重建的 UE 音频逻辑包括：

- SoundCue 的随机节点和权重；
- MetaSound 图；
- Submix、Concurrency 和 Attenuation；
- UE Notify 中的动作触发；
- 3D 空间化、播放器池、总线和混音。

`ProSoundCollection` 的内层大压缩包本轮未解压。即使后续能够提取 WAV，也必须先确认原包许可、允许编辑范围和 Web 再分发条件。未核验的资源只能保持 `Pending/Deferred`，不得进入公开构建。

---

## 8. 资产迁移验收

### 8.1 动作

- [ ] 每个 FBX 都有原始路径、hash、来源和许可记录。
- [ ] 实际动画 clip 数量、帧率、首尾帧和时长已记录。
- [ ] 骨架、目标骨架映射、重定向和 root motion 决策已记录。
- [ ] 武器握点、方向、攻击轨迹和脚底接触通过动作检查。
- [ ] Godot 中动画库可加载，切换不会报错。
- [ ] 战斗时间线与动画表现分离，攻击有效窗可复现。

### 8.2 环境与 VFX

- [ ] GLB 面数、材质槽、纹理尺寸、UV2 和碰撞代理已记录。
- [ ] Base Color、Normal、ORM 的色彩空间和通道已核对。
- [ ] 静态场景可以进入 LightmapGI 流程。
- [ ] VFX 有 Godot 重建规格，而不是依赖 `.uasset` 运行。
- [ ] 透明 Overdraw、粒子数量、Shader 采样和包体积已采样。
- [ ] Web High/Balanced/Low 均有可接受的回退路径。

### 8.3 Web 和授权

- [ ] Godot headless 导入无错误或已记录可接受警告。
- [ ] Chrome、Edge、Firefox、Safari 至少完成一次启动和操作。
- [ ] 真实浏览器记录 FPS、GPU 帧时间、Draw Call、三角形、纹理内存和加载时间。
- [ ] 原始、处理、运行时文件和 hash 可以互相追溯。
- [ ] 许可证、署名和公开 Web 再分发状态已明确。
- [ ] 不能公开发布的资产已被替换、隔离或标记为阻塞。

---

## 9. 本轮不做

- 不移动、删除、覆盖或批量改写 Downloads 原件；
- 不把 UE `.uasset`/`.umap` 直接复制到 Godot 运行时；
- 不启动 UE 进行未经确认的旧版本资产转换；
- 不解压约 1.79 GB 的 Pro Sound 内层归档；
- 不修改 `project.godot`、战斗脚本、场景或音频路由代码；
- 不将“可导出”“可播放”或“免费获得”解释为已获得 Web 再分发许可。

这份文档只定义迁移边界和执行顺序。等主对话完成动作模组接入后，再按动作实际骨架、clip、root motion 和动画时间线执行转换与音频绑定。
