// SPDX-License-Identifier: GPL-3.0-only

import '../reward_ledger.dart';

/// 奖励账本的参考实现。
///
/// 只编码幂等：每个 rewardKey 保留第一次写入的记录，之后一律拒绝。
/// 不判断玩家该不该获得奖励，也不从对白生成 rewardKey。
/// “第一次就入账”是替身的占位行为，不是产品规则。
final class InMemoryRewardLedger implements RewardLedger {
  InMemoryRewardLedger({required this.cooldown});

  @override
  final Duration cooldown;

  final Map<String, SettlementRecord> _byKey = {};

  @override
  SettleResult trySettle(RewardEvent event) {
    final existing = _byKey[event.rewardKey];
    if (existing != null) {
      if (_insideCooldown(existing, event.timestampMs)) {
        return SettleResult.inCooldown;
      }
      return SettleResult.alreadySettled;
    }
    _byKey[event.rewardKey] = SettlementRecord(
      rewardKey: event.rewardKey,
      dialogueId: event.dialogueId,
      pair: event.pair,
      settledAtMs: event.timestampMs,
    );
    return SettleResult.settled;
  }

  @override
  List<SettlementRecord> settlements() {
    return List<SettlementRecord>.unmodifiable(_byKey.values);
  }

  @override
  int settlementCount(String rewardKey) {
    return _byKey.containsKey(rewardKey) ? 1 : 0;
  }

  @override
  bool isWithinCooldown(String rewardKey, int timestampMs) {
    final existing = _byKey[rewardKey];
    if (existing == null) {
      return false;
    }
    return _insideCooldown(existing, timestampMs);
  }

  bool _insideCooldown(SettlementRecord record, int timestampMs) {
    final delta = timestampMs - record.settledAtMs;
    return delta >= 0 && delta < cooldown.inMilliseconds;
  }
}
