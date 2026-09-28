# 浏览器端 Godot 渲染技术推荐

状态：技术方案草案，面向 `Gilded Ruin Boss` 浏览器版本。

适用版本：Godot 4.7.2，`GL Compatibility`，WebGL 2.0。

关联文件：

- [项目配置](../project.godot)
- [美术方向](ART-DIRECTION.zh-CN.md)
- [范围与不做清单](SCOPE.zh-CN.md)
- [QA 清单](QA-CHECKLIST.zh-CN.md)
- [资产来源台账](ASSET-LEDGER.zh-CN.md)

---

## 1. 结论先行

浏览器版不能以 Godot Forward+ 作为基础。Godot Web 导出使用 Compatibility Renderer，因此本项目的画质路线应为：

```text
Tripo 高质量 PBR 资产
+ StandardMaterial3D
+ LightmapGI 静态间接光
+ SSAO 与 AO 贴图
+ 有限的动态灯光和阴影
+ ReflectionProbe 环境反射
+ 深度雾 / 高度雾
+ Glow
+ 少量自定义材质或全屏 Shader
```

不应把下面这些桌面 Forward+ 能力作为 Web 基线依赖：

- SDFGI；
- VoxelGI；
- SSIL；
- Volumetric Fog；
- TAA；
- 依赖 Forward+ 的高级 CompositorEffect。

这并不意味着浏览器版只能做低画质。这个项目是单场景、单 Boss、有限可见范围的战斗切片，适合通过烘焙光照、控制灯光数量、精心安排材质和后处理来获得稳定的暗黑奇幻氛围。

> 重要：画面中所谓“Shader 效果”不是一个统一的大 Shader。材质、灯光、阴影、GI、Environment、CameraAttributes 和全屏后处理应分别设计和验收。

---

## 2. 浏览器端的渲染边界

### 2.1 当前工程基线

`project.godot` 已设置：

- Godot 4.7；
- `GL Compatibility`；
- WebGL 2.0 目标；
- 1280×720 视口；
- 3D MSAA 已启用。

该基线应保持不变。不要为了获得某个桌面特效而把项目切换到 Forward+，再假设之后可以正常导出 Web。

### 2.2 Web 可用能力

| 能力 | Web 基线建议 | 说明 |
|---|---|---|
| PBR 材质 | 使用 | 以 `StandardMaterial3D` 为主 |
| 动态灯光 | 使用，但限量 | 主要服务于火盆、角色和战斗反馈 |
| 阴影 | 使用，但限量 | 主方向光和少量关键局部光投影 |
| LightmapGI | 使用 | 静态场景的主要间接光来源 |
| SSAO | 使用 | 适度强化接触关系，避免过黑 |
| ReflectionProbe | 使用 | 为铠甲、湿地面提供稳定环境反射 |
| 深度雾 / 高度雾 | 使用 | 代替体积雾的大部分空间氛围 |
| Glow | 使用 | 只给火焰、武器和受控发光材质 |
| 景深 | 谨慎使用 | 优先用于 Photo Mode、过场和拍照 |
| 自定义 Spatial Shader | 使用，但保持轻量 | 只解决 StandardMaterial3D 无法解决的问题 |
| 全屏后处理 Shader | 使用，但控制数量 | 暗角、颜色调整、局部滤镜可采用 |

### 2.3 不可依赖的能力

| 能力 | 处理方式 |
|---|---|
| SDFGI / VoxelGI | 不使用；用 LightmapGI、AO、ReflectionProbe 和动态灯光替代 |
| SSIL | 不使用；用 SSAO、AO 贴图和 LightmapGI 替代 |
| 体积雾 | 不使用为硬依赖；用深度/高度雾、粒子和雾片模拟 |
| TAA | 不作为 Web 方案依赖；保留 MSAA，必要时使用轻量 FXAA/自定义方案 |
| 高数量带阴影局部光 | 不使用；只保留可见且有表现收益的关键光 |
| 每帧更新的高质量反射 | 不使用；优先烘焙或低频更新 ReflectionProbe |

