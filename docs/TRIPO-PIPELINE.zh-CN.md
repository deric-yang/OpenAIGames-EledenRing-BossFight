# Tripo 资产管线

本管线只负责把 8 个原始资产的生成请求、任务状态和下载后的 GLB 源文件做成可追溯记录。生成结果不会自动视为可发布资产；Blender 清理、减面、LOD、碰撞代理、Godot 导入、视觉检查和许可证确认仍是后续人工步骤。

## 运行时和文件

- 唯一实现：Python 3.9，入口为 `scripts/tripo/generate.py`。
- `scripts/tripo/generate.mjs` 仅保留弃用提示，不再包含第二套 API 实现；当前环境没有 Node，不应使用它。
- API 密钥只接受进程环境变量 `TRIPO_API_KEY`。脚本不会读取 `.env`、文档、转录或其他项目文件中的凭据，也不会把密钥写入记录或打印到终端。
- `TRIPO_MODEL` 可以通过环境变量覆盖默认模型名；它不包含凭据。
- 生成请求记录位于 `generation-records/tripo/<asset_id>/request.json`，提交记录、轮询记录和审计记录分别为 `submission.json`、`task.json` 和 `audit.json`。
- 下载原始文件位于 `assets/source/<asset_id>/model.glb`。签名下载 URL 只在当前进程内存和 curl 的 stdin 中流转，不进入命令行参数、JSON 记录或日志。

## 先做离线预览

离线预览不需要 API 密钥、不访问网络、不消耗额度，也不会创建生成记录：

```sh
python3 scripts/tripo/generate.py submit --dry-run
python3 scripts/tripo/generate.py submit --dry-run wd_player_visual_01 wd_player_weapon_01
# 等价命令：
python3 scripts/tripo/generate.py dry-run wd_player_visual_01
```

输出中的 `request` 是准备发送的 JSON，`runtime_budget_seconds` 是本地规划预算，不是未经确认的 Tripo API 字段。清单保持原有 8 个资产意图；额外的预算只用于本地下载超时和计划，不会加入 API 请求体。

## 线上命令（当前不要盲目执行）

```sh
TRIPO_API_KEY='由安全的进程环境注入' \
  python3 scripts/tripo/generate.py submit wd_player_visual_01

TRIPO_API_KEY='由安全的进程环境注入' \
  python3 scripts/tripo/generate.py poll

TRIPO_API_KEY='由安全的进程环境注入' \
  python3 scripts/tripo/generate.py balance
```

本次工作没有执行线上命令，也没有使用凭据或消耗额度。`submit` 在写入不可变的 `request.json` 后才会发送请求。如果进程在 POST 后丢失响应，下一次运行看到“有 request、无 submission”时会停止，不会自动重试，从而避免重复扣费；需要先在服务商控制台或人工核对任务，再决定如何补录记录。已有 `submission.json` 时只会报告 `already_submitted`。

## 安全和文件完整性

- JSON 记录使用同目录临时文件、flush/fsync 和原子替换，避免半写文件。
- API 和下载失败只报告通用错误，不转储远端响应体、curl stderr 或签名 URL。
- 下载 URL 必须是 HTTPS，curl 禁止跟随到非 HTTPS 的重定向；不使用 `-k` 绕过 TLS 校验。
- 下载完成后先校验 GLB v2 magic、版本、声明长度和 JSON chunk，再原子替换为 `model.glb`。无效文件不会进入源资产目录。
- 轮询记录只保留资产 ID、任务 ID、状态、进度、额度字段和时间戳，不保留完整远端响应。

## 清单和请求字段

当前清单为 8 个资产，原始 prompt 保持不变。每项增加了仅供本地使用的运行预算：

| 资产 | 本地预算（秒） |
|---|---:|
| `wd_black_tree_hero_01` | 900 |
| `wd_tree_root_01` | 720 |
| `wd_ruin_foreground_01` | 720 |
| `wd_war_debris_01` | 600 |
| `wd_war_banner_01` | 600 |
| `wd_torch_01` | 600 |
| `wd_player_visual_01` | 900 |
| `wd_player_weapon_01` | 720 |

请求体保留本次会话中已有的模型、几何质量、面数、纹理/PBR、prompt、negative prompt 和确定性 `model_seed` 字段。negative prompt 额外排除了漂浮几何、断开部件、额外肢体和坏拓扑。

### 官方字段核验状态

截至 2026-09-27，本次尝试访问官方公开页面时网络连接被拒绝，无法从页面内容核实当前生产 API：

- [Tripo Generation API](https://platform.tripo3d.ai/docs/generation)
- [Tripo API Schema](https://platform.tripo3d.ai/docs/schema)
- [Tripo Quick Start](https://platform.tripo3d.ai/docs/quick-start)

因此，以下内容均应视为**未核实的历史脚本约定**，不能在网络恢复前当作官方兼容性结论：`https://openapi.tripo3d.ai/v3`、`/generation/text-to-model`、`/account/balance`、`/tasks/{task_id}`，以及请求字段名和成功响应中的 `task_id`/模型 URL 字段。脚本没有用猜测的生产 API 做验证调用；恢复网络后应先重新对照官方文档，再进行单个、人工批准的提交。

## 测试

只使用 Python 标准库的 mock unittest，不访问网络：

```sh
python3 -m unittest discover -s tests -p 'test_tripo_pipeline.py' -v
```

测试覆盖离线预览、缺少密钥、API 错误脱敏、不可变请求和重复提交保护、HTTPS 签名 URL 不进 argv、GLB 校验、原子记录写入以及无效下载清理。

## Godot 导入建议

本次按文件所有权限制，没有修改项目外的 Godot 文件。建议主代理在确认目录策略后，在 `assets/source/` 和 `assets/processed/` 下各放置适当的 `.gdignore`，避免原始/加工资产被 Godot 当作运行时资产扫描；不要忽略 `assets/runtime/`。