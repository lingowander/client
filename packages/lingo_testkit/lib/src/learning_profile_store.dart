// SPDX-License-Identifier: GPL-3.0-only

import 'language_pair.dart';

/// 一次写入某个语言对档案的占位信号。
///
/// [marker] 是不透明字符串，不是分数、等级或百分比。
final class LearningSignal {
  const LearningSignal({required this.pair, required this.marker});

  final LanguagePair pair;
  final String marker;

  @override
  String toString() => 'LearningSignal($pair, $marker)';
}

/// 某个语言对档案的可比较投影。
///
/// 参考实现按信号到达顺序保存 [markers]。lingo_core 的适配器可以改用别的
/// 投影，只要它只反映这一语言对自己的状态，并且可按值比较。
final class ProfileSnapshot {
  ProfileSnapshot(List<String> markers)
    : markers = List<String>.unmodifiable(markers);

  final List<String> markers;

  @override
  bool operator ==(Object other) {
    if (other is! ProfileSnapshot || other.markers.length != markers.length) {
      return false;
    }
    for (var index = 0; index < markers.length; index++) {
      if (other.markers[index] != markers[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(markers);

  @override
  String toString() => 'ProfileSnapshot($markers)';
}

/// 按（源语言，目标语言）分桶的学习档案。
///
/// 纯游戏对（源语言等于目标语言）不得产生档案。
/// 一个桶的快照只能由发给该桶的信号决定。
abstract interface class LearningProfileStore {
  void apply(LearningSignal signal);

  /// 该语言对还没有学习档案时返回 null。纯游戏对始终返回 null。
  ProfileSnapshot? snapshotFor(LanguagePair pair);
}