---

## 3. “Shader”在本项目中的正确拆分

### 3.1 材质层：`StandardMaterial3D`

负责：

- Base Color；
- Metallic；
- Roughness；
- Normal Map；
- AO；
- Emission；
- 透明和剔除；
- 基础 Fresnel、Clearcoat 等材质属性。

Tripo 资产接入后，默认先使用 `StandardMaterial3D`。不能因为画面需要反射、金属和高光，就马上把所有材质改成 `ShaderMaterial`。

### 3.2 自定义物体 Shader：`ShaderMaterial`

只在以下情况使用：

- 铠甲边缘需要受控 Fresnel 轮廓光；
- 湿地面需要额外的局部反射混合；
- 石墙或地面需要大尺度色差和 Detail Normal 混合；
- 火焰、魔法、剑光需要特殊发光、溶解或扭曲；
- 需要浏览器版专用的轻量材质降级。

每个自定义 Shader 都要有：

- 使用目的；
- 输入纹理和参数说明；
- 适用对象数量；
- Web High / Balanced / Low 的开关或降级方式；
- 与 StandardMaterial3D 版本的对照截图。

### 3.3 场景和光照层

以下内容不应被误称为“材质 Shader”：

- `WorldEnvironment`：环境光、雾、Glow、色调映射、颜色调整和 SSAO；
- `CameraAttributes`：曝光和景深；
- `DirectionalLight3D`、`OmniLight3D`、`SpotLight3D`：直接光；
- `LightmapGI`：静态间接光；
- `ReflectionProbe`：环境反射；
- 阴影图、PSSM、Shadow Atlas：渲染器的阴影资源；
- 粒子、雾片和半透明网格：局部氛围表现。

因此，整体画面质量的研究重点应是“整套渲染配置和资产规范”，而不是单独写一个万能 Shader。

---

## 4. Tripo PBR 资产接入规范

### 4.1 纹理色彩空间

| 纹理 | 导入原则 |
|---|---|
| Base Color / Albedo | sRGB |
| Emission Color | 按 Godot 材质颜色流程处理 |
| Normal | 非颜色数据 |
| Roughness | 线性数据 |
| Metallic | 线性数据 |
| AO | 线性数据 |
|

如果把 Roughness、Metallic 或 Normal 按颜色纹理导入，铠甲会出现塑料感、粗糙度反应异常或法线细节错误。

### 4.2 ORM 通道

Tripo 或后处理工具可能将 AO、Roughness、Metallic 打包成一张 ORM 纹理，但通道顺序必须通过实际文件确认，不能假设所有工具都使用同一种约定。

接入检查至少包括：

- Godot 材质中每个通道的映射是否正确；
- Metallic 是否只出现在金属部件；
- Roughness 是否有合理范围，而不是整张图接近 0 或 1；
- AO 是否被重复乘算；
- Normal 的 Y 通道方向是否正确；
- 贴图压缩后是否产生明显块状伪影。

### 4.3 UV、尺度和几何

正式模型导入前必须检查：

- 世界单位是否以米为基准；
- 角色高度、Boss 高度和武器长度是否统一；
- 法线和切线是否正确；
- 是否有可用于 LightmapGI 的 UV2；
- 静态模块是否可以合并或实例化；
- 远景和重复墙体是否需要 LOD 或简化网格；
- 碰撞网格是否与视觉网格分离。

LightmapGI 对静态场景尤其依赖合理的 UV2。没有正确 UV2 的模型不能直接进入最终烘焙流程。

### 4.4 材质分区建议

不要把整套资产统一处理成“高金属、高光泽”。建议至少区分：

- 抛光或磨损黑铁；
- 生锈金属；
- 皮革；
- 石墙和石板；
- 木头；
- 湿地面；
- 蜡烛和火焰；
- 魔法或 Boss 发光部件。

