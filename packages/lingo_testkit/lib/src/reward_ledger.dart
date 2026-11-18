// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Lingowander
//
// 语遇 Lingowander 客户端的一部分。
// 本文件以 GNU General Public License v3.0 授权（仅此版本）。
// 完整文本见仓库根目录 LICENSE。

import 'language_pair.dart';

/// 一次尝试结算某个 [rewardKey]。
///
/// [dialogueId] 和 [pair] 用来描述“换语言后重放同一对白”。
/// 账本只按 [rewardKey] 去重，不从对白推导键。
final class RewardEvent {
  const RewardEvent({
    required this.rewardKey,
    required this.dialogueId,
    required this.pair,
    required this.timestampMs,
  });

  final String rewardKey;
  final String dialogueId;
  final LanguagePair pair;

  /// 事件自带的逻辑时间，单位毫秒。实现不应改读墙上时钟。
  final int timestampMs;

  RewardEvent copyWith({int? timestampMs, LanguagePair? pair}) {
    return RewardEvent(
      rewardKey: rewardKey,
      dialogueId: dialogueId,
      pair: pair ?? this.pair,
      timestampMs: timestampMs ?? this.timestampMs,
    );
  }

  @override
  String toString() {
    return 'RewardEvent($rewardKey, $dialogueId, $pair, t=$timestampMs)';
  }
}

/// 已经写入账本的一次结算。同一个 [rewardKey] 至多一条。
final class SettlementRecord {
  const SettlementRecord({
    required this.rewardKey,
    required this.dialogueId,
    required this.pair,
    required this.settledAtMs,
  });

  final String rewardKey;
  final String dialogueId;
  final LanguagePair pair;
  final int settledAtMs;

  @override
  String toString() => 'Settlement($rewardKey @ $settledAtMs)';
}

/// [RewardLedger.trySettle] 的三种结果。没有“再结算一次”。
enum SettleResult {
  /// 这个 key 此前没有结算，本次写入了唯一一条记录。
  settled,

  /// 这个 key 已经结算过，而且本次时间戳落在冷却区间内。
  inCooldown,

  /// 这个 key 已经结算过，本次不在冷却区间内，仍然拒绝。
  alreadySettled,
}

/// 奖励幂等账本。
///
/// 这不是发奖规则。它不判断玩家是否完成了目标，只保证同一个
/// [RewardEvent.rewardKey] 最多留下一条结算，并且冷却期内不会新增。
/// 生产实现位于尚未落地的 lingo_core。测试通过 wiring.dart 注入替身。
abstract interface class RewardLedger {
  /// 本账本使用的冷却时长。区间由实现解释为左闭右开。
  Duration get cooldown;

  SettleResult trySettle(RewardEvent event);

  /// 已结算记录。每个 rewardKey 至多出现一次。
  List<SettlementRecord> settlements();

  /// 该 key 的成功结算次数，只能是 0 或 1。
  int settlementCount(String rewardKey);

  /// 该 key 尚未结算时返回 false。
  /// 已结算时，时间戳落在 `[settledAtMs, settledAtMs + cooldown)` 内返回 true。
  bool isWithinCooldown(String rewardKey, int timestampMs);
}
