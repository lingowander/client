# 贡献说明

语遇客户端以 GNU GPL-3.0-only 授权，见仓库根目录的 [LICENSE](LICENSE) 与 [README](README.md)。

## 暂不接受外部拉取请求

在贡献者协议（CLA）或开发者来源证书（DCO）确定之前，**不接受外部拉取请求**。应用商店分发还可能需要 GPLv3 第 7 条附加许可，这项也尚未决定。政策落地并写回本文之前，请不要提交补丁。

维护者在本仓库上的日常开发不受此限制，仍然通过短生命周期分支和拉取请求合并。

## English

External pull requests are not accepted until a CLA or DCO policy is decided. A possible GPLv3 section 7 additional permission for app-store distribution is also undecided. Please do not send patches before that policy is written down here.

## 开发环境

1. 安装 Flutter stable（含 Dart）。版本与持续集成一致，使用 stable 渠道，不固定某个补丁号。
2. 克隆本仓库，在根目录执行 `dart pub get`。根目录是 pub workspace，不要在子目录单独维护另一份锁文件。
3. 运行应用：`cd app && flutter run`。组织标识为 `com.lingowander`。

## 分支与拉取请求

- 默认分支是 `main`。采用主干开发：功能分支生命周期短，合入后删除。
- 变更通过拉取请求进入 `main`，合并前需要评审。
- 不要把密钥、令牌、内部服务器地址或未公开的素材提交进仓库。
- 一个拉取请求只做一件事。

## 代码风格

提交前在仓库根目录运行，并保证全部通过：

```bash
dart format --output=none --set-exit-if-changed .
( cd app && flutter analyze && flutter test )
( cd packages/lingo_core && dart analyze && dart test )
( cd packages/lingo_protocol && dart analyze && dart test )
( cd packages/lingo_testkit && dart analyze && dart test )
python3 evals/tools/validate_cases.py
```

- 格式以 `dart format` 为准。
- `app/` 使用 [flutter_lints](https://pub.dev/packages/flutter_lints)（`app/analysis_options.yaml`）。
- `packages/lingo_core`、`packages/lingo_protocol` 与 `packages/lingo_testkit` 是纯 Dart 包，使用 [lints](https://pub.dev/packages/lints) 的 recommended 规则，并且不得依赖 Flutter。
- 根目录是唯一的 pub 锁文件。不要在包目录再提交 `pubspec.lock`。
- 叙事逻辑放在 `packages/lingo_core`。`app/lib/core` 只预留给应用层基础设施，两者不要混用。
- 接口与模型输出契约放在 `packages/lingo_protocol`。不要在客户端里手写一份会和服务端漂移的平行类型，作为最终契约。