金属度和粗糙度的差异应当服务于形体识别，而不是单纯追求高亮反射。

---

## 5. 推荐的场景渲染结构

建议建立一个独立的 `WebRenderLab` 场景，先验证渲染，再接入完整 Boss 战场：

```text
WebRenderLab
├── WorldEnvironment
├── Camera3D
│   └── CameraAttributesPractical
├── DirectionalLight3D_Moon
├── OmniLight3D_Torch_01
├── OmniLight3D_Torch_02
├── LightmapGI
├── ReflectionProbe_Arena
├── ReflectionProbe_Character
├── StaticArenaGeometry
├── MaterialCalibrationObjects
│   ├── MetalSphere
│   ├── RoughMetalSphere
│   ├── StoneSphere
│   ├── LeatherSphere
│   └── WetFloorPatch
└── Atmosphere
    ├── FireParticles
    ├── AshParticles
    └── FogCards
```

校准场景必须同时包含：

- 中性灰材质；
- 黑铁和亮铁；
- 粗糙石材；
- 皮革；
- 湿地面；
- 一个带骨骼动画的角色；
- 一个火盆或发光物体。

没有中性材质检查时，很容易把“全场染红”误认为美术风格已经成立。

---

## 6. 灯光设计

项目当前美术方向是血红、暗紫环境，冷色阴影和受控暖色发光。建议把灯光分为三层。

### 6.1 冷色主方向光

使用一个 `DirectionalLight3D` 模拟月光或高处环境主光：

- 从侧后方或侧上方照亮角色；
- 让黑色铠甲获得可读轮廓；
- 保持石墙和金属之间的材质差异；
- 不要把环境光强度开到足以抹平阴影。

方向光的旋转比位置重要。`Shadow Max Distance` 应覆盖玩家、Boss 和主要战斗区域，不要为了照亮无关远景而无限拉远。

### 6.2 暖色局部光

火盆、蜡烛和湿沙反光区可以使用暖色 `OmniLight3D` 或 `SpotLight3D`：

- 只有重点火盆投射阴影；
- 普通蜡烛可只提供亮度和颜色，不投射动态阴影；
- 局部光需要有范围衰减，避免整张地图被染成橙色；
- 火焰的外观由 Emission/粒子负责，真实灯光负责照亮地面和角色。

### 6.3 轮廓光

优先用真实方向光形成轮廓。只有当角色在某些镜头下与背景完全分离失败时，才增加极弱的 Fresnel 或专用轮廓光。

轮廓光不能替代基本光照，也不能让所有物体都拥有发光边缘。

### 6.4 颜色纪律

场景最多保留：

```text
冷色主光
+ 暖色火光
+ 一个受控的特殊色
```

如果同时使用红、紫、蓝、橙、绿等高饱和局部光，材质细节会被颜色污染，画面反而不精致。

---

## 7. 阴影策略

### 7.1 主光阴影

主方向光优先调节：

1. `Shadow Max Distance`；
2. PSSM 分割；
3. Shadow Map 质量；
4. `Normal Bias` 和 `Bias`；
5. 适度模糊。

近处分割需要优先保证角色脚下、武器和 Boss 接触区域的清晰度。阴影范围越大，单位区域获得的阴影精度越低。

### 7.2 阴影错误排查

| 症状 | 优先检查 |
|---|---|
| 阴影贴在模型表面、出现条纹 | 法线、Normal Bias、阴影图精度 |
| 阴影漂浮 | Bias / Normal Bias 是否过大 |
| 近处阴影模糊 | Shadow Max Distance 是否过远、PSSM 分割是否合理 |
| 局部光突然没有阴影 | Shadow Atlas 是否被占满 |
| 阴影随镜头闪动 | 阴影精度、Bias、模型尺度和远近平面 |

不要先用极大的 Bias “修掉”所有阴影伪影，这通常会制造漂浮阴影。

### 7.3 关键光才投影

建议初始只给以下对象提供动态阴影：

