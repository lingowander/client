// SPDX-License-Identifier: GPL-3.0-only

import 'dart:io';

import 'package:license_scan/license_scan.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  String? repoRoot;
  String? packageConfigPath;
  String? lockfilePath;
  var label = 'workspace';
  var allowAbsentExceptions = false;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    String next() {
      if (index + 1 >= args.length) {
        stderr.writeln('缺少 $arg 的参数。');
        exit(64);
      }
      index++;
      return args[index];
    }

    switch (arg) {
      case '--help':
      case '-h':
        stdout.writeln(
          'Usage: dart run bin/check_licenses.dart '
          '[--repo-root PATH] [--package-config PATH] [--lock PATH] '
          '[--label NAME] [--allow-absent-exceptions]',
        );
        return;
      case '--repo-root':
        repoRoot = next();
      case '--package-config':
        packageConfigPath = next();
      case '--lock':
        lockfilePath = next();
      case '--label':
        label = next();
      case '--allow-absent-exceptions':
        allowAbsentExceptions = true;
      default:
        stderr.writeln('未知参数：$arg');
        exit(64);
    }
  }

  try {
    final root = repoRoot ?? findRepoRoot(Directory.current).path;
    final report = await scanRepository(
      root,
      packageConfigPath: packageConfigPath,
      lockfilePath: lockfilePath,
      label: label,
      allowAbsentExceptions: allowAbsentExceptions,
    );
    stdout.write(renderReport(report));
    exit(report.ok ? 0 : 1);
  } on PolicyError catch (error) {
    stderr.writeln(error);
    exit(1);
  }
}

Directory findRepoRoot(Directory start) {
  var directory = start.absolute;
  while (true) {
    final policy = File(p.join(directory.path, 'tool', 'license_policy.yaml'));
    final pubspec = File(p.join(directory.path, 'pubspec.yaml'));
    if (policy.existsSync() && pubspec.existsSync()) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw PolicyError('从 ${start.path} 向上找不到仓库根目录。');
    }
    directory = parent;
  }
}
