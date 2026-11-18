// SPDX-License-Identifier: GPL-3.0-only

import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
// ignore: implementation_imports
import 'package:pana/src/license_detection/license_detector.dart' as detector;

const requiredHeaderPhrases = <String>['临时白名单', '待 W1-03 定稿后对齐', '不作为正式许可证政策'];

const licenseFileNames = <String>[
  'LICENSE',
  'LICENSE.md',
  'LICENSE.markdown',
  'LICENSE.txt',
  'LICENCE',
  'LICENCE.md',
  'LICENCE.txt',
  'COPYING',
  'COPYING.txt',
  'UNLICENSE',
];

class PolicyError implements Exception {
  final String message;

  PolicyError(this.message);

  @override
  String toString() => message;
}

class LicenseExceptionEntry {
  final String package;
  final String license;
  final String reason;

  const LicenseExceptionEntry({
    required this.package,
    required this.license,
    required this.reason,
  });
}

class Policy {
  final List<String> permittedLicenses;
  final List<LicenseExceptionEntry> exceptions;

  const Policy({required this.permittedLicenses, required this.exceptions});

  bool permits(String license) => permittedLicenses.contains(license);
}

class Decision {
  final bool allowed;
  final bool usedException;
  final String detail;

  const Decision({
    required this.allowed,
    required this.usedException,
    required this.detail,
  });
}

class LockedPackage {
  final String version;
  final String source;

  const LockedPackage({required this.version, required this.source});
}

class LicenseLocation {
  final List<File> files;
  final String origin;

  const LicenseLocation({required this.files, required this.origin});
}

class PackageScan {
  final String name;
  final String version;
  final String source;
  final List<String> licenses;
  final Decision decision;
  final String licenseOrigin;

  const PackageScan({
    required this.name,
    required this.version,
    required this.source,
    required this.licenses,
    required this.decision,
    required this.licenseOrigin,
  });
}

class ScanReport {
  final Policy policy;
  final List<PackageScan> packages;
  final List<String> errors;
  final String label;

  const ScanReport({
    required this.policy,
    required this.packages,
    required this.errors,
    required this.label,
  });

  bool get ok =>
      errors.isEmpty && packages.every((package) => package.decision.allowed);
}

Policy parsePolicy(String text) {
  for (final phrase in requiredHeaderPhrases) {
    if (!text.contains(phrase)) {
      throw PolicyError('规则文件头部缺少「$phrase」。');
    }
  }

  final document = loadYaml(text);
  if (document is! YamlMap) {
    throw PolicyError('规则文件必须是 YAML 映射。');
  }

  final permittedRaw = document['permittedLicenses'];
  if (permittedRaw is! YamlList || permittedRaw.isEmpty) {
    throw PolicyError('permittedLicenses 必须是非空列表。');
  }
  final permitted = <String>[];
  for (final item in permittedRaw) {
    if (item is! String || item.trim().isEmpty) {
      throw PolicyError('permittedLicenses 的每一项都必须是非空字符串。');
    }
    if (permitted.contains(item)) {
      throw PolicyError('允许列表重复：$item');
    }
    permitted.add(item);
  }

  final exceptionsRaw = document['exceptions'];
  if (exceptionsRaw is! YamlList) {
    throw PolicyError('exceptions 必须是列表。当前没有例外时写成空列表。');
  }
  if (exceptionsRaw.isEmpty && !text.contains('当前例外：无')) {
    throw PolicyError('例外为空时，规则文件头部必须写明「当前例外：无」。');
  }
  if (exceptionsRaw.isNotEmpty && text.contains('当前例外：无')) {
    throw PolicyError('已有例外时，不要在头部保留「当前例外：无」。');
  }

  final exceptions = <LicenseExceptionEntry>[];
  final seen = <String>{};
  for (final item in exceptionsRaw) {
    if (item is! YamlMap) {
      throw PolicyError('每条例外都必须包含 package、license 和 reason。');
    }
    final package = item['package'];
    final license = item['license'];
    final reason = item['reason'];
    if (package is! String ||
        package.trim().isEmpty ||
        license is! String ||
        license.trim().isEmpty ||
        reason is! String ||
        reason.trim().isEmpty) {
      throw PolicyError('例外必须写明包名、许可和引入理由。');
    }
    final key = '${package.trim()}\n${license.trim()}';
    if (!seen.add(key)) {
      throw PolicyError('例外重复：${package.trim()} (${license.trim()})');
    }
    exceptions.add(
      LicenseExceptionEntry(
        package: package.trim(),
        license: license.trim(),
        reason: reason.trim(),
      ),
    );
  }

  return Policy(permittedLicenses: permitted, exceptions: exceptions);
}