- 主方向光；
- 1–2 个最靠近战斗区域的火盆；
- 需要明显制造攻击反馈的特殊光源。

阴影灯越多，Shadow Atlas 越容易降级。装饰性蜡烛和远处火光可以只提供非阴影照明。

---

## 8. GI、AO 和反射

### 8.1 LightmapGI

LightmapGI 是 Web 版静态场景间接光的首选：

- 适合当前单一竞技场；
- 适合墙体、地面、断墙和固定装饰；
- 运行时成本低于完整实时 GI；
- 需要正确 UV2 和静态物体标记；
- 场景重新布光或几何改变后需要重新烘焙。

LightmapGI 的烘焙结果可以由 Compatibility 运行，但烘焙阶段需要在开发环境中完成。动态角色和动态 Boss 不会像静态场景那样参与同一套烘焙，应使用动态灯光、环境光和其他轻量补偿保证角色亮度一致。

### 8.2 AO

建议组合：

```text
模型 AO 贴图
+ SSAO
+ LightmapGI
```

三者负责不同尺度：

- AO 贴图：模型内部固定缝隙；
- SSAO：屏幕空间中的近距离接触；
- LightmapGI：静态结构的间接光和大尺度明暗关系。

AO 的目标是增强接触，不是把墙角和铠甲缝隙涂成纯黑。若画面出现脏黑、脚下黑圈或角色整体失去颜色，先降低 AO，而不是增加环境光。

### 8.3 ReflectionProbe

铠甲、武器和湿地面需要环境反射才能显得有材质，但 Web 端不建议依赖高成本的实时屏幕空间反射。

优先使用：

- 覆盖竞技场的 ReflectionProbe；
- 角色或 Boss 附近的局部 ReflectionProbe；
- 合理的 roughness 让反射不要过于镜面；
- 静态或低频更新；
- 低质量档位关闭额外探针或减少更新。

ReflectionProbe 是补充，不是全局 GI。反射过强会让石墙、皮革和铠甲全部看起来像湿塑料。

---

## 9. 雾和空间氛围

### 9.1 Web 基线：深度雾 + 高度雾

使用 `WorldEnvironment` 的普通雾配置：

- 深度雾隐藏远处墙体和重复模块；
- 高度雾形成贴地层次；
- 低浓度雾帮助冷色阴影与暖色火光分离；
- 雾色应与天空或环境色协调，而不是简单套灰白滤镜。

建议先关闭雾完成灯光和材质校准，再以低密度逐步加入。

### 9.2 体积感的 Web 模拟

由于 Compatibility 不支持体积雾，可用以下组合模拟局部氛围：

```text
深度/高度雾
+ 交叉雾片或 Billboard
+ 低数量粒子
+ 发光火焰
+ 点光源或聚光灯
```

雾片必须有深度淡出和软边缘，避免摄像机旋转时看到明显的矩形面。不要让透明粒子覆盖整个画面，否则容易产生过度 Overdraw 和移动端性能问题。

### 9.3 火焰和烟尘

火焰外观建议使用：

```text
Emission 材质
+ 粒子动画
+ Glow
+ 一盏低范围动态光
```

烟尘和灰烬应优先使用少量粒子或远景装饰，不要把复杂的体积效果写入所有材质。

---

## 10. 后处理和镜头

### 10.1 色调映射和曝光

色调映射不是 Shader 的替代品，但它会决定材质和灯光最后的观感。

推荐流程：

1. 关闭雾和 Glow；
2. 使用中性灰和 PBR 校准球调整主光与环境光；
3. 固定曝光；
4. 在 ACES 或 AgX 中选择一个版本并锁定；
5. 再加入血红/暗紫环境色；
6. 最后调局部火光和 Glow。

不要用极端曝光来掩盖错误材质。否则黑铁会失去层次，火光会变灰，石墙会变成一片黑。

### 10.2 Glow

Glow 只应作用于：

