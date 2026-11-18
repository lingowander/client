// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Lingowander
//
// 语遇 Lingowander 客户端的一部分。
// 本文件以 GNU General Public License v3.0 授权（仅此版本）。
// 完整文本见仓库根目录 LICENSE。

import 'package:lingo_core/lingo_core.dart';
import 'package:lingo_protocol/lingo_protocol.dart';

import 'learning_profile_store.dart';
import 'reference/in_memory_learning_profile_store.dart';
import 'reference/in_memory_reward_ledger.dart';
import 'reward_ledger.dart';

/// 参考实现的占位冷却。不是产品参数。
/// 属性测试会传入自己生成的时长，不依赖这个默认值。
const Duration referenceCooldown = Duration(milliseconds: 1000);

/// 已经链上的包。目前二者都只有包名常量，没有奖励账本、画像或协议类型。
///
/// [lingoCoreName] 与 [lingoProtocolName] 被引用，是为了让 workspace 依赖真正参与编译。
/// 出现可替换的生产类型之前，下面两个工厂继续返回参考实现，不在这里补业务规则。
const List<String> linkedPlaceholderPackages = <String>[
  lingoCoreName,
  lingoProtocolName,
];

/// 创建当前被测的奖励账本。
///
/// lingo_core 还没有账本类型，所以返回参考实现。类型出现后，只改这个函数，
/// 改为返回生产实现或薄适配器。标明“参考实现占位行为”的测试要一起删掉，
/// 因为生产代码会自行决定某次尝试是否符合发奖条件。
RewardLedger createRewardLedgerUnderTest({
  Duration cooldown = referenceCooldown,
}) {
  return InMemoryRewardLedger(cooldown: cooldown);
}

/// 创建当前被测的语言对画像存储。
///
/// lingo_core 还没有画像类型，所以返回参考实现。适配器的快照只能投影该语言对
/// 自己的状态，不要投影分数、等级或百分比。
LearningProfileStore createLearningProfileStoreUnderTest() {
  return InMemoryLearningProfileStore();
}