Decision decide({
  required String package,
  required List<String> licenses,
  required Policy policy,
}) {
  if (licenses.isEmpty) {
    return const Decision(
      allowed: false,
      usedException: false,
      detail: '未识别许可',
    );
  }

  final rejected = <String>[];
  final reasons = <String>[];
  for (final license in licenses) {
    if (policy.permits(license)) {
      continue;
    }
    final matches = policy.exceptions.where(
      (entry) => entry.package == package && entry.license == license,
    );
    if (matches.isEmpty) {
      rejected.add(license);
      continue;
    }
    for (final entry in matches) {
      reasons.add('${entry.license}：${entry.reason}');
    }
  }

  if (rejected.isNotEmpty) {
    return Decision(
      allowed: false,
      usedException: false,
      detail: '不允许：${rejected.join(', ')}',
    );
  }
  if (reasons.isNotEmpty) {
    return Decision(
      allowed: true,
      usedException: true,
      detail: reasons.join('；'),
    );
  }
  return const Decision(allowed: true, usedException: false, detail: '');
}

// Flutter's engine notice file separates components with a long dashed
// line. Shorter dashed underlines appear inside the FreeType license.
final _noticeSeparator = RegExp(r'\n-{40,}\n');

Future<List<String>> detectLicenseIds(String text) async {
  if (_noticeSeparator.allMatches(text).length >= 3) {
    return _detectNoticeBundle(text);
  }
  return _idsFromDetection(await detector.detectLicense(text, 0.9));
}

Future<List<String>> _detectNoticeBundle(String text) async {
  final ids = <String>[];
  final unknown = <String>[];
  for (final block in text.split(_noticeSeparator)) {
    final trimmed = block.trim();
    if (trimmed.isEmpty || _isAttributionOnly(trimmed)) {
      continue;
    }
    final detected = await _classifyBlock(trimmed);
    if (detected.isEmpty) {
      final heading = trimmed
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) => line.isNotEmpty, orElse: () => 'unknown');
      if (!unknown.contains(heading)) {
        unknown.add(heading);
      }
      continue;
    }
    for (final id in detected) {
      if (!ids.contains(id)) {
        ids.add(id);
      }
    }
  }
  if (unknown.isNotEmpty) {
    ids.addAll(unknown.take(8).map((heading) => 'UNRECOGNIZED:$heading'));
  }
  return ids;
}

Future<List<String>> _classifyBlock(String block) async {
  final strict = await detector.detectLicense(block, 0.9);
  if (strict.matches.isNotEmpty) {
    return _idsFromDetection(strict);
  }
  final loose = await detector.detectLicense(block, 0.8);
  if (loose.matches.isNotEmpty && loose.unclaimedTokenPercentage < 0.4) {
    return _idsFromDetection(loose);
  }
  final notice = _noticeLicense(block);
  if (notice == null) {
    return const [];
  }
  return [notice];
}

List<String> _idsFromDetection(detector.Result result) {
  final ids = <String>[];
  for (final match in result.matches) {
    if (!ids.contains(match.identifier)) {
      ids.add(match.identifier);
    }
  }
  return ids;
}

String? _noticeLicense(String block) {
  final lower = block.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (lower.contains('gnu lesser general public license') &&
      lower.contains('version 2.1')) {
    return 'LGPL-2.1';
  }
  if (lower.contains('gnu lesser general public license') &&
      lower.contains('version 3')) {
    return 'LGPL-3.0';
  }
  if (lower.contains('gnu general public license') &&
      lower.contains('version 3')) {
    return 'GPL-3.0';
  }
  if (lower.contains('gnu general public license') &&
      (lower.contains('version 2') || lower.contains('version 2,'))) {
    return 'GPL-2.0';
  }
  if (lower.contains('mozilla public license') && lower.contains('2.0')) {
    return 'MPL-2.0';
  }
  if (lower.contains('apache license, version 2.0') ||
      lower.contains('apache license version 2.0') ||
      lower.contains('licensed under the apache license, version 2.0')) {
    return 'Apache-2.0';
  }
  if (lower.contains('boost software license')) {
    return 'BSL-1.0';
  }
  if (lower.contains('freetype project license')) {
    return 'FTL';
  }
  if (lower.contains('png reference library license')) {
    return 'libpng-2.0';
  }
  if (lower.contains('nvidia corporation') &&
      lower.contains('non-exclusive license')) {
    return 'LicenseRef-NVIDIA-2002';
  }
  if (lower.contains('creativecommons.org/licenses/zero') ||
      lower.contains('creative commons zero')) {
    return 'CC0-1.0';
  }
  if (lower.contains('public domain')) {
    return 'public-domain';
  }
  if (lower.contains('licensed under the mit license')) {
    return 'MIT';
  }
  if (lower.contains('permission to use, copy, modify, and distribute')) {
    return 'HPND';
  }
  if (lower.contains('bsd-style open source license')) {
    return 'BSD-3-Clause';
  }
  if (lower.contains('permission is hereby granted')) {
    return 'MIT';
  }
  if (lower.contains('redistribution and use in source and binary forms')) {
    final clauses = RegExp(r'^\s*\d+\.', multiLine: true).allMatches(block);
    return clauses.length == 2 ? 'BSD-2-Clause' : 'BSD-3-Clause';
  }
  return null;
}