- 火焰；
- 剑光；
- 魔法效果；
- 湿沙反光区的受控发光；
- Boss 阶段转场的特殊能量。

普通石墙、金属高光和 UI 不应无意中进入 Glow。Glow 强度和阈值需要纳入质量档位。

### 10.3 景深

景深由 `CameraAttributes` 管理，不是普通物体材质 Shader。

建议：

- 战斗默认关闭或极弱；
- Boss 登场、处决窗口和 Photo Mode 可以增强；
- 不能模糊玩家需要判断的攻击轨迹；
- 低档位直接关闭。

### 10.4 暗角和颜色调整

暗角适合强化画面中心、低血量或特殊阶段，但必须低强度。颜色调整可以使用渐变或 LUT，但必须保留一个中性材质验收模式。

暗角和 LUT 属于全屏后处理，不要写进每个物体的材质 Shader。

---

## 11. 质量档位

以下是起始方案，不是未经测试的硬指标。需要在目标浏览器和硬件上实测后校准。

| 项目 | Web High | Web Balanced | Web Low |
|---|---|---|---|
| 内部渲染分辨率 | 100% | 85–90% | 70–80% |
| 3D MSAA | 保留 | 保留或降低 | 关闭或最低档 |
| 主方向光阴影 | 开，高质量 | 开，中质量 | 开，短距离 |
| 局部阴影灯 | 1–2 个 | 0–1 个 | 关闭 |
| LightmapGI | 开 | 开 | 开，降低贴图/采样预算 |
| SSAO | 开，低到中强度 | 开，低强度 | 关闭或最低强度 |
| ReflectionProbe | 主要探针 | 主要探针 | 静态或关闭次要探针 |
| 深度/高度雾 | 开 | 开，降低密度 | 简化深度雾 |
| 雾片/粒子 | 完整限制数量 | 减少数量 | 只保留关键 FX |
| Glow | 开 | 开，降低强度 | 关闭或极低 |
| 景深 | Photo Mode/过场 | 仅过场 | 关闭 |
| 自定义 Shader | 完整 | 简化分支 | StandardMaterial3D 回退 |

### 11.1 初始性能目标

以当前 1280×720 视口为基线，建议先建立以下验收目标：

- 中档桌面浏览器：稳定 60 FPS 为目标；
- 低档设备：允许 30 FPS 档位，但不能出现严重输入延迟；
- 单帧 GPU 时间、Draw Call、三角形数量和纹理显存必须在真实浏览器中记录；
- 首次加载时间和包体积必须单独记录；
- 不把编辑器窗口中的 FPS 当作 Web 性能结论。

具体阈值应在目标设备矩阵确定后冻结。

### 11.2 性能检查顺序

出现掉帧时按以下顺序排查：

1. 浏览器实际渲染分辨率；
2. 阴影灯数量和阴影距离；
3. 半透明粒子与雾片 Overdraw；
4. 高分辨率纹理和贴图切换；
5. ReflectionProbe 更新；
6. Glow 和全屏后处理；
7. 动态物体数量和骨骼更新；
8. 自定义 Shader 分支和纹理采样次数。

不要一开始就降低所有材质分辨率。先定位 GPU 和带宽的真实瓶颈。

---

## 12. 推荐实施顺序

### 阶段 1：灰盒光照和镜头

使用程序几何验证：

- 24m × 18m 战场的近、中、远三层构图；
- 玩家与 Boss 的轮廓可读性；
- 冷色主光和暖色火光方向；
- 竞技场中央水坑的位置；
- 摄像机退让和战斗可读性。

此阶段不引入复杂自定义 Shader。

### 阶段 2：材质校准场景

加入中性灰、金属、石材、皮革和湿地面，确认：

- 颜色空间；
- ORM 通道；
- 法线；
- 粗糙度范围；
- Metallic 分区；
- 贴图压缩；
- 光照下的材质差异。

### 阶段 3：LightmapGI 和 ReflectionProbe

