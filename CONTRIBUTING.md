# 贡献指南

感谢你对 Efflora HarmonyOS Bench 的关注！

## 贡献新任务

1. 阅读 [`docs/categories.md`](docs/categories.md)、[`docs/environment.md`](docs/environment.md) 和 [`docs/task-format.md`](docs/task-format.md)，安装 Harbor 0.24.0（`uv tool install harbor==0.24.0`）。
2. 用 Harbor 生成任务骨架，再按 `docs/task-format.md` 修改：

   ```bash
   harbor task init efflora/<task-id> -p tasks --no-pytest
   # 例：harbor task init efflora/bugfix-notepad-crash-on-empty-title -p tasks --no-pytest
   ```

3. 填写 `instruction.md`、`task.toml`、`environment/`、`solution/solve.sh`、`tests/`。
4. 本地自检：

   ```bash
   python3 scripts/validate_tasks.py tasks/<task-id>
   python3 scripts/build_index.py            # 更新 tasks/index.jsonl 和 README 任务分布图，随任务一起提交
   harbor run -p tasks/<task-id> -a oracle   # 参考解必须得 1 分
   harbor run -p tasks/<task-id> -a nop      # 不做修改必须得 0 分
   ```

5. 提交 PR，并在描述中说明任务来源、上游许可证、估计用时和验证结果。

## 任务检查清单

- [ ] 任务 id 符合 `<category>-<app>-<short-desc>`，与目录名、`task.name` 一致
- [ ] 上游代码固定到 commit，许可证允许再分发/引用
- [ ] 符合基准环境约定：`schema_version = "1.4"`、`metadata.api_level = 24`，涉及时区 / 语言 / 分辨率的行为按 `docs/environment.md`
- [ ] `instruction.md` 不泄露解法，测试只覆盖说明中的行为
- [ ] oracle 得分 1，nop 得分 0
- [ ] 不包含任何密钥、个人信息或 HarmonyOS SDK 文件

## 提交评测结果

运行产物与轨迹提交到 HuggingFace 数据集 `efflora/harmonyos-bench-runs`。流程见 [`docs/evaluation.md`](docs/evaluation.md#提交结果)。

## 其他贡献

Bug 报告、评测环境改进、文档完善均欢迎通过 Issue / PR 提交。

## 许可

提交贡献即表示你同意以 [Apache License 2.0](LICENSE) 授权你的贡献内容。
