// SPDX-License-Identifier: GPL-3.0-only

import 'package:dartproptest/dartproptest.dart';
import 'package:lingo_testkit/lingo_testkit.dart';
import 'package:test/test.dart';

import 'generators.dart';

void main() {
  group('不变量（接到 lingo_core 后仍应成立）', () {
    test('任意事件序列里同一个 reward_key 最多结算一次', () {
      forAll(
        (RewardScenario scenario) {
          final ledger = createRewardLedgerUnderTest(
            cooldown: Duration(milliseconds: scenario.cooldownMs),
          );
          checkRewardSequence(ledger, scenario.events);
          return true;
        },
        <Generator<dynamic>>[rewardScenarioGen],
        numRuns: 60,
        seed: '109',
      );
    });

    test('空序列不会产生结算', () {
      forAll(
        (int cooldownMs) {
          final ledger = createRewardLedgerUnderTest(
            cooldown: Duration(milliseconds: cooldownMs),
          );
          if (ledger.settlements().isNotEmpty) {
            throw StateError('空序列出现了结算');
          }
          return true;
        },
        <Generator<dynamic>>[Gen.interval(1, 5000)],
        numRuns: 20,
        seed: '109',
      );
    });
  });

  group('参考实现占位行为（接线到 lingo_core 时删除）', () {
    test('当前工厂返回参考实现，首次观察会入账', () {
      final ledger = createRewardLedgerUnderTest(
        cooldown: const Duration(milliseconds: 50),
      );
      expect(ledger, isA<InMemoryRewardLedger>());
      const event = RewardEvent(
        rewardKey: 'placeholder.reward.a',
        dialogueId: 'placeholder.dialogue.1',
        pair: LanguagePair(source: 'x-a', target: 'x-b'),
        timestampMs: 10,
      );
      expect(ledger.trySettle(event), SettleResult.settled);
      expect(ledger.settlementCount(event.rewardKey), 1);
    });

    test('参考实现没有全局冷却，另一个 key 仍可首次入账', () {
      final ledger = createRewardLedgerUnderTest(
        cooldown: const Duration(milliseconds: 100),
      );
      const first = RewardEvent(
        rewardKey: 'placeholder.reward.a',
        dialogueId: 'placeholder.dialogue.1',
        pair: LanguagePair(source: 'x-a', target: 'x-b'),
        timestampMs: 0,
      );
      const second = RewardEvent(
        rewardKey: 'placeholder.reward.b',
        dialogueId: 'placeholder.dialogue.2',
        pair: LanguagePair(source: 'x-b', target: 'x-c'),
        timestampMs: 1,
      );
      expect(ledger.trySettle(first), SettleResult.settled);
      expect(
        ledger.isWithinCooldown(first.rewardKey, second.timestampMs),
        isTrue,
      );
      expect(ledger.trySettle(second), SettleResult.settled);
      expect(ledger.settlementCount(first.rewardKey), 1);
      expect(ledger.settlementCount(second.rewardKey), 1);
    });
  });
}

/// 可转移到生产实现的检查：不要求“每个事件都发奖”，只要求账本不变量。
void checkRewardSequence(RewardLedger ledger, List<RewardEvent> events) {
  if (ledger.cooldown <= Duration.zero) {
    throw StateError('测试需要正的冷却时长，实际为 ${ledger.cooldown}');
  }
  final seen = <String>{};
  for (final event in events) {
    final before = ledger.settlementCount(event.rewardKey);
    final others = <String, int>{
      for (final key in seen)
        if (key != event.rewardKey) key: ledger.settlementCount(key),
    };
    final result = ledger.trySettle(event);
    final after = ledger.settlementCount(event.rewardKey);
    if (after > 1) {
      throw StateError('reward_key ${event.rewardKey} 结算超过一次');
    }
    if (before == 1 && result == SettleResult.settled) {
      throw StateError('已结算的 ${event.rewardKey} 又结算了一次');
    }
    if (before == 1 && after != 1) {
      throw StateError('拒绝 ${event.rewardKey} 时账本条数变了');
    }
    if (before == 0 && result == SettleResult.settled && after != 1) {
      throw StateError('首次结算后 ${event.rewardKey} 的条数不是 1');
    }
    if (before == 0 && result != SettleResult.settled && after != 0) {
      throw StateError('${event.rewardKey} 未结算却写入了账本');
    }
    if (before == 1) {
      final inCooldown = ledger.isWithinCooldown(
        event.rewardKey,
        event.timestampMs,
      );
      if (inCooldown && result != SettleResult.inCooldown) {
        throw StateError('冷却期内 ${event.rewardKey} 的结果应为 inCooldown');
      }
      if (!inCooldown && result != SettleResult.alreadySettled) {
        throw StateError('冷却期外的重复尝试应为 alreadySettled');
      }
    }
    for (final other in others.entries) {
      if (ledger.settlementCount(other.key) != other.value) {
        throw StateError('${other.key} 的结算次数被其他 key 改写');
      }
    }
    seen.add(event.rewardKey);
  }

  final records = List<SettlementRecord>.of(ledger.settlements());
  for (final record in records) {
    if (ledger.settlementCount(record.rewardKey) != 1) {
      throw StateError('账本里的 ${record.rewardKey} 不是恰好一条');
    }
    probeCooldown(ledger, record);
    probeLanguageReplay(ledger, record);
  }

  for (final event in events) {
    final before = ledger.settlementCount(event.rewardKey);
    final result = ledger.trySettle(event);
    if (result == SettleResult.settled ||
        ledger.settlementCount(event.rewardKey) != before) {
      throw StateError('重玩 ${event.rewardKey} 新增了结算');
    }
  }
}

void probeCooldown(RewardLedger ledger, SettlementRecord record) {
  final window = ledger.cooldown.inMilliseconds;
  final inside = recordAsEvent(record, record.settledAtMs);
  if (ledger.trySettle(inside) != SettleResult.inCooldown) {
    throw StateError('${record.rewardKey} 在冷却起点仍新增或分类错误');
  }
  final outside = recordAsEvent(record, record.settledAtMs + window);
  if (ledger.trySettle(outside) != SettleResult.alreadySettled) {
    throw StateError('${record.rewardKey} 在冷却结束后又结算了一次');
  }
  if (ledger.settlementCount(record.rewardKey) != 1) {
    throw StateError('冷却探针改变了 ${record.rewardKey} 的条数');
  }
}

void probeLanguageReplay(RewardLedger ledger, SettlementRecord record) {
  final switched = RewardEvent(
    rewardKey: record.rewardKey,
    dialogueId: record.dialogueId,
    pair: LanguagePair(
      source: record.pair.source,
      target: record.pair.target == 'x-a' ? 'x-b' : 'x-a',
    ),
    timestampMs: record.settledAtMs + ledger.cooldown.inMilliseconds + 1,
  );
  if (ledger.trySettle(switched) == SettleResult.settled) {
    throw StateError('换语言重放同一对白又结算了 ${record.rewardKey}');
  }
  if (ledger.settlementCount(record.rewardKey) != 1) {
    throw StateError('换语言重放改变了 ${record.rewardKey} 的条数');
  }
}

RewardEvent recordAsEvent(SettlementRecord record, int timestampMs) {
  return RewardEvent(
    rewardKey: record.rewardKey,
    dialogueId: record.dialogueId,
    pair: record.pair,
    timestampMs: timestampMs,
  );
}
