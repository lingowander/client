// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Lingowander
//
// 语遇 Lingowander 客户端的一部分。
// 本文件以 GNU General Public License v3.0 授权（仅此版本）。
// 完整文本见仓库根目录 LICENSE。

/// 语遇属性测试用的最小接口与参考实现。
///
/// 奖励账本和语言对画像的生产代码属于尚未落地的 lingo_core。
/// 本库的参考实现只编码不变量，接到生产代码时替换 wiring.dart 中的工厂。
library;

export 'src/language_pair.dart';
export 'src/learning_profile_store.dart';
export 'src/reference/in_memory_learning_profile_store.dart';
export 'src/reference/in_memory_reward_ledger.dart';
export 'src/reward_ledger.dart';
export 'src/wiring.dart';
