<!--
SPDX-License-Identifier: GPL-3.0-only
Copyright (C) 2026 Lingowander

语遇 Lingowander 客户端的一部分。
本文件以 GNU General Public License v3.0 授权（仅此版本）。
完整文本见仓库根目录 LICENSE。
-->

# lingo_testkit

语遇属性测试骨架。包在 `packages/lingo_testkit`，并登记在根目录 pub workspace 里。

一开始它放在 `evals/property/`，是为了不和当时还在并行的仓库骨架抢 `packages/`。骨架合入之后，根目录的 `pubspec.yaml` 就是 workspace，贡献说明也不让子目录再留一份锁文件。所以包挪到这里，锁文件只保留仓库根目录那一份。

## 和现有包的对接

`lingo_core` 与 `lingo_protocol` 目前各自只导出一个包名常量，没有奖励账本、语言对画像，也没有 `turn_output` 之类的契约类型。本包依赖它们，让 workspace 解析和编译真正经过这两个库。`linkedPlaceholderPackages` 引用这两个常量。

工厂仍然返回参考实现。等生产类型出现，只改 `lib/src/wiring.dart` 里的两个函数。不要把发奖条件或薄弱点计算写进参考实现。

## 为什么是 dartproptest

属性测试使用 [`dartproptest`](https://pub.dev/packages/dartproptest)（BSD-3-Clause）。BSD-3-Clause 可以和 GPL-3.0-only 的程序一起分发。`package:test` 与 `package:lints` 也是 BSD-3-Clause。

没有选用 `glados`。pub.dev 上的 1.1.7 把 SDK 约束写成 `>=2.12.0 <3.0.0`，当前 Dart 3 无法解析，最近一次发布停在 2023 年。

## 接口

`RewardLedger` 是奖励幂等账本，不是“这次该不该发奖”的规则引擎：

- `trySettle` 对同一个 `rewardKey` 最多成功一次
- 冷却区间是左闭右开的 `[settledAtMs, settledAtMs + cooldown)`，区间内返回 `inCooldown`
- 冷却结束后仍然返回 `alreadySettled`，不开始第二次结算
- 冷却按 key 计。处理另一个 key 不得改变已有 key 的结算次数
- 时间用事件自带的 `timestampMs`，参考实现不读墙上时钟
- 换语言重放同一对白、整段重玩，只要 `rewardKey` 相同就不再结算。键本身要由将来的 `lingo_core` 保证稳定；本包不从对白推导键

`LearningProfileStore` 是语言对画像的快照接口：

- `apply` 只允许影响信号自己的（源语言，目标语言）
- `snapshotFor` 在没有该桶、或该桶是纯游戏（源语言等于目标语言）时返回 `null`
- 切走再切回来，原桶快照等于“只重放该桶自己的信号”得到的快照
- 纯游戏信号不创建档案，也不改变其他桶
- 参考实现把占位 `marker` 按到达顺序放进快照。这不是薄弱点模型

## 参考实现不是业务逻辑

`InMemoryRewardLedger` 和 `InMemoryLearningProfileStore` 只为了让上面的不变量有一个可运行的替身。它们不计算经验、不生成薄弱点、不解释对白，也不决定哪一类行为值得奖励。第一次观察到某个新 key 就入账，只是为了让替身不是空操作；测试里把这一假设单独放在“参考实现占位行为”组，接到生产实现时删掉。

```bash
dart pub get
dart analyze packages/lingo_testkit
dart test packages/lingo_testkit
```

后两条从仓库根目录执行。
