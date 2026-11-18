// Generated from packages/lingo_protocol/schema/*.schema.json.
// Do not edit by hand. Regenerate with:
//
//   python3 packages/lingo_protocol/tool/generate_types.py
//
// CI runs that script with --check and fails when this file is stale.

import 'dart:convert';

import '../decode.dart';

final RegExp _languageCodePattern = RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]+)*$');

final RegExp _langPairKeyPattern =
    RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]+)*>[a-z]{2,3}(-[A-Za-z0-9]+)*$');

final RegExp _sceneIdPattern = RegExp(r'^s_[0-9]{4,}$');

final RegExp _idTokenPattern = RegExp(r'^[a-z][a-z0-9_]*$');

final RegExp _eventKeyPattern =
    RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

final RegExp _promptVersionPattern =
    RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$');

/// 语言代码。与 lang_pair_key 里 > 两侧的片段是同一种写法，例如 zh、en、zh-Hans。v0
/// 不把首发语言收成枚举；首发只用哪些代码是产品配置，不是本定义的封闭列表。
void checkLanguageCode(String value, String path) {
  validateString(value, path,
      minLength: 2, maxLength: 32, pattern: _languageCodePattern);
}

/// 由 pair 派生的分桶键，只在需要 map 键时使用，例如 zh>en、zh-Hans>en。分隔符固定为 >。文档里纯游戏有时写成
/// zh=zh，那个写法不是这个键；同语的派生键是 zh>zh。三份 v0 回合载荷没有 map 字段，因此没有引用本定义。
void checkLangPairKey(String value, String path) {
  validateString(value, path, pattern: _langPairKeyPattern);
}

/// 回合 id。由客户端生成，放进请求，用于幂等和重放。turn_output 与 turn_analysis 必须回显同一个值。weakness_plan
/// 不是单回合模型回显，不带这个字段。
void checkTurnId(String value, String path) {
  validateString(value, path, format: 'uuid');
}

/// 档案 id。三份 v0 回合载荷不携带它。定义留在 common，供后续契约使用。
void checkProfileId(String value, String path) {
  validateString(value, path, format: 'uuid');
}

/// 事件 id。建议使用 UUIDv7，以便按时间排序。format uuid 不检查版本位，v0 不能靠 schema 拒绝其他版本的 UUID。三份
/// v0 回合载荷里的故事事件用 event_key，不使用本字段。
void checkEventId(String value, String path) {
  validateString(value, path, format: 'uuid');
}

/// 场景 id，例如 s_0042。至少四位数字。
void checkSceneId(String value, String path) {
  validateString(value, path, pattern: _sceneIdPattern);
}

/// 小写标识。用于角色、台词、选项、节拍、薄弱点、语义键、descriptor、intent、prompt_id
/// 和镜头标签。不是封闭词表。turn_id、profile_id、event_id 和 scene_id 不用这个形态。
void checkIdToken(String value, String path) {
  validateString(value, path,
      minLength: 1, maxLength: 64, pattern: _idTokenPattern);
}

/// 故事事件键，至少两段、用点分开，例如 cafe.remembered_order。这不是
/// event_id。是否落在本场允许结算的事件键里，由代码做后续语义校验，不在本 schema 里列白名单。
void checkEventKey(String value, String path) {
  validateString(value, path,
      minLength: 3, maxLength: 64, pattern: _eventKeyPattern);
}

/// 提示词的语义化版本，例如 0.3.1。它和载荷里的 schema_version 是两套编号。文档里的 turn_output@1 不是本字段的取值。
void checkPromptVersion(String value, String path) {
  validateString(value, path, pattern: _promptVersionPattern);
}

/// 闭区间 0 到 1。技术方案示例里的 tension、severity、level_evidence 和 confidence
/// 都是这个区间里的数，文档本身没有写值域。v0 按示例收成这个区间。这些数不是给玩家看的分数。
void checkUnitInterval(double value, String path) {
  validateNumber(value, path, minimum: 0, maximum: 1);
}

/// 语言对，与技术方案 2.5 的 {src, tgt} 一致。src 与 tgt 相同就是纯游戏。所有回合载荷都用这个对象，不用 zh>en 这种字符串。
/// 实例不可变，相等性按字段值比较。
final class LanguagePair {
  factory LanguagePair({
    required String src,
    required String tgt,
  }) {
    checkLanguageCode(src, 'src');
    checkLanguageCode(tgt, 'tgt');
    return LanguagePair._(
      src: src,
      tgt: tgt,
    );
  }

  const LanguagePair._({
    required this.src,
    required this.tgt,
  });

  factory LanguagePair.fromJson(Object? json, {String path = ''}) {
    final jsonMap = readObject(json, path, const {'src', 'tgt'});
    final src =
        readRequiredString(jsonMap, 'src', path, check: checkLanguageCode);
    final tgt =
        readRequiredString(jsonMap, 'tgt', path, check: checkLanguageCode);
    return LanguagePair._(
      src: src,
      tgt: tgt,
    );
  }

  /// 语言代码。与 lang_pair_key 里 > 两侧的片段是同一种写法，例如 zh、en、zh-Hans。v0
  /// 不把首发语言收成枚举；首发只用哪些代码是产品配置，不是本定义的封闭列表。
  final String src;

  /// 语言代码。与 lang_pair_key 里 > 两侧的片段是同一种写法，例如 zh、en、zh-Hans。v0
  /// 不把首发语言收成枚举；首发只用哪些代码是产品配置，不是本定义的封闭列表。
  final String tgt;

  Map<String, Object?> toJson() {
    return {
      'src': src,
      'tgt': tgt,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LanguagePair && src == other.src && tgt == other.tgt;
  }

  @override
  int get hashCode => Object.hashAll([
        src,
        tgt,
      ]);

  @override
  String toString() => '$runtimeType(${jsonEncode(toJson())})';
}
