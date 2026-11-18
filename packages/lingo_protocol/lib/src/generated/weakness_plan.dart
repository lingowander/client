// Generated from packages/lingo_protocol/schema/*.schema.json.
// Do not edit by hand. Regenerate with:
//
//   python3 packages/lingo_protocol/tool/generate_types.py
//
// CI runs that script with --check and fails when this file is stale.

import 'dart:convert';

import '../decode.dart';
import 'common.dart';
import 'enums.dart';

/// 实例不可变，相等性按字段值比较。
final class WeaknessTarget {
  factory WeaknessTarget({
    required String weaknessId,
    ObservationKind? kind,
    required WeaknessStrategy strategy,
    required int budgetPerScene,
    SceneConstraints? sceneConstraints,
    WeaknessCooldown? cooldown,
  }) {
    checkIdToken(weaknessId, 'weaknessId');
    validateInteger(budgetPerScene, 'budgetPerScene', minimum: 0);
    return WeaknessTarget._(
      weaknessId: weaknessId,
      kind: kind,
      strategy: strategy,
      budgetPerScene: budgetPerScene,
      sceneConstraints: sceneConstraints,
      cooldown: cooldown,
    );
  }

  const WeaknessTarget._({
    required this.weaknessId,
    this.kind,
    required this.strategy,
    required this.budgetPerScene,
    this.sceneConstraints,
    this.cooldown,
  });

