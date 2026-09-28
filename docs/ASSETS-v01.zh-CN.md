# 首批 Tripo 资产 · 2026-09-27

## 交付与费用

5 件生成任务全部成功，原始 GLB 位于 `assets/source/<ID>/model.glb`。银灰骑士使用单体 A-pose 概念图，其余使用独立资产提示词。模型版本 `v3.1-20260211`，详细几何和 PBR 纹理。

生成前余额 1375；生成后 API 查询余额 **1115**、冻结 **0**。合计 **260 credits**：骑士 60，其余各 50。没有自动重复生成或额外绑骨收费任务。

| 资产 | 任务 ID | 费用 |
| --- | --- | ---: |
| 银灰骑士 | 878680ef-f845-4e91-ab15-71170013fb4d | 60 |
| Great Enemy 主体 | 98dba75f-0e97-4145-aee0-50d3abe1acbd | 50 |
| Great Enemy 巨刀 | 56dac0ea-5c8c-4a56-97e2-049c020d29bb | 50 |
| 黄金巨树 | cc956b3f-eb17-429b-bb6c-5f73272d1466 | 50 |
| 战争残骸 | a5858239-6039-4be9-8d86-f5b456e7adfa | 50 |

原始请求、任务状态与 SHA-256 记录在 `generation-records/production-v01/<ID>/`。原件下载校验 GLB 版本与长度，完成后才从 `.part` 原子改名；已提交 ID 不会重复提交。

## 实测几何

| 原件 | 三角面数 | 骨架 |
| --- | ---: | --- |
| 银灰骑士 | 473,707 | 无 |
| Boss 主体 | 783,056 | 无 |
| 巨刀候选 | 142,938 | 无 |
| 黄金树 | 667,876 | 无 |
| 战争残骸 | 240,991 | 无 |

每件目前为一个网格对象、一套材质与三张 4096×4096 贴图（颜色、法线、ORM）。这些是源资产规格，不是浏览器游戏的最终预算。

## 审阅入口

- 本地网页：<http://127.0.0.1:8093/asset-review/>，支持模型选择、旋转、缩放、下载和三角面数查看。
- 渲染图与几何统计：`assets/processed/<ID>/review/`。
- 重建网页：`node tools/asset-review/build.mjs`；使用项目已有 Web 预览服务，仅服务 `builds/web`。
- 预览器采用 [Google model-viewer](https://modelviewer.dev/) 4.3.1，本地内置脚本与 Apache-2.0 许可证。

## 外观评审与下一步

- **银灰骑士**：银灰钢甲与炭灰裙布已落实，背面甲片完整；角色高精原件约 47 万三角面，无骨架。需整理面部/手部细节、下摆拓扑与减面，再做骨架及旧动作验证。
- **Boss 主体**：宽肩厚甲、暗铁旧金和酒红腰布，当前约 78 万三角面，无骨架。作为连续人体装配基础；还需要更夸张的头冠、鬃饰与背部装饰，才能接近概念中的将军气势。肩甲与手臂在大幅挥刀时的穿插尚未验证。
- **巨刀（待返修）**：当前弧度过大，近似镰形，偏离参考中的厚重双刀。保留为候选，下一轮改成长刀身、轻弧度与厚重刀背；不将此候选设为最终武器。装配尺度、握点、碰撞体及武器轨迹尚未制作。
- **黄金树**：树干与金色裂隙可用作基底，但当前树冠较稀疏、枝梢偏钝，且底部带薄地片。需清理地片并扩展横向主枝，才能达到概念里的远景尺度。发光、雾气、帷幔及远景构图在场景阶段实现。
- **战争残骸**：成组原件用于后续沙丘散布；需减面和碰撞代理。

所有模型是静态生成原件，尚未通过运行时面数、骨架、动画变形与浏览器性能验收。游戏内仍保留现有白盒人物、树与残骸。Boss 正式动作继续等待用户提供；没有将这些静态模型标为已完成动作资产。

## 可复现命令

```sh
scripts/tripo/run.command balance
scripts/tripo/run.command poll

/Applications/Blender.app/Contents/MacOS/Blender --background \
  --python tools/asset-processing/review_model.py -- \
  --source assets/source/player_silver_v01/model.glb \
  --output assets/processed/player_silver_v01/review --front-angle 90

node tools/asset-review/build.mjs
```

渲染脚本只规范化审阅场景，不覆盖生成原件。高精度 GLB 的审阅渲染按顺序执行，避免在 16 GB 本机上并行造成内存压力。
