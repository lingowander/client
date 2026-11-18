# 语遇 Lingowander 客户端

语遇是一款人工智能情景对话语言学习游戏，形式接近视觉小说，界面与文案以中文为先。玩家可以不登录、在本机游玩，也可以使用自己的模型密钥，或在登录后走官方模型与云同步。叙事规则放在纯 Dart 内核里，三种路径共用同一套故事引擎。

本仓库目前只是工程骨架：有可以编译的 Flutter 应用、叙事与契约两个占位包、评测用例模板、属性测试骨架，以及格式检查、静态分析和测试的持续集成。没有剧情、输入、存档或网络功能。

## English summary

Lingowander (语遇) is a Chinese-first, visual-novel style language-learning game built around AI scenario dialogue. This repository is the GPL-3.0 client. The Flutter app lives in `app/`. Narrative code will live in the pure-Dart package `packages/lingo_core`. API and model-output contracts will live in `packages/lingo_protocol`. A separate private server repository (Go) will host the official model gateway, metering, sync, and accounts. This tree is a skeleton: a placeholder home screen, stub libraries, eval-case templates, a property-test package, and CI. No game features yet. `lingo_core` and `lingo_protocol` still export only their package names.

## 仓库布局

Flutter 应用在 `app/`，不在仓库根目录。根目录的 `pubspec.yaml` 是 Dart pub workspace，成员是应用和三个纯 Dart 包。组织标识为 `com.lingowander`（Android 应用 id 与 iOS bundle id 为 `com.lingowander.lingowander`）。

```text
.
├── app/                          Flutter 应用（Android、iOS，以及 Web 与桌面骨架）
│   └── lib/
│       ├── main.dart             占位首页
│       ├── core/                 应用层基础设施占位（不是叙事内核）
│       └── features/
│           ├── story/            叙事与视觉小说界面
│           ├── input/            语音、打字、选字
│           ├── settings/         设置
│           ├── save_sync/        本地存档与云同步
│           └── byok/             自带密钥
├── packages/
│   ├── lingo_core/               叙事内核，纯 Dart，无 Flutter 依赖（仍是占位）
│   ├── lingo_protocol/           API / LLM 契约，纯 Dart 占位
│   └── lingo_testkit/            属性测试骨架与参考实现，不是产品逻辑
├── prompts/                      提示词（空）
├── evals/                        评测用例 v0 与确定性断言约定
├── docs/                         文档（空）
├── assets/                       素材（空，许可与代码分开）
└── .github/workflows/            ci.yml 与 evals.yml
```

`app/lib/core` 预留给路由、依赖装配等应用层代码。故事引擎在 `packages/lingo_core`，不要把叙事逻辑写进 `app/lib/core`。

`packages/lingo_protocol` 以后放置 OpenAPI 生成的 Dart 客户端和 JSON Schema。服务端实现不在本仓库。

上述功能目录里现在只有说明文件，没有业务代码。

## 运行与测试

需要 [Flutter](https://docs.flutter.dev/install) stable（自带对应版本的 Dart）。在仓库根目录：

```bash
dart pub get
cd app
flutter run
```

检查（与持续集成相同）：

```bash
dart format --output=none --set-exit-if-changed .
cd app && flutter analyze && flutter test
cd packages/lingo_core && dart analyze && dart test
cd packages/lingo_protocol && dart analyze && dart test
cd packages/lingo_testkit && dart analyze && dart test
```

上面的 `cd` 从仓库根目录算起。应用使用 `flutter_lints`，纯 Dart 包使用 `lints`。评测用例的 schema 校验在 `.github/workflows/evals.yml`，不在上面这条主检查里。

## 配套服务端

官方模型网关、计量、同步、账号与防刷放在配套的**私有**服务端仓库，使用 Go，与本仓库分开。本仓库不包含服务端代码，也不包含服务器地址或密钥。

## 许可证

本仓库以 GNU General Public License v3.0 授权，完整文本见 [LICENSE](LICENSE)。

SPDX-License-Identifier: GPL-3.0-only

标识 `GPL-3.0-only` 表示仅适用第 3 版，不自动包含「或任何后续版本」。Flutter 与 Dart SDK 为 BSD-3-Clause，可以并入以 GPL-3.0 发布的客户端。在贡献者协议（CLA）或开发者来源证书（DCO）确定之前，不接受外部拉取请求，见 [CONTRIBUTING.md](CONTRIBUTING.md)。
