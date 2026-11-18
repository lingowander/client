// SPDX-License-Identifier: GPL-3.0-only

import 'dart:io';

import 'package:license_scan/license_scan.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Policy checkedIn;

  setUpAll(() {
    final file = File(
      p.normalize(p.join(Directory.current.path, '..', 'license_policy.yaml')),
    );
    checkedIn = parsePolicy(file.readAsStringSync());
  });

  test('checked-in policy is a temporary allowlist', () {
    final text = File(
      p.normalize(p.join(Directory.current.path, '..', 'license_policy.yaml')),
    ).readAsStringSync();
    expect(text, contains('临时白名单'));
    expect(text, contains('待 W1-03 定稿后对齐'));
    expect(text, contains('不作为正式许可证政策'));
    expect(text, isNot(contains('当前例外：无')));
    expect(
      checkedIn.permittedLicenses,
      containsAll(const [
        'MIT',
        'BSD-2-Clause',
        'BSD-3-Clause',
        'Apache-2.0',
        'ISC',
        'Zlib',
        'GPL-3.0',
        'LGPL-2.1',
        'LGPL-3.0',
        'AGPL-3.0',
      ]),
    );
    expect(checkedIn.permittedLicenses, isNot(contains('GPL-2.0')));
    expect(checkedIn.permittedLicenses, isNot(contains('MPL-2.0')));
    expect(checkedIn.exceptions, hasLength(1));
    expect(checkedIn.exceptions.single.package, 'sky_engine');
    expect(checkedIn.exceptions.single.license, 'LicenseRef-NVIDIA-2002');
    expect(checkedIn.exceptions.single.reason, isNot(isEmpty));
  });

  test('rejects an exception that omits the reason', () {
    expect(
      () => parsePolicy('''
# 临时白名单，待 W1-03 定稿后对齐。
# W1-03 定稿前，本文件不作为正式许可证政策。
permittedLicenses:
  - MIT
exceptions:
  - package: example
    license: MPL-2.0
'''),
      throwsA(isA<PolicyError>()),
    );
  });

  test('allows MIT and rejects GPL-2.0 and MPL-2.0 unless excepted', () {
    final policy = parsePolicy('''
# 临时白名单，待 W1-03 定稿后对齐。
# W1-03 定稿前，本文件不作为正式许可证政策。
# 当前例外：无
permittedLicenses:
  - MIT
  - GPL-3.0
exceptions: []
''');

    expect(
      decide(package: 'a', licenses: const ['MIT'], policy: policy).allowed,
      isTrue,
    );
    expect(
      decide(package: 'b', licenses: const ['GPL-2.0'], policy: policy).allowed,
      isFalse,
    );
    expect(
      decide(package: 'c', licenses: const ['MPL-2.0'], policy: policy).allowed,
      isFalse,
    );
    expect(
      decide(package: 'd', licenses: const [], policy: policy).detail,
      '未识别许可',
    );

    final withException = parsePolicy('''
# 临时白名单，待 W1-03 定稿后对齐。
# W1-03 定稿前，本文件不作为正式许可证政策。
permittedLicenses:
  - MIT
exceptions:
  - package: reviewed
    license: MPL-2.0
    reason: 仅测试例外记录，不代表允许 MPL-2.0 进入产品依赖。
''');
    final allowed = decide(
      package: 'reviewed',
      licenses: const ['MPL-2.0'],
      policy: withException,
    );
    expect(allowed.allowed, isTrue);
    expect(allowed.usedException, isTrue);
    expect(
      decide(
        package: 'other',
        licenses: const ['MPL-2.0'],
        policy: withException,
      ).allowed,
      isFalse,
    );
  });

  test('detector recognizes the MIT license text', () async {
    final ids = await detectLicenseIds(_mit);
    expect(ids, contains('MIT'));
  });
}

const _mit = '''
MIT License

Copyright (c) 2026 Example

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';
