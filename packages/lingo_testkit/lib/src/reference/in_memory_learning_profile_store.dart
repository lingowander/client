// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Lingowander
//
// 语遇 Lingowander 客户端的一部分。
// 本文件以 GNU General Public License v3.0 授权（仅此版本）。
// 完整文本见仓库根目录 LICENSE。

import '../language_pair.dart';
import '../learning_profile_store.dart';

/// 语言对画像的参考实现。
///
/// 每个非纯游戏语言对一条列表，只追加发给该对的占位标记。
/// 不计算薄弱点、不衰减、不生成学习计划。
final class InMemoryLearningProfileStore implements LearningProfileStore {
  final Map<LanguagePair, List<String>> _markers = {};

  @override
  void apply(LearningSignal signal) {
    if (signal.pair.isPureGame) {
      return;
    }
    _markers.putIfAbsent(signal.pair, () => <String>[]).add(signal.marker);
  }

  @override
  ProfileSnapshot? snapshotFor(LanguagePair pair) {
    final markers = _markers[pair];
    if (markers == null) {
      return null;
    }
    return ProfileSnapshot(List<String>.of(markers));
  }
}
