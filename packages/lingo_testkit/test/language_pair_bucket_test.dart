// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Lingowander
//
// 语遇 Lingowander 客户端的一部分。
// 本文件以 GNU General Public License v3.0 授权（仅此版本）。
// 完整文本见仓库根目录 LICENSE。

import 'package:dartproptest/dartproptest.dart';
import 'package:lingo_testkit/lingo_testkit.dart';
import 'package:test/test.dart';

import 'generators.dart';

const LanguagePair absentPure = LanguagePair(
  source: 'x-none',
  target: 'x-none',
);
const LanguagePair absentLearning = LanguagePair(
  source: 'x-none',
  target: 'x-else',
);

void main() {
  group('不变量（接到 lingo_core 后仍应成立）', () {
    test('任意语言切换序列按语言对分桶，纯游戏不产生档案', () {
      forAll(
        (List<LearningSignal> signals) {
          checkIsolation(signals);
          return true;
        },
        <Generator<dynamic>>[learningSequenceGen],
        numRuns: 60,
        seed: '109',
      );
    });

    test('切到其他语言对再切回时，原桶状态延续', () {
      forAll(
        (SwitchBackScenario scenario) {
          checkSwitchBack(scenario);
          return true;
        },
        <Generator<dynamic>>[switchBackGen],
        numRuns: 40,
        seed: '109',
      );
    });
  });

  group('参考实现占位行为（接线到 lingo_core 时删除）', () {
    test('当前工厂返回按标记追加的参考存储', () {
      final store = createLearningProfileStoreUnderTest();
      expect(store, isA<InMemoryLearningProfileStore>());
      const pair = LanguagePair(source: 'x-a', target: 'x-b');
      store.apply(
        const LearningSignal(pair: pair, marker: 'placeholder.marker.1'),
      );
      expect(
        store.snapshotFor(pair),
        ProfileSnapshot(const <String>['placeholder.marker.1']),
      );
    });
  });
}

void checkIsolation(List<LearningSignal> signals) {
  final full = createLearningProfileStoreUnderTest();
  for (final signal in signals) {
    full.apply(signal);
  }

  final pairs = <LanguagePair>{
    absentPure,
    absentLearning,
    for (final signal in signals) signal.pair,
  };
  for (final pair in pairs) {
    final onlyThisPair = createLearningProfileStoreUnderTest();
    for (final signal in signals) {
      if (signal.pair == pair && !pair.isPureGame) {
        onlyThisPair.apply(signal);
      }
    }
    if (full.snapshotFor(pair) != onlyThisPair.snapshotFor(pair)) {
      throw StateError('语言对 $pair 受到了其他桶的影响');
    }
    if (pair.isPureGame && full.snapshotFor(pair) != null) {
      throw StateError('纯游戏语言对 $pair 产生了学习档案');
    }
  }

  final withoutPure = createLearningProfileStoreUnderTest();
  for (final signal in signals.where((signal) => !signal.pair.isPureGame)) {
    withoutPure.apply(signal);
  }
  for (final pair in pairs) {
    if (full.snapshotFor(pair) != withoutPure.snapshotFor(pair)) {
      throw StateError('纯游戏输入改变了 $pair 的档案');
    }
  }
}

void checkSwitchBack(SwitchBackScenario scenario) {
  if (scenario.home.isPureGame || scenario.home == scenario.away) {
    throw StateError('生成器给出的 home/away 不符合切回场景：$scenario');
  }
  final store = createLearningProfileStoreUnderTest();
  for (final signal in scenario.homePrefix) {
    store.apply(signal);
  }
  final afterPrefix = store.snapshotFor(scenario.home);

  for (final signal in scenario.awaySignals) {
    store.apply(signal);
  }
  for (final signal in scenario.pureNoise) {
    store.apply(signal);
  }
  if (store.snapshotFor(scenario.home) != afterPrefix) {
    throw StateError('离开 ${scenario.home} 后原桶被改写');
  }
  if (scenario.pureNoise.isNotEmpty &&
      store.snapshotFor(scenario.pureNoise.first.pair) != null) {
    throw StateError('纯游戏噪声产生了学习档案');
  }

  for (final signal in scenario.homeSuffix) {
    store.apply(signal);
  }

  final onlyHome = createLearningProfileStoreUnderTest();
  for (final signal in <LearningSignal>[
    ...scenario.homePrefix,
    ...scenario.homeSuffix,
  ]) {
    onlyHome.apply(signal);
  }
  if (store.snapshotFor(scenario.home) != onlyHome.snapshotFor(scenario.home)) {
    throw StateError('切回 ${scenario.home} 时没有延续该桶');
  }

  final onlyAway = createLearningProfileStoreUnderTest();
  for (final signal in scenario.awaySignals) {
    onlyAway.apply(signal);
  }
  if (store.snapshotFor(scenario.away) != onlyAway.snapshotFor(scenario.away)) {
    throw StateError('${scenario.away} 混入了其他语言对的状态');
  }
}
