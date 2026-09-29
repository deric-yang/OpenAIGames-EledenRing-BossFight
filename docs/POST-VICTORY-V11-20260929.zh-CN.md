# V11：胜利后自由移动

已阅读并沿用 `HANDOFF-INPUT-V11-20260929.zh-CN.md`。200ms 单槽缓冲、翻滚保护、动作取消窗口与连段宽限保持原有配置；V12 候选音效未接入。

## 行为

- 击败 Boss 后仍处于 `victory`，继续接收走路、疾跑、翻滚和攻击输入；不会重新启动 Boss AI、伤害判定或战斗音乐。
- 胜利时清除之前缓存的攻击；之后的新输入继续使用 V11 的消费和耐力规则。
- 镜头解除 Boss 锁定，Tab 不会重新锁定已死亡的 Boss。Boss 消散时移除对玩家的碰撞，避免留下隐形障碍。
- 胜利播报、消散、奖励卡及音效保持原有时序。屏幕下方提示移动操作及 R 重开。
- R 恢复双方生命值、位置、碰撞、镜头锁定、输入缓存和冠冕过场候场状态。玩家死亡后仍需按 R 复活，不允许死后走动。

## 验证

- `tests/player_input_v11_test.gd`：19 项通过。
- `tests/post_victory_movement_test.gd`：21 项通过，包含真实玩家位移、疾跑、翻滚单次消费、胜利播报单次触发、解除 Boss 碰撞、胜利/失败按 R 重开及初始状态恢复。
- 新测试分别运行于 Godot headless 与原生 Compatibility 渲染器。测试场景直接触发胜利分支，不代表完整手动打败 Boss；原生截图见 `qa/post-victory-v11-20260929/victory-movement.png`。
- Web 导出使用 `index-input-v11-victory.*` 独立文件名，主入口 `builds/web/index.html` 已指向新版，避免命中旧包缓存。构建哈希记录在 `builds/web/build-info.json`。
- 浏览器已加载新版脚本并正常进入出生画面，控制台未见警告或错误；浏览器检查仅覆盖加载，战后移动与重开由上述真实场景测试验证。

试玩：<http://127.0.0.1:8093/?build=input-v11-victory>

本轮修改仅在原开发目录完成，未同步 GitHub 的独立发布副本。
