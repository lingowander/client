/// Immutable Dart types for the lingo_protocol v0 turn contracts.
///
/// The files under `src/generated` come from `schema/*.schema.json`.
/// Regenerate them with `tool/generate_types.py`. Unknown JSON fields
/// and unknown enum values throw [LingoProtocolException].
library;

export 'src/decode.dart' show LingoProtocolException;
export 'src/generated/common.dart';
export 'src/generated/enums.dart';
export 'src/generated/payload.dart';
export 'src/generated/turn_analysis.dart';
export 'src/generated/turn_output.dart';
export 'src/generated/weakness_plan.dart';
export 'src/turn_id.dart' show generateTurnId;