固定静态几何、UV2 和光源后进行烘焙。记录：

- 烘焙耗时；
- Lightmap 体积；
- 角色与 Boss 的运行时补光；
- 铠甲和水坑反射是否稳定；
- 镜头移动时是否出现明显跳变。

### 阶段 4：阴影、AO 和局部光

加入：

- 主方向光 PSSM；
- 关键火盆阴影；
- SSAO；
- 角色脚下接触关系；
- 武器和 Boss 的战斗反馈光。

分别保存关闭/开启对照截图，避免把 AO、阴影和 GI 的效果混在一起。

### 阶段 5：雾、Glow 和色调映射

按以下顺序加入：

```text
曝光
→ 色调映射
→ 深度/高度雾
→ Glow
→ 颜色调整
→ 暗角
→ 景深
```

每一步都应能单独关闭，便于定位画面问题。

### 阶段 6：自定义 Shader

只实现已经确认有视觉收益的效果：

- 湿地面；
- 火焰；
- 剑光；
- Boss 发光部位；
- 角色 Fresnel；
- 轻量全屏暗角。

所有 Shader 都要提供低质量回退路径。

### 阶段 7：质量档位和浏览器回归

至少测试：

- Chrome；
- Edge；
- Firefox；
- Safari；
- 一台中档桌面 GPU；
- 一台集成显卡或低档设备；
- 目标移动浏览器（如果产品范围包含移动端）。

---

## 13. 可参考的模板和示例

这些示例可以作为研究材料，但不能直接认为是 Web 兼容模板。

### 官方资料

