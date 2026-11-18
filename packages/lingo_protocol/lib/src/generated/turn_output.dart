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
final class TurnLine {
  factory TurnLine({
    required String lineId,
    required String lang,
    required String text,
    required TurnLineExpression expression,
    String? translation,
  }) {
    checkIdToken(lineId, 'lineId');
    checkLanguageCode(lang, 'lang');
    validateString(text, 'text', minLength: 1);
    if (translation != null) {
      validateString(translation, 'translation', minLength: 1);
    }
    return TurnLine._(
      lineId: lineId,
      lang: lang,
      text: text,
      expression: expression,
      translation: translation,
    );
  }

  const TurnLine._({
    required this.lineId,
    required this.lang,
    required this.text,
    required this.expression,
    this.translation,
  });

  factory TurnLine.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path,
        const {'line_id', 'lang', 'text', 'expression', 'translation'});
    final lineId =
        readRequiredString(jsonMap, 'line_id', path, check: checkIdToken);
    final lang =
        readRequiredString(jsonMap, 'lang', path, check: checkLanguageCode);
    final text = readRequiredString(jsonMap, 'text', path, minLength: 1);
    final expression = readRequiredEnum(
        jsonMap, 'expression', path, TurnLineExpression.byWire);
    final translation =
        readOptionalString(jsonMap, 'translation', path, minLength: 1);
    return TurnLine._(
      lineId: lineId,
      lang: lang,
      text: text,
      expression: expression,
      translation: translation,
    );
  }

  /// 台词 id，供 proposed_events.evidence_line_ids 引用。方案页提案，v0 必填。
  final String lineId;

  /// 这句 text 的语言。
  final String lang;

  /// 玩家可见的台词。学习回合里这是目标语文本。
  final String text;

  /// 本句的表情标签，同时给立绘使用。提案，待评审。技术方案示例在台词上写了 emotion=warm，在 image_requests 上写了
  /// expression=smile，两处不一致，而且文档没有已定的表情枚举（表情数量待美术确定）。v0 只保留这一个表情字段，不再设置
  /// emotion。warm 不是合法值。代码如何把枚举映射到立绘资源键，不在本 schema 里。
  final TurnLineExpression expression;

  /// 可选，不在 required 里。待定：译文由谁生成。省略表示本句不带译文。不另设译文语言字段。
  final String? translation;

  Map<String, Object?> toJson() {
    return {
      'line_id': lineId,
      'lang': lang,
      'text': text,
      'expression': expression.wire,
      if (translation != null) 'translation': translation!,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TurnLine &&
            lineId == other.lineId &&
            lang == other.lang &&
            text == other.text &&
            expression == other.expression &&
            translation == other.translation;
  }

  @override
  int get hashCode => Object.hashAll([
        lineId,
        lang,
        text,
        expression,
        translation,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class TurnChoice {
  factory TurnChoice({
    required String id,
    required String lang,
    required String text,
    required String intent,
  }) {
    checkIdToken(id, 'id');
    checkLanguageCode(lang, 'lang');
    validateString(text, 'text', minLength: 1);
    checkIdToken(intent, 'intent');
    return TurnChoice._(
      id: id,
      lang: lang,
      text: text,
      intent: intent,
    );
  }

  const TurnChoice._({
    required this.id,
    required this.lang,
    required this.text,
    required this.intent,
  });

  factory TurnChoice.fromJson(Object? json, {String path = ''}) {
    final jsonMap =
        readObject(json, path, const {'id', 'lang', 'text', 'intent'});
    final id = readRequiredString(jsonMap, 'id', path, check: checkIdToken);
    final lang =
        readRequiredString(jsonMap, 'lang', path, check: checkLanguageCode);
    final text = readRequiredString(jsonMap, 'text', path, minLength: 1);
    final intent =
        readRequiredString(jsonMap, 'intent', path, check: checkIdToken);
    return TurnChoice._(
      id: id,
      lang: lang,
      text: text,
      intent: intent,
    );
  }

  /// 小写标识。用于角色、台词、选项、节拍、薄弱点、语义键、descriptor、intent、prompt_id
  /// 和镜头标签。不是封闭词表。turn_id、profile_id、event_id 和 scene_id 不用这个形态。
  final String id;

  /// 选项文本的语言。技术方案示例没有这个字段，方案页提案补上。v0 在选项对象里定为必填，因为选项和台词一样是玩家可见文本。
  final String lang;

  /// 玩家可见的选项文本。
  final String text;

  /// 选项意图标签，例如 order_drink。不是封闭词表。
  final String intent;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'lang': lang,
      'text': text,
      'intent': intent,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TurnChoice &&
            id == other.id &&
            lang == other.lang &&
            text == other.text &&
            intent == other.intent;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        lang,
        text,
        intent,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class SceneState {
  factory SceneState({
    required String beatId,
    String? nextBeatHint,
    required GoalProgress goalProgress,
    required double tension,
  }) {
    checkIdToken(beatId, 'beatId');
    if (nextBeatHint != null) {
      checkIdToken(nextBeatHint, 'nextBeatHint');
    }
    checkUnitInterval(tension, 'tension');
    return SceneState._(
      beatId: beatId,
      nextBeatHint: nextBeatHint,
      goalProgress: goalProgress,
      tension: tension,
    );
  }

  const SceneState._({
    required this.beatId,
    this.nextBeatHint,
    required this.goalProgress,
    required this.tension,
  });

  factory SceneState.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path,
        const {'beat_id', 'next_beat_hint', 'goal_progress', 'tension'});
    final beatId =
        readRequiredString(jsonMap, 'beat_id', path, check: checkIdToken);
    final nextBeatHint = readOptionalString(jsonMap, 'next_beat_hint', path,
        check: checkIdToken);
    final goalProgress =
        readRequiredEnum(jsonMap, 'goal_progress', path, GoalProgress.byWire);
    final tension =
        readRequiredNumber(jsonMap, 'tension', path, check: checkUnitInterval);
    return SceneState._(
      beatId: beatId,
      nextBeatHint: nextBeatHint,
      goalProgress: goalProgress,
      tension: tension,
    );
  }

  /// 当前节拍 id。
  final String beatId;

  /// 可选。模型建议的下一节拍。是否转场由代码决定。方案页提案。
  final String? nextBeatHint;

  /// 本场目标推进，取自技术方案示例。
  final GoalProgress goalProgress;

  /// 场面张力。示例值为 0.4。不向玩家展示。
  final double tension;

  Map<String, Object?> toJson() {
    return {
      'beat_id': beatId,
      if (nextBeatHint != null) 'next_beat_hint': nextBeatHint!,
      'goal_progress': goalProgress.wire,
      'tension': tension,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SceneState &&
            beatId == other.beatId &&
            nextBeatHint == other.nextBeatHint &&
            goalProgress == other.goalProgress &&
            tension == other.tension;
  }

  @override
  int get hashCode => Object.hashAll([
        beatId,
        nextBeatHint,
        goalProgress,
        tension,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class ProposedEvent {
  factory ProposedEvent({
    required String eventKey,
    List<String>? evidenceLineIds,
    required String evidence,
  }) {
    checkEventKey(eventKey, 'eventKey');
    final frozenEvidenceLineIds = evidenceLineIds == null
        ? null
        : List<String>.unmodifiable(evidenceLineIds);
    if (frozenEvidenceLineIds != null) {
      for (final item in frozenEvidenceLineIds) {
        checkIdToken(item, 'evidenceLineIds');
      }
    }
    validateString(evidence, 'evidence', minLength: 1);
    return ProposedEvent._(
      eventKey: eventKey,
      evidenceLineIds: frozenEvidenceLineIds,
      evidence: evidence,
    );
  }

  const ProposedEvent._({
    required this.eventKey,
    this.evidenceLineIds,
    required this.evidence,
  });

  factory ProposedEvent.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(
        json, path, const {'event_key', 'evidence_line_ids', 'evidence'});
    final eventKey =
        readRequiredString(jsonMap, 'event_key', path, check: checkEventKey);
    final evidenceLineIds = readOptionalList(
        jsonMap,
        'evidence_line_ids',
        path,
        (item, itemPath) =>
            readStringItem(item, itemPath, check: checkIdToken));
    final evidence =
        readRequiredString(jsonMap, 'evidence', path, minLength: 1);
    return ProposedEvent._(
      eventKey: eventKey,
      evidenceLineIds: evidenceLineIds,
      evidence: evidence,
    );
  }

  /// 故事事件键，至少两段、用点分开，例如 cafe.remembered_order。这不是
  /// event_id。是否落在本场允许结算的事件键里，由代码做后续语义校验，不在本 schema 里列白名单。
  final String eventKey;

  /// 可选。支撑这条提议的台词 id。方案页提案。schema 不要求这些 id 一定出现在 lines 里。
  final List<String>? evidenceLineIds;

  /// 提议这条事件的依据。不是玩家可见文本。
  final String evidence;

  Map<String, Object?> toJson() {
    return {
      'event_key': eventKey,
      if (evidenceLineIds != null) 'evidence_line_ids': [...evidenceLineIds!],
      'evidence': evidence,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProposedEvent &&
            eventKey == other.eventKey &&
            deepListEquals(evidenceLineIds, other.evidenceLineIds) &&
            evidence == other.evidence;
  }

  @override
  int get hashCode => Object.hashAll([
        eventKey,
        deepListHash(evidenceLineIds),
        evidence,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class ImageRequest {
  factory ImageRequest({
    required ImageSlot slot,
    required ImagePriority priority,
    String? npcId,
    String? semanticKey,
    String? camera,
  }) {
    if (npcId != null) {
      checkIdToken(npcId, 'npcId');
    }
    if (semanticKey != null) {
      checkIdToken(semanticKey, 'semanticKey');
    }
    if (camera != null) {
      checkIdToken(camera, 'camera');
    }
    return ImageRequest._(
      slot: slot,
      priority: priority,
      npcId: npcId,
      semanticKey: semanticKey,
      camera: camera,
    );
  }

  const ImageRequest._({
    required this.slot,
    required this.priority,
    this.npcId,
    this.semanticKey,
    this.camera,
  });

  factory ImageRequest.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path,
        const {'slot', 'priority', 'npc_id', 'semantic_key', 'camera'});
    final slot = readRequiredEnum(jsonMap, 'slot', path, ImageSlot.byWire);
    final priority =
        readRequiredEnum(jsonMap, 'priority', path, ImagePriority.byWire);
    final npcId =
        readOptionalString(jsonMap, 'npc_id', path, check: checkIdToken);
    final semanticKey =
        readOptionalString(jsonMap, 'semantic_key', path, check: checkIdToken);
    final camera =
        readOptionalString(jsonMap, 'camera', path, check: checkIdToken);
    return ImageRequest._(
      slot: slot,
      priority: priority,
      npcId: npcId,
      semanticKey: semanticKey,
      camera: camera,
    );
  }

  /// 槽位类型：背景、立绘、关键 CG。取自技术方案示例和图像管线说明。这里的 expression 是槽位种类，不是表情取值；表情取值只在
  /// lines[].expression。
  final ImageSlot slot;

  /// 优先级。技术方案示例只有 low 和 normal，v0 不另加取值。
  final ImagePriority priority;

  /// 相关角色。技术方案示例里的字段名是 npc，数据模型用 npc_id。v0 用 npc_id。立绘槽位预期会带它，但 schema 不对槽位做条件必填。
  final String? npcId;

  /// 资产语义键。技术方案示例里的字段名是 key，资产库字段是 semantic_key。v0 用 semantic_key。背景和 CG 预期会带它。
  final String? semanticKey;

  /// 可选镜头标签。图像管线说明 image_requests 包含镜头，但没有词表，示例里也没有具体取值。v0 只限制标识形态，不枚举景别。
  final String? camera;

  Map<String, Object?> toJson() {
    return {
      'slot': slot.wire,
      'priority': priority.wire,
      if (npcId != null) 'npc_id': npcId!,
      if (semanticKey != null) 'semantic_key': semanticKey!,
      if (camera != null) 'camera': camera!,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ImageRequest &&
            slot == other.slot &&
            priority == other.priority &&
            npcId == other.npcId &&
            semanticKey == other.semanticKey &&
            camera == other.camera;
  }

  @override
  int get hashCode => Object.hashAll([
        slot,
        priority,
        npcId,
        semanticKey,
        camera,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class MemoryNote {
  factory MemoryNote({
    required MemoryKind kind,
    required String text,
    required List<String> entities,
    double? confidence,
  }) {
    validateString(text, 'text', minLength: 1);
    final frozenEntities = List<String>.unmodifiable(entities);
    for (final item in frozenEntities) {
      checkIdToken(item, 'entities');
    }
    if (confidence != null) {
      checkUnitInterval(confidence, 'confidence');
    }
    return MemoryNote._(
      kind: kind,
      text: text,
      entities: frozenEntities,
      confidence: confidence,
    );
  }

  const MemoryNote._({
    required this.kind,
    required this.text,
    required this.entities,
    this.confidence,
  });

  factory MemoryNote.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(
        json, path, const {'kind', 'text', 'entities', 'confidence'});
    final kind = readRequiredEnum(jsonMap, 'kind', path, MemoryKind.byWire);
    final text = readRequiredString(jsonMap, 'text', path, minLength: 1);
    final entities = readRequiredList(
        jsonMap,
        'entities',
        path,
        (item, itemPath) =>
            readStringItem(item, itemPath, check: checkIdToken));
    final confidence = readOptionalNumber(jsonMap, 'confidence', path,
        check: checkUnitInterval);
    return MemoryNote._(
      kind: kind,
      text: text,
      entities: entities,
      confidence: confidence,
    );
  }

  /// 笔记种类。技术方案示例只给了 fact。方案页提案把种类收成这五项，v0 采纳该枚举。
  final MemoryKind kind;

  /// 笔记正文。不是玩家可见台词。
  final String text;

  /// 涉及的实体 id。可以是空数组。
  final List<String> entities;

  /// 可选。模型对这条笔记的置信度。方案页提案。阈值未定，schema 不解释这个数。
  final double? confidence;

  Map<String, Object?> toJson() {
    return {
      'kind': kind.wire,
      'text': text,
      'entities': [...entities],
      if (confidence != null) 'confidence': confidence!,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryNote &&
            kind == other.kind &&
            text == other.text &&
            deepListEquals(entities, other.entities) &&
            confidence == other.confidence;
  }

  @override
  int get hashCode => Object.hashAll([
        kind,
        text,
        deepListHash(entities),
        confidence,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 实例不可变，相等性按字段值比较。
final class PromptMeta {
  factory PromptMeta({
    required String promptId,
    required String promptVersion,
  }) {
    checkIdToken(promptId, 'promptId');
    checkPromptVersion(promptVersion, 'promptVersion');
    return PromptMeta._(
      promptId: promptId,
      promptVersion: promptVersion,
    );
  }

  const PromptMeta._({
    required this.promptId,
    required this.promptVersion,
  });

  factory PromptMeta.fromJson(Object? json, {String path = ''}) {
    final jsonMap =
        readObject(json, path, const {'prompt_id', 'prompt_version'});
    final promptId =
        readRequiredString(jsonMap, 'prompt_id', path, check: checkIdToken);
    final promptVersion = readRequiredString(jsonMap, 'prompt_version', path,
        check: checkPromptVersion);
    return PromptMeta._(
      promptId: promptId,
      promptVersion: promptVersion,
    );
  }

  /// 提示词 id，例如 turn。技术方案示例把 id 和版本写成 turn@0.3.1。v0 拆开，便于生成字段而不是再解析字符串。
  final String promptId;

  /// 提示词的语义化版本，例如 0.3.1。它和载荷里的 schema_version 是两套编号。文档里的 turn_output@1 不是本字段的取值。
  final String promptVersion;

  Map<String, Object?> toJson() {
    return {
      'prompt_id': promptId,
      'prompt_version': promptVersion,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PromptMeta &&
            promptId == other.promptId &&
            promptVersion == other.promptVersion;
  }

  @override
  int get hashCode => Object.hashAll([
        promptId,
        promptVersion,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}

/// 对白模型每一回合的输出契约，schema_version 0。lines 与 choices 的 text
/// 是玩家可见内容，里面不得出现学习元信息；这条约束要靠后续语义校验，JSON Schema 查不了自然语言。proposed_events
/// 只是提议，奖励和阶段推进由代码裁决。 实例不可变，相等性按字段值比较。
final class TurnOutput {
  factory TurnOutput({
    String schemaName = 'turn_output',
    int schemaVersion = 0,
    required String turnId,
    required LanguagePair pair,
    required String speaker,
    required List<TurnLine> lines,
    List<TurnChoice>? choices,
    InputModeHint? inputModeHint,
    required SceneState sceneState,
    List<ProposedEvent>? proposedEvents,
    List<ImageRequest>? imageRequests,
    List<MemoryNote>? memoryNotes,
    required PromptMeta meta,
  }) {
    if (schemaName != 'turn_output') {
      throw LingoProtocolException(
          path: 'schemaName',
          message: 'schema_name 必须是 turn_output。不认识的取值会被拒绝。');
    }
    if (schemaVersion != 0) {
      throw LingoProtocolException(
          path: 'schemaVersion',
          message:
              'schema_version 必须是 0，实际是 $schemaVersion。不认识的契约版本会被拒绝，不会按别的版本猜测。');
    }
    checkTurnId(turnId, 'turnId');
    checkIdToken(speaker, 'speaker');
    final frozenLines = List<TurnLine>.unmodifiable(lines);
    if (frozenLines.isEmpty) {
      throw LingoProtocolException(
          path: 'lines', message: '至少需要 1 项，实际有 ${frozenLines.length} 项。');
    }
    final frozenChoices =
        choices == null ? null : List<TurnChoice>.unmodifiable(choices);
    if (frozenChoices != null) {}
    final frozenProposedEvents = proposedEvents == null
        ? null
        : List<ProposedEvent>.unmodifiable(proposedEvents);
    if (frozenProposedEvents != null) {}
    final frozenImageRequests = imageRequests == null
        ? null
        : List<ImageRequest>.unmodifiable(imageRequests);
    if (frozenImageRequests != null) {}
    final frozenMemoryNotes =
        memoryNotes == null ? null : List<MemoryNote>.unmodifiable(memoryNotes);
    if (frozenMemoryNotes != null) {}
    return TurnOutput._(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      turnId: turnId,
      pair: pair,
      speaker: speaker,
      lines: frozenLines,
      choices: frozenChoices,
      inputModeHint: inputModeHint,
      sceneState: sceneState,
      proposedEvents: frozenProposedEvents,
      imageRequests: frozenImageRequests,
      memoryNotes: frozenMemoryNotes,
      meta: meta,
    );
  }

  const TurnOutput._({
    required this.schemaName,
    required this.schemaVersion,
    required this.turnId,
    required this.pair,
    required this.speaker,
    required this.lines,
    this.choices,
    this.inputModeHint,
    required this.sceneState,
    this.proposedEvents,
    this.imageRequests,
    this.memoryNotes,
    required this.meta,
  });

  factory TurnOutput.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path, const {
      'schema_name',
      'schema_version',
      'turn_id',
      'pair',
      'speaker',
      'lines',
      'choices',
      'input_mode_hint',
      'scene_state',
      'proposed_events',
      'image_requests',
      'memory_notes',
      'meta'
    });
    final schemaName =
        readConstString(jsonMap, 'schema_name', path, 'turn_output');
    final schemaVersion = readConstInt(jsonMap, 'schema_version', path, 0);
    final turnId =
        readRequiredString(jsonMap, 'turn_id', path, check: checkTurnId);
    final pair =
        readRequiredModel(jsonMap, 'pair', path, LanguagePair.fromJson);
    final speaker =
        readRequiredString(jsonMap, 'speaker', path, check: checkIdToken);
    final lines = readRequiredList(jsonMap, 'lines', path,
        (item, itemPath) => TurnLine.fromJson(item, path: itemPath),
        minItems: 1);
    final choices = readOptionalList(jsonMap, 'choices', path,
        (item, itemPath) => TurnChoice.fromJson(item, path: itemPath));
    final inputModeHint = readOptionalEnum(
        jsonMap, 'input_mode_hint', path, InputModeHint.byWire);
    final sceneState =
        readRequiredModel(jsonMap, 'scene_state', path, SceneState.fromJson);
    final proposedEvents = readOptionalList(jsonMap, 'proposed_events', path,
        (item, itemPath) => ProposedEvent.fromJson(item, path: itemPath));
    final imageRequests = readOptionalList(jsonMap, 'image_requests', path,
        (item, itemPath) => ImageRequest.fromJson(item, path: itemPath));
    final memoryNotes = readOptionalList(jsonMap, 'memory_notes', path,
        (item, itemPath) => MemoryNote.fromJson(item, path: itemPath));
    final meta = readRequiredModel(jsonMap, 'meta', path, PromptMeta.fromJson);
    return TurnOutput._(
      schemaName: schemaName,
      schemaVersion: schemaVersion,
      turnId: turnId,
      pair: pair,
      speaker: speaker,
      lines: lines,
      choices: choices,
      inputModeHint: inputModeHint,
      sceneState: sceneState,
      proposedEvents: proposedEvents,
      imageRequests: imageRequests,
      memoryNotes: memoryNotes,
      meta: meta,
    );
  }

  /// 载荷类型名。技术方案示例把类型和版本写在一起（turn_output@1），v0 拆成 schema_name 与 schema_version。
  final String schemaName;

  /// turn_output 自己的契约版本，整数，从 0 起独立递增，不跟着另外两份契约走。文档写法 turn_output@1
  /// 不是这个字段的值。演进规则见 packages/lingo_protocol/README.md。这不是存档迁移版本。
  final int schemaVersion;

  /// 回合 id。由客户端生成，放进请求，用于幂等和重放。turn_output 与 turn_analysis 必须回显同一个值。weakness_plan
  /// 不是单回合模型回显，不带这个字段。
  final String turnId;

  /// 本回合语言对。台词语言应等于 pair.tgt；是否相等留给语义校验。
  final LanguagePair pair;

  /// 说话角色 id，对应 NPC 的 npc_id，例如 npc_mika。
  final String speaker;

  /// 角色台词。至少一句。每句的 lang 是该句文本的语言，学习回合里应等于 pair.tgt；纯游戏时 src 与 tgt 相同。
  final List<TurnLine> lines;

  /// 可选的玩家选项。自由输入的回合可以不给这个字段。选项是否必须出现，文档没有规定，所以 v0 不强制非空。
  final List<TurnChoice>? choices;

  /// 可选的输入方式提示，对应已定的三种输入：voice 语音、typing 打字、word_choice
  /// 选字。技术方案的对白示例没有这个字段，三种输入是玩法而不是模型输出，因此这里只是提案，并且可选。schema 不规定它和 choices 必须如何搭配。
  final InputModeHint? inputModeHint;

  final SceneState sceneState;

  /// 模型提议的故事事件。可以没有。不在本场允许列表里的事件由代码降级，不在本 schema 里拒绝。
  final List<ProposedEvent>? proposedEvents;

  /// 异步出图或换立绘的槽位请求。模型不在这里写图像提示词。表情取值不在本数组里重复，见 lines[].expression。
  final List<ImageRequest>? imageRequests;

  /// 模型提议的记忆笔记。写入事实表前要由代码校验。可以没有。
  final List<MemoryNote>? memoryNotes;

  final PromptMeta meta;

  Map<String, Object?> toJson() {
    return {
      'schema_name': schemaName,
      'schema_version': schemaVersion,
      'turn_id': turnId,
      'pair': pair.toJson(),
      'speaker': speaker,
      'lines': [for (final item in lines) item.toJson()],
      if (choices != null)
        'choices': [for (final item in choices!) item.toJson()],
      if (inputModeHint != null) 'input_mode_hint': inputModeHint!.wire,
      'scene_state': sceneState.toJson(),
      if (proposedEvents != null)
        'proposed_events': [for (final item in proposedEvents!) item.toJson()],
      if (imageRequests != null)
        'image_requests': [for (final item in imageRequests!) item.toJson()],
      if (memoryNotes != null)
        'memory_notes': [for (final item in memoryNotes!) item.toJson()],
      'meta': meta.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TurnOutput &&
            schemaName == other.schemaName &&
            schemaVersion == other.schemaVersion &&
            turnId == other.turnId &&
            pair == other.pair &&
            speaker == other.speaker &&
            deepListEquals(lines, other.lines) &&
            deepListEquals(choices, other.choices) &&
            inputModeHint == other.inputModeHint &&
            sceneState == other.sceneState &&
            deepListEquals(proposedEvents, other.proposedEvents) &&
            deepListEquals(imageRequests, other.imageRequests) &&
            deepListEquals(memoryNotes, other.memoryNotes) &&
            meta == other.meta;
  }

  @override
  int get hashCode => Object.hashAll([
        schemaName,
        schemaVersion,
        turnId,
        pair,
        speaker,
        deepListHash(lines),
        deepListHash(choices),
        inputModeHint,
        sceneState,
        deepListHash(proposedEvents),
        deepListHash(imageRequests),
        deepListHash(memoryNotes),
        meta,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}
