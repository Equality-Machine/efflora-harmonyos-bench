## 变更类型

- [ ] 新任务（分类：feature / bugfix / spec）
- [ ] 评测环境 / 脚本
- [ ] 文档

## 新任务信息

- 任务 id：
- 上游仓库 / commit / 许可证：
- 预计用时（熟练鸿蒙工程师）：

## 自检

- [ ] `python3 scripts/validate_tasks.py` 通过
- [ ] 已运行 `python3 scripts/build_index.py` 更新 `tasks/index.jsonl` 和任务分布图
- [ ] 符合基准环境约定（API 24、Harbor 0.24.0 / schema 1.4，见 `docs/environment.md`）
- [ ] `harbor run -a oracle` 得分为 1
- [ ] `harbor run -a nop` 得分为 0
- [ ] 不包含密钥、个人信息或 HarmonyOS SDK 文件