bool _isAttributionOnly(String block) {
  final lower = block.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const markers = [
    'permission is hereby granted',
    'redistribution and use',
    'licensed under',
    'apache license',
    'terms and conditions',
    'boost software license',
    'gnu ',
    'mozilla public',
    'freetype',
    'png reference',
    'this software is provided',
    'the software is provided',
  ];
  if (markers.any(lower.contains)) {
    return false;
  }
  return block.length < 600;
}

Map<String, LockedPackage> parseLockfile(String text) {
  final document = loadYaml(text);
  if (document is! YamlMap) {
    return {};
  }
  final packages = document['packages'];
  if (packages is! YamlMap) {
    return {};
  }
  final locked = <String, LockedPackage>{};
  for (final entry in packages.entries) {
    final name = entry.key;
    final value = entry.value;
    if (name is! String || value is! YamlMap) {
      continue;
    }
    final version = value['version'];
    final source = value['source'];
    locked[name] = LockedPackage(
      version: version is String ? version : 'unknown',
      source: source is String ? source : 'unknown',
    );
  }
  return locked;
}

List<File> licenseFilesIn(String directory) {
  final files = <File>[];
  for (final name in licenseFileNames) {
    final file = File(p.join(directory, name));
    if (file.existsSync()) {
      files.add(file);
    }
  }
  return files;
}

String? flutterSdkRoot(String start) {
  var directory = Directory(start).absolute;
  while (true) {
    if (File(p.join(directory.path, 'bin', 'flutter')).existsSync()) {
      return directory.path;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      return null;
    }
    directory = parent;
  }
}

bool isInside(String parent, String child) {
  final normalizedParent = p.normalize(parent);
  final normalizedChild = p.normalize(child);
  return normalizedChild == normalizedParent ||
      normalizedChild.startsWith('$normalizedParent${p.separator}');
}

LicenseLocation locateLicenses({
  required String packageRoot,
  required String source,
  required String repoRoot,
}) {
  final local = licenseFilesIn(packageRoot);
  if (local.isNotEmpty) {
    return LicenseLocation(files: local, origin: packageRoot);
  }

  if (source == 'sdk') {
    final sdkRoot = flutterSdkRoot(packageRoot);
    if (sdkRoot != null) {
      final sdkLicense = licenseFilesIn(sdkRoot);
      if (sdkLicense.isNotEmpty) {
        return LicenseLocation(files: sdkLicense, origin: sdkRoot);
      }
    }
  }

  if (isInside(repoRoot, packageRoot)) {
    final repoLicense = licenseFilesIn(repoRoot);
    if (repoLicense.isNotEmpty) {
      return LicenseLocation(files: repoLicense, origin: repoRoot);
    }
  }

  return const LicenseLocation(files: [], origin: '');
}

