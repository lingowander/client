// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Lingowander
//
// 语遇 Lingowander 客户端的一部分。
// 本文件以 GNU General Public License v3.0 授权（仅此版本）。
// 完整文本见仓库根目录 LICENSE。

import 'package:lingo_testkit/lingo_testkit.dart';
import 'package:test/test.dart';

void main() {
  test('workspace 已链接占位包，但还没有可对接的奖励或契约类型', () {
    expect(linkedPlaceholderPackages, <String>['lingo_core', 'lingo_protocol']);
  });
}
