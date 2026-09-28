# 资产来源台账

所有正式资产接入前必须登记。Tripo 原始资产、Blender 加工资产和 Godot/Web 运行时资产必须分层保存。

## 必填字段

- `asset_id`
- 类别与用途
- 来源提供者 / URL / 服务条款版本
- Tripo task ID（如适用）
- prompt / negative prompt
- 生成模型与版本
- geometry quality / face limit
- texture quality / texture version
- seed（如服务返回）
- 生成日期、费用和币种
- 原始文件路径与 hash
- Blender 源文件、处理步骤和处理日期
- 运行时文件路径与 hash
- 原始面数、运行时三角面数、材质槽、纹理尺寸
- LOD0/LOD1/LOD2 目标和实际统计
- UV2、碰撞代理、实例化/合并方式
- 许可证、署名要求、再分发状态、是否允许公开发布
- 视觉审核：`approved / revise / reject`
- 性能审核：`approved / revise / reject`
- 备注和替代版本关系

## 首轮资产 ID

- `wd_ground_sand_module_01`
- `wd_ruin_foreground_01`
- `wd_war_debris_01`
- `wd_war_banner_01`
- `wd_torch_01`
- `wd_black_tree_hero_01`
- `wd_tree_root_01`
- `wd_tree_golden_rift_01`
- `wd_hanging_veil_01`
- `wd_dust_card_01`
- `wd_player_visual_01`
- `wd_player_weapon_01`
- `wd_boss_visual_blockout_01`（程序占位，不是 Tripo 正式资产）

## 生成档位原则

首轮按 400k / 800k / 1.2m 原始面数上限做代表性资产矩阵，再根据轮廓、材质、清理成本、下载体积和浏览器实测冻结类别档位。运行时不直接使用原始面数。

初始运行时预算：黑树 120k–250k、近景遗迹单件 30k–80k、小件 10k–30k、帷幔单片 2k–10k、玩家 120k–250k。中景优先 2K，远景优先 1K/图集/烘焙，4K 只给少数英雄材质候选。

## 安全与授权

Tripo 任务响应、临时签名 URL、API key、Authorization Header 和私密凭据不得写入 GDD、场景、运行时资源或公共仓库。生成资产不能自动标为 CC0。旧动作复用当前登记为 `Deferred`，进入后续阶段前重新核对骨骼、授权和动作适配。
