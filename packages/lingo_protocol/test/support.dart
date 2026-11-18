import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

final Directory packageRoot = _findPackageRoot();

Directory _findPackageRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    final schema = File('${dir.path}/schema/turn_output.schema.json');
    if (pubspec.existsSync() && schema.existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  throw StateError(
    'lingo_protocol package root not found from ${Directory.current.path}',
  );
}

String exampleText(String schemaName, String fileName) {
  return File(
    '${packageRoot.path}/examples/$schemaName/$fileName',
  ).readAsStringSync();
}

Object? decodeJson(String source) {
  final decoded = jsonDecode(source);
  return decoded as Object?;
}

Map<String, dynamic> decodeObject(String source) {
  final decoded = decodeJson(source);
  if (decoded is! Map) {
    throw StateError('expected a JSON object');
  }
  return Map<String, dynamic>.from(decoded);
}

/// Semantic JSON equality. Integral numbers compare equal across int and double
/// (`1 == 1.0`), matching JSON Schema's numeric comparison.
bool jsonEqual(Object? left, Object? right) {
  if (left is num && right is num) {
    return left == right;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (!jsonEqual(left[i] as Object?, right[i] as Object?)) {
        return false;
      }
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final key in left.keys) {
      if (!right.containsKey(key) ||
          !jsonEqual(left[key] as Object?, right[key] as Object?)) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

bool schemaAcceptsSource(String schemaName, String source) {
  final result = Process.runSync(
      'python3',
      [
        '-c',
        r'''
import json
import sys
import validate

name = sys.argv[1]
schemas, registry = validate.build_registry()
validator = validate.validator_for(schemas[name], registry)
instance = json.loads(sys.argv[2])
errors = list(validator.iter_errors(instance))
if errors:
    print(errors[0].message, file=sys.stderr)
    sys.exit(1)
''',
        schemaName,
        source,
      ],
      workingDirectory: packageRoot.path);
  if (result.exitCode == 0) {
    return true;
  }
  if (result.exitCode == 1) {
    return false;
  }
  fail(
    'schema validator failed to run (exit ${result.exitCode}):\n'
    '${result.stdout}\n${result.stderr}',
  );
}

bool schemaAccepts(String schemaName, Object? instance) {
  return schemaAcceptsSource(schemaName, jsonEncode(instance));
}