- [Environment and post-processing](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)：Environment、雾、Glow、景深、色调映射和颜色调整。
- [Overview of renderers](https://docs.godotengine.org/en/latest/tutorials/rendering/renderers.html)：Forward+、Mobile 和 Compatibility 的能力差异。
- [Internal rendering architecture](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html)：WebGL 2.0、Compatibility 和 LightmapGI 的渲染边界。
- [3D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html)：灯光、PSSM、阴影距离、Bias、Shadow Atlas 和接触阴影。
- [StandardMaterial3D](https://docs.godotengine.org/en/4.7/tutorials/3d/standard_material_3d.html)：PBR 材质和内置材质功能。

### 场景示例

- [Volumetric Fog Demo](https://godotengine.org/asset-library/asset/2754)：研究雾与灯光交互；主要面向 Forward+，不作为 Web 体积雾基线。
- [Global Illumination Demo](https://store.godotengine.org/asset/godot-foundation/global-illumination-demo/)：对比 LightmapGI、VoxelGI、SDFGI、ReflectionProbe 等；需要提取 Compatibility 可用部分。
- [Overgrown Subway Demo](https://github.com/mikatomik/Godot-4-Overgrown-Subway-Demo)：研究完整环境中的 LightmapGI、ReflectionProbe、雾、SSAO、Glow 和资产组织。
- [Desert Light](https://github.com/RPicster/godot4-demo-desert-light)：研究间接光、日夜灯光和体积氛围；高级效果需要改写为 Web 方案。

建议不要寻找一个“一键变成 UE5 画质”的万能模板。应从这些示例中分别抽取：

```text
材质导入规范
+ LightmapGI 流程
+ Environment 参数
+ 阴影配置
+ ReflectionProbe 布局
+ 后处理顺序
```

然后在本项目的 `WebRenderLab` 中重新组合。

---

## 14. 验收清单

### 14.1 材质

- [ ] Base Color、Normal、Roughness、Metallic、AO 色彩空间正确。
- [ ] ORM 通道已核对并记录。
- [ ] 石材、金属、皮革、湿地面的粗糙度差异明显。
- [ ] 黑铁不会因为曝光或 Glow 变成纯黑/纯白。
- [ ] 材质在中性光下成立，而不是只能在红色氛围光下成立。

### 14.2 灯光和阴影

- [ ] 玩家与 Boss 的轮廓在冷色主光下可读。
- [ ] 火盆产生暖色局部光，但不会染红全场。
- [ ] 主方向光阴影覆盖战斗区域。
- [ ] 角色脚下和武器接触阴影不漂浮。
- [ ] 不重要的蜡烛和装饰灯没有消耗过多阴影资源。
- [ ] 镜头移动时阴影不明显闪烁或跳变。

### 14.3 GI、AO 和反射

- [ ] 静态墙体和地面完成 LightmapGI 烘焙。
- [ ] 动态角色有稳定的运行时补光。
- [ ] SSAO 不制造黑色光圈。
- [ ] 金属和湿地面有环境反射，但不出现塑料感。
- [ ] ReflectionProbe 更新不会导致明显性能尖峰。

### 14.4 雾和后处理

- [ ] 远景深度由雾自然衰减，而不是靠黑色遮罩硬切。
- [ ] 贴地雾不遮挡战斗判读。
- [ ] 火焰和剑光才是主要 Glow 来源。
- [ ] 景深不会模糊关键攻击信息。
- [ ] 暗角和 LUT 可单独关闭并恢复中性画面。

### 14.5 Web 运行

- [ ] Chrome、Edge、Firefox、Safari 至少完成一次启动和操作测试。
- [ ] 1280×720 和窗口缩放下画面比例正确。
- [ ] Web High、Balanced、Low 三档均可运行。
- [ ] 低档位关闭高级效果后没有 Shader 编译错误。
- [ ] 记录真实浏览器 FPS、GPU 帧时间、Draw Call、三角形、纹理内存和首次加载时间。
- [ ] 导出包、压缩资源和缓存策略经过实际部署验证。

---

## 15. 风险和处理原则

| 风险 | 处理原则 |
|---|---|
| 误把 Forward+ 示例直接搬到 Web | 所有特效先查 Compatibility 支持表，再进入方案 |
| PBR 贴图颜色空间错误 | 建立固定导入预设和中性材质测试场景 |
| AO 过黑 | 降低 SSAO/AO 强度，检查是否重复乘算 |
| 阴影漂浮或闪烁 | 先查尺度、Bias、Normal Bias、阴影距离和模型法线 |
| 雾洗白画面 | 降低密度，区分深度雾与高度雾颜色 |
| Glow 过量 | 收紧 HDR 阈值，只允许明确 Emission 进入 |
| 金属像塑料 | 检查 Metallic 分区、Roughness 和 ReflectionProbe 强度 |
| Web 性能不稳定 | 先降低阴影/透明 Overdraw/分辨率，再考虑减少材质细节 |
| 首次加载过慢 | 控制 GLB、纹理和 Lightmap 体积，采用压缩和按需加载 |
| Shader 编译卡顿 | 减少材质变体，预热关键材质，提供 StandardMaterial3D 回退 |

---

## 16. 最终推荐

本项目浏览器版采用以下技术基线：

```text
Godot 4.7.2
GL Compatibility / WebGL 2
StandardMaterial3D 为主
Tripo PBR 资产经过固定导入校验
LightmapGI 负责静态间接光
SSAO + AO 贴图负责局部接触
ReflectionProbe 负责金属和湿地面反射
一个冷色主方向光
少量暖色关键局部光
深度雾 + 高度雾
Emission + Glow 负责火焰和特殊能量
景深仅用于过场和 Photo Mode
自定义 Shader 只解决明确的材质或后处理需求
Web High / Balanced / Low 三档可测量降级
```

核心原则是：

> **先用正确的资产、光照方向、烘焙间接光和稳定阴影建立画面，再用少量 Shader 和后处理做风格增强。不要试图用一个复杂 Shader 弥补错误的 PBR、曝光、灯光和场景构图。**

这份文档是浏览器渲染技术建议，不替代后续的场景、脚本、资产导入器和性能测试实现。正式接入 Tripo 资产后，应以实际浏览器截图、帧时间和回归结果继续修订本方案。
