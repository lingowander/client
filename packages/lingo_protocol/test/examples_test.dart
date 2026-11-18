import 'dart:io';

import 'package:lingo_protocol/lingo_protocol.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('validate.py accepts the example corpus', () {
    final result = Process.runSync(
        'python3',
        [
          'validate.py',
        ],
        workingDirectory: packageRoot.path);
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });

  final root = Directory('${packageRoot.path}/examples');
  for (final entity in root.listSync()) {
    if (entity is! Directory) {
      continue;
    }
    final schemaName = _baseName(entity.path);
    for (final file in entity.listSync().whereType<File>()) {
      final fileName = _baseName(file.path);
      if (!fileName.endsWith('.json')) {
        continue;
      }
      final label = '$schemaName/$fileName';
      if (fileName.startsWith('valid_')) {
        test('$label passes schema validation and round-trips', () {
          final original = decodeJson(file.readAsStringSync());
          expect(schemaAccepts(schemaName, original), isTrue);
          final typed = decodePayload(original);
          final encoded = _toJson(typed);
          expect(schemaAccepts(schemaName, encoded), isTrue);
          expect(jsonEqual(original, encoded), isTrue);
          expect(decodePayload(encoded), typed);
        });
      } else if (fileName.startsWith('invalid_')) {
        test('$label is rejected by the schema and by Dart', () {
          final original = decodeJson(file.readAsStringSync());
          expect(schemaAccepts(schemaName, original), isFalse);
          expect(
            () => decodePayload(original),
            throwsA(isA<LingoProtocolException>()),
          );
        });
      } else {
        throw StateError(
            'example name must start with valid_ or invalid_: $label');
      }
    }
  }
}

String _baseName(String path) {
  final parts = Uri.file(path).pathSegments.where((part) => part.isNotEmpty);
  return parts.last;
}

Map<String, Object?> _toJson(Object typed) {
  return switch (typed) {
    TurnOutput value => value.toJson(),
    TurnAnalysis value => value.toJson(),
    WeaknessPlan value => value.toJson(),
    _ => throw StateError('unexpected ${typed.runtimeType}'),
  };
}
