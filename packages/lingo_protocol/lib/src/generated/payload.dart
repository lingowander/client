// Generated from packages/lingo_protocol/schema/*.schema.json.
// Do not edit by hand. Regenerate with:
//
//   python3 packages/lingo_protocol/tool/generate_types.py
//
// CI runs that script with --check and fails when this file is stale.

import 'dart:convert';

import '../decode.dart';
import 'turn_analysis.dart';
import 'turn_output.dart';
import 'weakness_plan.dart';

/// Decodes one v0 payload by its `schema_name`.
///
/// 不认识的 `schema_name` 会抛出 [LingoProtocolException]，不会猜测类型。
Object decodePayload(Object? json) {
  if (json is! Map) {
    throw const LingoProtocolException(path: '/', message: '期望 JSON 对象。');
  }
  final name = json['schema_name'] as Object?;
  switch (name) {
    case 'turn_output':
      return TurnOutput.fromJson(json);
    case 'turn_analysis':
      return TurnAnalysis.fromJson(json);
    case 'weakness_plan':
      return WeaknessPlan.fromJson(json);
    default:
      throw LingoProtocolException(
        path: '/schema_name',
        message: '未知的 schema_name ${jsonEncode(name)}。'
            '允许：turn_output、turn_analysis、weakness_plan。'
            '不认识的契约不会被猜测。',
      );
  }
}
