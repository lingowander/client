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
final class Observation {
  factory Observation({
    required ObservationKind kind,
    required String descriptor,
    required String evidenceSpan,
    required double severity,
  }) {
    checkIdToken(descriptor, 'descriptor');
    validateString(evidenceSpan, 'evidenceSpan', minLength: 1);
    checkUnitInterval(severity, 'severity');
    return Observation._(
      kind: kind,
      descriptor: descriptor,
      evidenceSpan: evidenceSpan,
      severity: severity,
    );
  }

  const Observation._({
    required this.kind,
    required this.descriptor,
    required this.evidenceSpan,
    required this.severity,
  });

  factory Observation.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(
        json, path, const {'kind', 'descriptor', 'evidence_span', 'severity'});
    final kind =
        readRequiredEnum(jsonMap, 'kind', path, ObservationKind.byWire);
    final descriptor =
        readRequiredString(jsonMap, 'descriptor', path, check: checkIdToken);
    final evidenceSpan =
        readRequiredString(jsonMap, 'evidence_span', path, minLength: 1);
    final severity =
        readRequiredNumber(jsonMap, 'severity', path, check: checkUnitInterval);
    return Observation._(
      kind: kind,
      descriptor: descriptor,
      evidenceSpan: evidenceSpan,
      severity: severity,
    );
  }

  /// 回合后分析的观察类别，取自技术方案 turn_analysis 示例。pronunciation 能否拿到证据，文档写明尚待核实，v0
  /// 仍保留这个枚举值。
  final ObservationKind kind;

  /// 观察条目，例如 article_omission。方案页希望使用受控词表，但词表尚未给出，所以 v0 只限制标识形态，不收成枚举。
  final String descriptor;

  /// 支撑这条观察的玩家原话片段。分析载荷不是玩家界面。
  final String evidenceSpan;

  /// 程度。技术方案示例为 0.3。不向玩家展示，schema 也不把它解释成对或错。
  final double severity;

  Map<String, Object?> toJson() {
    return {
      'kind': kind.wire,
      'descriptor': descriptor,
      'evidence_span': evidenceSpan,
      'severity': severity,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Observation &&
            kind == other.kind &&
            descriptor == other.descriptor &&
            evidenceSpan == other.evidenceSpan &&
            severity == other.severity;
  }

  @override
  int get hashCode => Object.hashAll([
        kind,
        descriptor,
        evidenceSpan,
        severity,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class LevelEvidence {
  factory LevelEvidence({
    required double production,
    required double comprehension,
  }) {
    checkUnitInterval(production, 'production');
    checkUnitInterval(comprehension, 'comprehension');
    return LevelEvidence._(
      production: production,
      comprehension: comprehension,
    );
  }

  const LevelEvidence._({
    required this.production,
    required this.comprehension,
  });

  factory LevelEvidence.fromJson(Object? json, {String path = ''}) {
    final jsonMap =
        readObject(json, path, const {'production', 'comprehension'});
    final production = readRequiredNumber(jsonMap, 'production', path,
        check: checkUnitInterval);
    final comprehension = readRequiredNumber(jsonMap, 'comprehension', path,
        check: checkUnitInterval);
    return LevelEvidence._(
      production: production,
      comprehension: comprehension,
    );
  }

  /// 产出方面的隐式水平信号。文档把 production 和 comprehension 标为示例维度，量表是否对齐外部标准尚未决定。v0
  /// 为了能生成固定结构，只收这两个必填字段；增加维度需要新的 schema_version。
  final double production;

  /// 理解方面的隐式水平信号。同 production，不向玩家展示。
  final double comprehension;

  Map<String, Object?> toJson() {
    return {
      'production': production,
      'comprehension': comprehension,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LevelEvidence &&
            production == other.production &&
            comprehension == other.comprehension;
  }

  @override
  int get hashCode => Object.hashAll([
        production,
        comprehension,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class EngagementSignals {
  factory EngagementSignals({
    required int turnLength,
    required double choiceDiversity,
  }) {
    validateInteger(turnLength, 'turnLength', minimum: 0);
    checkUnitInterval(choiceDiversity, 'choiceDiversity');
    return EngagementSignals._(
      turnLength: turnLength,
      choiceDiversity: choiceDiversity,
    );
  }

  const EngagementSignals._({
    required this.turnLength,
    required this.choiceDiversity,
  });

  factory EngagementSignals.fromJson(Object? json, {String path = ''}) {
    final jsonMap =
        readObject(json, path, const {'turn_length', 'choice_diversity'});
    final turnLength =
        readRequiredInteger(jsonMap, 'turn_length', path, minimum: 0);
    final choiceDiversity = readRequiredNumber(
        jsonMap, 'choice_diversity', path,
        check: checkUnitInterval);
    return EngagementSignals._(
      turnLength: turnLength,
      choiceDiversity: choiceDiversity,
    );
  }

  /// 本回合玩家输入的长度信号。技术方案示例为 0。文档没有写单位，v0 不规定是字符数还是词数。
  final int turnLength;

  /// 选项多样性信号。技术方案示例为 0.0。不向玩家展示。
  final double choiceDiversity;

  Map<String, Object?> toJson() {
    return {
      'turn_length': turnLength,
      'choice_diversity': choiceDiversity,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EngagementSignals &&
            turnLength == other.turnLength &&
            choiceDiversity == other.choiceDiversity;
  }

  @override
  int get hashCode => Object.hashAll([
        turnLength,
        choiceDiversity,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 回合后分析，schema_version 0。由廉价模型异步产出，不在对白的关键路径上。结果按语言对分桶，不向玩家展示，也不要写成分数、错题或等级。
/// 实例不可变，相等性按字段值比较。
final class TurnAnalysis {
  factory TurnAnalysis({
    String schemaName = 'turn_analysis',
    int schemaVersion = 0,
    required String turnId,
    required LanguagePair pair,
    required bool intentSuccess,
    required List<Observation> observations,
    required LevelEvidence levelEvidence,
    required EngagementSignals engagementSignals,
    double? analysisConfidence,
  }) {
    if (schemaName != 'turn_analysis') {
      throw LingoProtocolException(
          path: 'schemaName',
          message: 'schema_name 必须是 turn_analysis。不认识的取值会被拒绝。');
    }
    if (schemaVersion != 0) {
      throw LingoProtocolException(
          path: 'schemaVersion',
          message:
              'schema_version 必须是 0，实际是 $schemaVersion。不认识的契约版本会被拒绝，不会按别的版本猜测。');
    }
    checkTurnId(turnId, 'turnId');
    final frozenObservations = List<Observation>.unmodifiable(observations);
    if (analysisConfidence != null) {
      checkUnitInterval(analysisConfidence, 'analysisConfidence');
    }
    return TurnAnalysis._(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      turnId: turnId,
      pair: pair,
      intentSuccess: intentSuccess,
      observations: frozenObservations,
      levelEvidence: levelEvidence,
      engagementSignals: engagementSignals,
      analysisConfidence: analysisConfidence,
    );
  }

  const TurnAnalysis._({
    required this.schemaName,
    required this.schemaVersion,
    required this.turnId,
    required this.pair,
    required this.intentSuccess,
    required this.observations,
    required this.levelEvidence,
    required this.engagementSignals,
    this.analysisConfidence,
  });

  factory TurnAnalysis.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path, const {
      'schema_name',
      'schema_version',
      'turn_id',
      'pair',
      'intent_success',
      'observations',
      'level_evidence',
      'engagement_signals',
      'analysis_confidence'
    });
    final schemaName =
        readConstString(jsonMap, 'schema_name', path, 'turn_analysis');
    final schemaVersion = readConstInt(jsonMap, 'schema_version', path, 0);
    final turnId =
        readRequiredString(jsonMap, 'turn_id', path, check: checkTurnId);
    final pair =
        readRequiredModel(jsonMap, 'pair', path, LanguagePair.fromJson);
    final intentSuccess = readRequiredBool(jsonMap, 'intent_success', path);
    final observations = readRequiredList(jsonMap, 'observations', path,
        (item, itemPath) => Observation.fromJson(item, path: itemPath));
    final levelEvidence = readRequiredModel(
        jsonMap, 'level_evidence', path, LevelEvidence.fromJson);
    final engagementSignals = readRequiredModel(
        jsonMap, 'engagement_signals', path, EngagementSignals.fromJson);
    final analysisConfidence = readOptionalNumber(
        jsonMap, 'analysis_confidence', path,
        check: checkUnitInterval);
    return TurnAnalysis._(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      turnId: turnId,
      pair: pair,
      intentSuccess: intentSuccess,
      observations: observations,
      levelEvidence: levelEvidence,
      engagementSignals: engagementSignals,
      analysisConfidence: analysisConfidence,
    );
  }

  final String schemaName;

  /// turn_analysis 自己的契约版本，整数，从 0 起独立递增。文档写法 turn_analysis@1 不是这个字段的值。这不是存档迁移版本。
  final int schemaVersion;

  /// 回合 id。由客户端生成，放进请求，用于幂等和重放。turn_output 与 turn_analysis 必须回显同一个值。weakness_plan
  /// 不是单回合模型回显，不带这个字段。
  final String turnId;

  /// 这条分析属于哪一个语言对。分桶用对象，不用 zh>en 字符串。
  final LanguagePair pair;

  /// 玩家这一回合的沟通意图是否达成。这是沟通结果，不是语言水平分，也不向玩家展示。
  final bool intentSuccess;

  /// 对玩家输入的语言观察。错误点，以及词汇或语法上被注意到的条目，都放在这里：kind 为 grammar 或 lexical
  /// 即词汇/语法相关，descriptor 是条目名。文档没有单独的命中列表，也没有正负极性，v0 不另加字段。可以是空数组。
  final List<Observation> observations;

  final LevelEvidence levelEvidence;

  final EngagementSignals engagementSignals;

  /// 可选。模型对本条分析的置信度。方案页提案：低置信度时只更新、不注入。具体阈值文档未定，schema 不编码阈值。
  final double? analysisConfidence;

  Map<String, Object?> toJson() {
    return {
      'schema_name': schemaName,
      'schema_version': schemaVersion,
      'turn_id': turnId,
      'pair': pair.toJson(),
      'intent_success': intentSuccess,
      'observations': [for (final item in observations) item.toJson()],
      'level_evidence': levelEvidence.toJson(),
      'engagement_signals': engagementSignals.toJson(),
      if (analysisConfidence != null)
        'analysis_confidence': analysisConfidence!,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TurnAnalysis &&
            schemaName == other.schemaName &&
            schemaVersion == other.schemaVersion &&
            turnId == other.turnId &&
            pair == other.pair &&
            intentSuccess == other.intentSuccess &&
            deepListEquals(observations, other.observations) &&
            levelEvidence == other.levelEvidence &&
            engagementSignals == other.engagementSignals &&
            analysisConfidence == other.analysisConfidence;
  }

  @override
  int get hashCode => Object.hashAll([
        schemaName,
        schemaVersion,
        turnId,
        pair,
        intentSuccess,
        deepListHash(observations),
        levelEvidence,
        engagementSignals,
        analysisConfidence,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}
