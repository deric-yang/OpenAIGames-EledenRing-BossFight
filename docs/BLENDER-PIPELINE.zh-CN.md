# 《恸哭沙丘》Blender 拼装管线

## 当前状态

本轮只生成 Blender 评审用的程序化场景骨架。Tripo 当前不可用，因此所有本轮新增几何、材质和道具都必须标记为 `procedural`，不能写成 Tripo 生成资产，也不能标记为正式视觉资产或完成资产。

- Blender 场景：`WeepingDunes_Assembly`
- 场景状态：`procedural_scaffold_needs_Tripo_visual_replacement`
- Boss：继续保持程序体块占位（`procedural-blockout`）
- 运行时导出：未执行，等待视觉与性能审核
- 轴约定：Blender 原生 Z-up，X/Y 为地面，Z 为高度；不执行 Godot/Blender 反射或置换矩阵
- glTF：后续使用标准 Blender glTF 导出方向；禁止负行列式映射

## 安全边界

构建脚本只清理带有 `wd_owner = gilded-ruin-boss:weeping-dunes` 的项目场景、主集合、子集合和程序对象。不会全选删除、不会清理未打标签的用户对象，也不会删除用户拥有的场景内容。相同标签的场景和集合会被复用，程序材质使用稳定的 `WD_` 名称，重复构建不会累积 `.001/.002` 项目相机、灯光、场景或材质。

项目对象位于 `WeepingDunes_Assembly` 主集合下：

- `WD_Ground`：宽阔起伏沙丘地形与基底
- `WD_Foreground` / `WD_Midground`：破碎遗迹、碎石、旗帜、火盆、武器代理
- `WD_BlackTree`：带根部、分叉和逐段收细的黑树
- `WD_GoldenRift`：薄的锯齿金色裂隙曲线
- `WD_HangingVeil`：低面数弯曲透明帷幔，不使用矩形实体块
- `WD_Cameras` / `WD_Atmosphere`：评审镜头与程序灯光

## 评审与 QA

先通过项目 MCP 检查当前场景，再保存版本化的 before 截图；构建后必须通过 MCP 检查标签、轴约定、相机和对象数量，并实际读取渲染截图。当前证据：

- before：`qa/blender/weeping_dunes_before_v001.png`
- 中间迭代：`qa/blender/weeping_dunes_after_v003.png`
- 最终评审图：`qa/blender/weeping_dunes_final_v004.png`
- 最终 MCP 构建输出：`qa/blender/mcp_build_final.json`
- 最终 MCP 检查输出：`qa/blender/mcp_inspect_final.json`
- 评审摘要：`qa/blender/blender_review_summary_v004.json`
- 当前 Blend：`assets/processed/weeping_dunes_assembly.blend`

最终图已能同时读出近景碎石/遗迹和战场道具、中景金色玩家与较大的红色 Boss 体块、远景黑树剪影/金色裂隙/半透明帷幔。镜头不再裁切树顶和主要演员。视觉上仍属于未完成 scaffold：树和 Boss 仍是低面数程序代理，帷幔透明度、黑树材质、前景道具轮廓和实际运行时性能仍需 Godot 与后续正式资产审核。

## MCP 日志

MCP 的标准错误输出重定向到 `qa/blender/*stderr` 文件，避免构建脚本内容反复淹没终端。客户端同时检查 `isError` 以及返回文本中的常见异常标记（`Traceback`、`RuntimeError`、`NameError` 等），避免服务端在 `isError=false` 时静默吞掉脚本错误。

项目配置不再引用 `projects/sekiro-combat` 的活动路径。`tools/blender-mcp/mcp-for-blender` 是一个项目内启动器，真正的第三方 MCP 服务通过环境变量显式提供：

```sh
export BLENDER_MCP_COMMAND=/absolute/path/to/mcp-for-blender
python3 tools/blender-mcp/client.py tools/blender-mcp/inspect_scene.py
```

启动器不会下载、复制或隐藏外部依赖；未设置变量时会以明确错误退出。这样 Blender 插件/服务的安装位置属于本机环境，而不是新项目的运行时资产或源码依赖。
