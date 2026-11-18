// SPDX-License-Identifier: GPL-3.0-only

/// 一档学习或游戏所使用的语言对。
///
/// [source] 与 [target] 相同表示纯游戏，不产生学习档案。
final class LanguagePair {
  const LanguagePair({required this.source, required this.target});

  final String source;
  final String target;

  bool get isPureGame => source == target;

  @override
  bool operator ==(Object other) {
    return other is LanguagePair &&
        other.source == source &&
        other.target == target;
  }

  @override
  int get hashCode => Object.hash(source, target);

  @override
  String toString() => '$source→$target';
}
