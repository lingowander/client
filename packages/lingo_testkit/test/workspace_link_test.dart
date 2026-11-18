// SPDX-License-Identifier: GPL-3.0-only

import 'package:lingo_testkit/lingo_testkit.dart';
import 'package:test/test.dart';

void main() {
  test('workspace 已链接占位包，但还没有可对接的奖励或契约类型', () {
    expect(linkedPlaceholderPackages, <String>['lingo_core', 'lingo_protocol']);
  });
}