  factory WeaknessTarget.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path, const {
      'weakness_id',
      'kind',
      'strategy',
      'budget_per_scene',
      'scene_constraints',
      'cooldown'
    });
    final weaknessId =
        readRequiredString(jsonMap, 'weakness_id', path, check: checkIdToken);
    final kind =
        readOptionalEnum(jsonMap, 'kind', path, ObservationKind.byWire);
    final strategy =
        readRequiredEnum(jsonMap, 'strategy', path, WeaknessStrategy.byWire);
    final budgetPerScene =
        readRequiredInteger(jsonMap, 'budget_per_scene', path, minimum: 0);
    final sceneConstraints = readOptionalModel(
        jsonMap, 'scene_constraints', path, SceneConstraints.fromJson);
    final cooldown =
        readOptionalModel(jsonMap, 'cooldown', path, WeaknessCooldown.fromJson);
    return WeaknessTarget._(
      weaknessId: weaknessId,
      kind: kind,
      strategy: strategy,
      budgetPerScene: budgetPerScene,
      sceneConstraints: sceneConstraints,
      cooldown: cooldown,
    );
  }

  /// 薄弱点 id，例如 w12。
  final String weaknessId;

  /// 可选。薄弱点类别，复用分析观察的四类。语言层数据里有类别，但注入计划示例没有这个字段，所以 v0 可选。
  final ObservationKind? kind;

  /// 注入方式，取自技术方案示例：NPC 复用句式、目标需要、场景道具。不增加显式纠错或测验类取值。
  final WeaknessStrategy strategy;

  /// 这一场允许编织该薄弱点的次数，也就是频次上限。技术方案示例值为 1。v0 不把 1 写成默认值，也不设置上界。
  final int budgetPerScene;

  /// 可选。出现场景约束。技术方案的计划示例没有这个对象；任务需要携带约束，而文档没有定义合法场景列表。v0 只运送已有的 scene id 和 beat
  /// id，不解释它们。
  final SceneConstraints? sceneConstraints;

  /// 可选。冷却。语言层有下次编织时间和复习安排，但没有字段形状，间隔算法也未定。v0 只留一个可选下界，不实现间隔算法。
  final WeaknessCooldown? cooldown;

  Map<String, Object?> toJson() {
    return {
      'weakness_id': weaknessId,
      if (kind != null) 'kind': kind!.wire,
      'strategy': strategy.wire,
      'budget_per_scene': budgetPerScene,
      if (sceneConstraints != null)
        'scene_constraints': sceneConstraints!.toJson(),
      if (cooldown != null) 'cooldown': cooldown!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WeaknessTarget &&
            weaknessId == other.weaknessId &&
            kind == other.kind &&
            strategy == other.strategy &&
            budgetPerScene == other.budgetPerScene &&
            sceneConstraints == other.sceneConstraints &&
            cooldown == other.cooldown;
  }

  @override
  int get hashCode => Object.hashAll([
        weaknessId,
        kind,
        strategy,
        budgetPerScene,
        sceneConstraints,
        cooldown,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class SceneConstraints {
  factory SceneConstraints({
    List<String>? sceneIds,
    List<String>? beatIds,
  }) {
    final frozenSceneIds =
        sceneIds == null ? null : List<String>.unmodifiable(sceneIds);
    if (frozenSceneIds != null) {
      if (frozenSceneIds.isEmpty) {
        throw LingoProtocolException(
            path: 'sceneIds',
            message: '至少需要 1 项，实际有 ${frozenSceneIds.length} 项。');
      }
      for (final item in frozenSceneIds) {
        checkSceneId(item, 'sceneIds');
      }
    }
    final frozenBeatIds =
        beatIds == null ? null : List<String>.unmodifiable(beatIds);
    if (frozenBeatIds != null) {
      if (frozenBeatIds.isEmpty) {
        throw LingoProtocolException(
            path: 'beatIds',
            message: '至少需要 1 项，实际有 ${frozenBeatIds.length} 项。');
      }
      for (final item in frozenBeatIds) {
        checkIdToken(item, 'beatIds');
      }
    }
    final present = <Object?>[
      sceneIds,
      beatIds,
    ].where((item) => item != null).length;
    checkPropertyCount('SceneConstraints', present: present, minProperties: 1);
    return SceneConstraints._(
      sceneIds: frozenSceneIds,
      beatIds: frozenBeatIds,
    );
  }

  const SceneConstraints._({
    this.sceneIds,
    this.beatIds,
  });

  factory SceneConstraints.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path, const {'scene_ids', 'beat_ids'});
    final sceneIds = readOptionalList(jsonMap, 'scene_ids', path,
        (item, itemPath) => readStringItem(item, itemPath, check: checkSceneId),
        minItems: 1);
    final beatIds = readOptionalList(jsonMap, 'beat_ids', path,
        (item, itemPath) => readStringItem(item, itemPath, check: checkIdToken),
        minItems: 1);
    final present = <Object?>[
      sceneIds,
      beatIds,
    ].where((item) => item != null).length;
    checkPropertyCount(path, present: present, minProperties: 1);
    return SceneConstraints._(
      sceneIds: sceneIds,
      beatIds: beatIds,
    );
  }

  /// 允许出现的场景 id，形态为 s_ 加至少四位数字。
  final List<String>? sceneIds;

  /// 允许出现的节拍 id。
  final List<String>? beatIds;

  Map<String, Object?> toJson() {
    return {
      if (sceneIds != null) 'scene_ids': [...sceneIds!],
      if (beatIds != null) 'beat_ids': [...beatIds!],
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SceneConstraints &&
            deepListEquals(sceneIds, other.sceneIds) &&
            deepListEquals(beatIds, other.beatIds);
  }

  @override
  int get hashCode => Object.hashAll([
        deepListHash(sceneIds),
        deepListHash(beatIds),
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class WeaknessCooldown {
  factory WeaknessCooldown({
    required int minScenesBetween,
  }) {
    validateInteger(minScenesBetween, 'minScenesBetween', minimum: 0);
    return WeaknessCooldown._(
      minScenesBetween: minScenesBetween,
    );
  }

  const WeaknessCooldown._({
    required this.minScenesBetween,
  });

  factory WeaknessCooldown.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path, const {'min_scenes_between'});
    final minScenesBetween =
        readRequiredInteger(jsonMap, 'min_scenes_between', path, minimum: 0);
    return WeaknessCooldown._(
      minScenesBetween: minScenesBetween,
    );
  }

  /// 两次编织之间至少隔开的场数。单位用「场」是提案：文档没有规定冷却单位。0 只表示这个整数允许为零，不是产品默认。
  final int minScenesBetween;

  Map<String, Object?> toJson() {
    return {
      'min_scenes_between': minScenesBetween,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WeaknessCooldown && minScenesBetween == other.minScenesBetween;
  }

  @override
  int get hashCode => Object.hashAll([
        minScenesBetween,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 无感薄弱点注入计划，schema_version 0。由编排器代码生成，交给对白提示词。它不是玩家可见文本。纯游戏桶不注入练习；v0 用空的
/// targets 表示这一场没有注入，不另设开关。 实例不可变，相等性按字段值比较。
final class WeaknessPlan {
  factory WeaknessPlan({
    String schemaName = 'weakness_plan',
    int schemaVersion = 0,
    required LanguagePair pair,
    required List<WeaknessTarget> targets,
  }) {
    if (schemaName != 'weakness_plan') {
      throw LingoProtocolException(
          path: 'schemaName',
          message: 'schema_name 必须是 weakness_plan。不认识的取值会被拒绝。');
    }
    if (schemaVersion != 0) {
      throw LingoProtocolException(
          path: 'schemaVersion',
          message:
              'schema_version 必须是 0，实际是 $schemaVersion。不认识的契约版本会被拒绝，不会按别的版本猜测。');
    }
    final frozenTargets = List<WeaknessTarget>.unmodifiable(targets);
    return WeaknessPlan._(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      pair: pair,
      targets: frozenTargets,
    );
  }

  const WeaknessPlan._({
    required this.schemaName,
    required this.schemaVersion,
    required this.pair,
    required this.targets,
  });

  factory WeaknessPlan.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(
        json, path, const {'schema_name', 'schema_version', 'pair', 'targets'});
    final schemaName =
        readConstString(jsonMap, 'schema_name', path, 'weakness_plan');
    final schemaVersion = readConstInt(jsonMap, 'schema_version', path, 0);
    final pair =
        readRequiredModel(jsonMap, 'pair', path, LanguagePair.fromJson);
    final targets = readRequiredList(jsonMap, 'targets', path,
        (item, itemPath) => WeaknessTarget.fromJson(item, path: itemPath));
    return WeaknessPlan._(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      pair: pair,
      targets: targets,
    );
  }

  final String schemaName;

  /// weakness_plan 自己的契约版本，整数，从 0 起独立递增。文档写法 weakness_plan@1 不是这个字段的值。这不是存档迁移版本。
  final int schemaVersion;

  /// 这份计划属于哪一个语言对。技术方案示例没有这个字段，但薄弱档案按语言对分桶，计划必须自描述，避免串桶。src 与 tgt 相同表示纯游戏桶。本载荷不回显
  /// turn_id。
  final LanguagePair pair;

  /// 本场要编织的薄弱点。可以是空数组。schema 不强制学习桶非空，也不强制纯游戏桶为空。
  final List<WeaknessTarget> targets;

  Map<String, Object?> toJson() {
    return {
      'schema_name': schemaName,
      'schema_version': schemaVersion,
      'pair': pair.toJson(),
      'targets': [for (final item in targets) item.toJson()],
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WeaknessPlan &&
            schemaName == other.schemaName &&
            schemaVersion == other.schemaVersion &&
            pair == other.pair &&
            deepListEquals(targets, other.targets);
  }

  @override
  int get hashCode => Object.hashAll([
        schemaName,
        schemaVersion,
        pair,
        deepListHash(targets),
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}