Future<ScanReport> scanRepository(
  String repoRoot, {
  String? packageConfigPath,
  String? lockfilePath,
  String label = 'workspace',
  bool allowAbsentExceptions = false,
}) async {
  final root = p.normalize(Directory(repoRoot).absolute.path);
  final policyFile = File(p.join(root, 'tool', 'license_policy.yaml'));
  if (!policyFile.existsSync()) {
    throw PolicyError('找不到规则文件 ${policyFile.path}');
  }
  final policy = parsePolicy(policyFile.readAsStringSync());

  final configFile = File(
    packageConfigPath ?? p.join(root, '.dart_tool', 'package_config.json'),
  ).absolute;
  if (!configFile.existsSync()) {
    throw PolicyError('找不到 ${configFile.path}。请先运行 dart pub get。');
  }
  final lockFile = File(lockfilePath ?? p.join(root, 'pubspec.lock')).absolute;
  final locked = lockFile.existsSync()
      ? parseLockfile(lockFile.readAsStringSync())
      : <String, LockedPackage>{};
  final config = await loadPackageConfig(configFile);
  final packages = [...config.packages]
    ..sort((a, b) => a.name.compareTo(b.name));

  final scanned = <PackageScan>[];
  final seenNames = <String>{};
  for (final package in packages) {
    seenNames.add(package.name);
    final lockedPackage = locked[package.name];
    final packageRoot = p.normalize(package.root.toFilePath());
    final source =
        lockedPackage?.source ??
        (isInside(root, packageRoot) ? 'workspace' : 'unknown');
    final version =
        lockedPackage?.version ??
        (isInside(root, packageRoot) ? 'workspace' : 'unknown');
    final location = locateLicenses(
      packageRoot: packageRoot,
      source: source,
      repoRoot: root,
    );

    final licenses = <String>[];
    var unrecognized = false;
    String? readError;
    for (final file in location.files) {
      String text;
      try {
        text = file.readAsStringSync();
      } on FileSystemException catch (error) {
        readError = error.message;
        break;
      }
      final ids = await detectLicenseIds(text);
      if (ids.isEmpty) {
        unrecognized = true;
        continue;
      }
      for (final id in ids) {
        if (!licenses.contains(id)) {
          licenses.add(id);
        }
      }
    }

    final Decision decision;
    if (readError != null) {
      decision = Decision(
        allowed: false,
        usedException: false,
        detail: '无法读取许可文件：$readError',
      );
    } else if (location.files.isEmpty) {
      decision = const Decision(
        allowed: false,
        usedException: false,
        detail: '没有 LICENSE 文件',
      );
    } else if (unrecognized) {
      decision = const Decision(
        allowed: false,
        usedException: false,
        detail: 'LICENSE 文本未识别',
      );
    } else {
      decision = decide(
        package: package.name,
        licenses: licenses,
        policy: policy,
      );
    }

    scanned.add(
      PackageScan(
        name: package.name,
        version: version,
        source: source,
        licenses: licenses,
        decision: decision,
        licenseOrigin: location.origin,
      ),
    );
  }

  final errors = <String>[];
  for (final exception in policy.exceptions) {
    if (!seenNames.contains(exception.package)) {
      if (!allowAbsentExceptions) {
        errors.add(
          '例外 ${exception.package} (${exception.license}) 不是当前解析结果中的包。',
        );
      }
      continue;
    }
    final package = scanned.firstWhere(
      (item) => item.name == exception.package,
    );
    final used =
        package.licenses.contains(exception.license) &&
        !policy.permits(exception.license);
    if (!used) {
      errors.add(
        '例外未使用：${exception.package} 的 ${exception.license} '
        '没有出现在不允许的识别结果中。',
      );
    }
  }

  for (final name in locked.keys.where((name) => !seenNames.contains(name))) {
    errors.add('pubspec.lock 中的 $name 没有出现在 package_config.json。');
  }

  return ScanReport(
    policy: policy,
    packages: scanned,
    errors: errors,
    label: label,
  );
}

String renderReport(ScanReport report) {
  final buffer = StringBuffer()
    ..writeln('目标：${report.label}')
    ..writeln('临时白名单，待 W1-03 定稿后对齐。W1-03 定稿前不作为正式许可证政策。')
    ..writeln('允许：${report.policy.permittedLicenses.join(', ')}');
  if (report.policy.exceptions.isEmpty) {
    buffer.writeln('例外：无');
  } else {
    buffer.writeln('例外：');
    for (final exception in report.policy.exceptions) {
      buffer.writeln(
        '  - ${exception.package}  ${exception.license}  ${exception.reason}',
      );
    }
  }

  final counts = <String, int>{};
  for (final package in report.packages) {
    final label = package.licenses.isEmpty
        ? '(无)'
        : (package.licenses.toList()..sort()).join('+');
    counts[label] = (counts[label] ?? 0) + 1;
  }
  buffer.writeln('扫描包数：${report.packages.length}');
  final countKeys = counts.keys.toList()..sort();
  for (final key in countKeys) {
    buffer.writeln('  $key  ${counts[key]}');
  }

  buffer.writeln('明细：');
  for (final package in report.packages) {
    final licenses = package.licenses.isEmpty
        ? '(无)'
        : package.licenses.join(', ');
    final status = !package.decision.allowed
        ? '失败'
        : package.decision.usedException
        ? '例外'
        : '允许';
    final detail = package.decision.detail.isEmpty
        ? ''
        : ' ${package.decision.detail}';
    final origin = package.licenseOrigin.isEmpty
        ? ''
        : ' 许可文件目录：${package.licenseOrigin}';
    buffer.writeln(
      '  ${package.name} ${package.version} [${package.source}] '
      '$licenses $status$detail$origin',
    );
  }

  if (report.errors.isNotEmpty) {
    buffer.writeln('规则错误：');
    for (final error in report.errors) {
      buffer.writeln('  - $error');
    }
  }
  buffer.writeln(report.ok ? '结果：通过' : '结果：失败');
  return buffer.toString();
}
