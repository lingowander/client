import 'dart:math';

import 'generated/common.dart';

/// Creates the `turn_id` a client puts on a request.
///
/// The id is a hyphenated UUID version 4. `turn_output` and `turn_analysis`
/// must echo it. This package does not define the request object itself;
/// `common.schema.json` only defines the id.
///
/// Pass [random] in tests. The default is [Random.secure].
String generateTurnId({Random? random}) {
  final rng = random ?? Random.secure();
  final bytes =
      List<int>.generate(16, (_) => rng.nextInt(256), growable: false);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  checkTurnId(id, 'turn_id');
  return id;
}
