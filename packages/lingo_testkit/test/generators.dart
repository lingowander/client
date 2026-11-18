// SPDX-License-Identifier: GPL-3.0-only

import 'package:dartproptest/dartproptest.dart';
import 'package:lingo_testkit/lingo_testkit.dart';

/// 生成器只制造占位事件，不实现发奖或画像规则。

const List<String> placeholderLanguages = <String>['x-a', 'x-b', 'x-c'];

final Generator<String> languageGen = Gen.elementOf<String>(
  placeholderLanguages,
);

final Generator<LanguagePair> languagePairGen = Gen.construct<LanguagePair>(
  (args) => LanguagePair(source: args[0] as String, target: args[1] as String),
  <Generator<dynamic>>[languageGen, languageGen],
);

final Generator<RewardEvent> rewardEventGen = Gen.construct<RewardEvent>(
  (args) => RewardEvent(
    rewardKey: args[0] as String,
    dialogueId: args[1] as String,
    pair: args[2] as LanguagePair,
    timestampMs: args[3] as int,
  ),
  <Generator<dynamic>>[
    Gen.elementOf<String>(const <String>[
      'placeholder.reward.a',
      'placeholder.reward.b',
      'placeholder.reward.c',
    ]),
    Gen.elementOf<String>(const <String>[
      'placeholder.dialogue.1',
      'placeholder.dialogue.2',
      'placeholder.dialogue.3',
    ]),
    languagePairGen,
    Gen.interval(0, 20000),
  ],
);

/// 一条已经掺入重复、乱序、换语言重放和整段重玩的事件序列。
final class RewardScenario {
  const RewardScenario({required this.cooldownMs, required this.events});

  final int cooldownMs;
  final List<RewardEvent> events;

  @override
  String toString() {
    return 'RewardScenario(cooldownMs: $cooldownMs, events: $events)';
  }
}

final Generator<RewardScenario> rewardScenarioGen =
    Gen.construct<RewardScenario>(
      (args) => expandRewardScenario(
        cooldownMs: args[0] as int,
        base: (args[1] as List).cast<RewardEvent>(),
        rotateBy: args[2] as int,
        switchTarget: args[3] as String,
      ),
      <Generator<dynamic>>[
        Gen.interval(1, 5000),
        Gen.array<RewardEvent>(rewardEventGen, minLength: 1, maxLength: 6),
        Gen.interval(0, 30),
        languageGen,
      ],
    );

/// 把任意底稿扩成任务要求覆盖的形状：重复、乱序、换语言重放、整段重玩。
RewardScenario expandRewardScenario({
  required int cooldownMs,
  required List<RewardEvent> base,
  required int rotateBy,
  required String switchTarget,
}) {
  final events = List<RewardEvent>.of(base);
  final head = events.first;
  events.add(head);
  final switchedTarget = switchTarget == head.pair.target
      ? 'x-other'
      : switchTarget;
  events.add(
    head.copyWith(
      pair: LanguagePair(source: head.pair.source, target: switchedTarget),
      timestampMs: head.timestampMs + rotateBy,
    ),
  );
  final rotation = rotateBy % events.length;
  final shuffled = <RewardEvent>[
    ...events.sublist(rotation),
    ...events.sublist(0, rotation),
  ];
  final replay = shuffled
      .map((event) => event.copyWith(timestampMs: event.timestampMs + 100000))
      .toList();
  return RewardScenario(
    cooldownMs: cooldownMs,
    events: <RewardEvent>[...shuffled, ...replay],
  );
}

final Generator<LearningSignal> learningSignalGen =
    Gen.construct<LearningSignal>(
      (args) => LearningSignal(
        pair: args[0] as LanguagePair,
        marker: 'placeholder.marker.${args[1]}',
      ),
      <Generator<dynamic>>[languagePairGen, Gen.interval(0, 999)],
    );

final Generator<List<LearningSignal>> learningSequenceGen =
    Gen.array<LearningSignal>(learningSignalGen, minLength: 0, maxLength: 12);

/// 切走再切回的一段占位序列。home 始终不是纯游戏对。
final class SwitchBackScenario {
  const SwitchBackScenario({
    required this.home,
    required this.away,
    required this.homePrefix,
    required this.awaySignals,
    required this.pureNoise,
    required this.homeSuffix,
  });

  final LanguagePair home;
  final LanguagePair away;
  final List<LearningSignal> homePrefix;
  final List<LearningSignal> awaySignals;
  final List<LearningSignal> pureNoise;
  final List<LearningSignal> homeSuffix;

  @override
  String toString() {
    return 'SwitchBack(home: $home, away: $away, '
        'prefix: $homePrefix, away: $awaySignals, '
        'pure: $pureNoise, suffix: $homeSuffix)';
  }
}

final Generator<SwitchBackScenario> switchBackGen =
    Gen.construct<SwitchBackScenario>(
      (args) {
        final home = nonPurePair(args[0] as String, args[1] as String);
        final away = differentPair(home, args[2] as String, args[3] as String);
        return SwitchBackScenario(
          home: home,
          away: away,
          homePrefix: signalsFor(home, (args[4] as List).cast<int>()),
          awaySignals: signalsFor(away, (args[5] as List).cast<int>()),
          pureNoise: signalsFor(
            LanguagePair(source: args[6] as String, target: args[6] as String),
            (args[7] as List).cast<int>(),
          ),
          homeSuffix: signalsFor(home, (args[8] as List).cast<int>()),
        );
      },
      <Generator<dynamic>>[
        languageGen,
        languageGen,
        languageGen,
        languageGen,
        Gen.array<int>(Gen.interval(0, 50), minLength: 0, maxLength: 4),
        Gen.array<int>(Gen.interval(0, 50), minLength: 0, maxLength: 4),
        languageGen,
        Gen.array<int>(Gen.interval(0, 50), minLength: 0, maxLength: 3),
        Gen.array<int>(Gen.interval(0, 50), minLength: 0, maxLength: 4),
      ],
    );

LanguagePair nonPurePair(String source, String target) {
  if (source != target) {
    return LanguagePair(source: source, target: target);
  }
  return LanguagePair(source: source, target: source == 'x-a' ? 'x-b' : 'x-a');
}

LanguagePair differentPair(LanguagePair home, String source, String target) {
  final candidate = nonPurePair(source, target);
  if (candidate != home) {
    return candidate;
  }
  return LanguagePair(source: home.target, target: home.source);
}

List<LearningSignal> signalsFor(LanguagePair pair, List<int> marks) {
  return <LearningSignal>[
    for (final mark in marks)
      LearningSignal(pair: pair, marker: 'placeholder.marker.$mark'),
  ];
}
