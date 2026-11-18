import 'dart:io';

import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('generated Dart matches the schema', () {
    final result = Process.runSync(
        'python3',
        [
          'tool/generate_types.py',
          '--check',
        ],
        workingDirectory: packageRoot.path);
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
  });
}
