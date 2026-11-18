// Generated from packages/lingo_protocol/schema/*.schema.json.
// Do not edit by hand. Regenerate with:
//
//   python3 packages/lingo_protocol/tool/generate_types.py
//
// CI runs that script with --check and fails when this file is stale.

import '../decode.dart';

/// 已与服务端对齐的任务类型，供网关按任务路由。三份 v0 输出载荷不重复携带它；它属于请求。请求契约不在本 PR。
enum TaskType {
  scenePlan('scene_plan'),
  turn('turn'),
  bridge('bridge'),
  turnAnalysis('turn_analysis'),
  summarize('summarize'),
  skeleton('skeleton'),
  ;

  const TaskType(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, TaskType> byWire = {
    'scene_plan': TaskType.scenePlan,
    'turn': TaskType.turn,
    'bridge': TaskType.bridge,
    'turn_analysis': TaskType.turnAnalysis,
    'summarize': TaskType.summarize,
    'skeleton': TaskType.skeleton,
  };

  static TaskType fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 回合后分析的观察类别，取自技术方案 turn_analysis 示例。pronunciation 能否拿到证据，文档写明尚待核实，v0
/// 仍保留这个枚举值。
enum ObservationKind {
  grammar('grammar'),
  lexical('lexical'),
  pragmatic('pragmatic'),
  pronunciation('pronunciation'),
  ;

  const ObservationKind(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, ObservationKind> byWire = {
    'grammar': ObservationKind.grammar,
    'lexical': ObservationKind.lexical,
    'pragmatic': ObservationKind.pragmatic,
    'pronunciation': ObservationKind.pronunciation,
  };

  static ObservationKind fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 本句的表情标签，同时给立绘使用。提案，待评审。技术方案示例在台词上写了 emotion=warm，在 image_requests 上写了
/// expression=smile，两处不一致，而且文档没有已定的表情枚举（表情数量待美术确定）。v0 只保留这一个表情字段，不再设置
/// emotion。warm 不是合法值。代码如何把枚举映射到立绘资源键，不在本 schema 里。
enum TurnLineExpression {
  neutral('neutral'),
  smile('smile'),
  happy('happy'),
  surprised('surprised'),
  sad('sad'),
  troubled('troubled'),
  ;

  const TurnLineExpression(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, TurnLineExpression> byWire = {
    'neutral': TurnLineExpression.neutral,
    'smile': TurnLineExpression.smile,
    'happy': TurnLineExpression.happy,
    'surprised': TurnLineExpression.surprised,
    'sad': TurnLineExpression.sad,
    'troubled': TurnLineExpression.troubled,
  };

  static TurnLineExpression fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 本场目标推进，取自技术方案示例。
enum GoalProgress {
  advancing('advancing'),
  stalled('stalled'),
  resolved('resolved'),
  ;

  const GoalProgress(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, GoalProgress> byWire = {
    'advancing': GoalProgress.advancing,
    'stalled': GoalProgress.stalled,
    'resolved': GoalProgress.resolved,
  };

  static GoalProgress fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 槽位类型：背景、立绘、关键 CG。取自技术方案示例和图像管线说明。这里的 expression 是槽位种类，不是表情取值；表情取值只在
/// lines[].expression。
enum ImageSlot {
  background('background'),
  expression('expression'),
  cg('cg'),
  ;

  const ImageSlot(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, ImageSlot> byWire = {
    'background': ImageSlot.background,
    'expression': ImageSlot.expression,
    'cg': ImageSlot.cg,
  };

  static ImageSlot fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 优先级。技术方案示例只有 low 和 normal，v0 不另加取值。
enum ImagePriority {
  low('low'),
  normal('normal'),
  ;

  const ImagePriority(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, ImagePriority> byWire = {
    'low': ImagePriority.low,
    'normal': ImagePriority.normal,
  };

  static ImagePriority fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 笔记种类。技术方案示例只给了 fact。方案页提案把种类收成这五项，v0 采纳该枚举。
enum MemoryKind {
  fact('fact'),
  relationship('relationship'),
  threadOpen('thread_open'),
  threadClose('thread_close'),
  world('world'),
  ;

  const MemoryKind(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, MemoryKind> byWire = {
    'fact': MemoryKind.fact,
    'relationship': MemoryKind.relationship,
    'thread_open': MemoryKind.threadOpen,
    'thread_close': MemoryKind.threadClose,
    'world': MemoryKind.world,
  };

  static MemoryKind fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 可选的输入方式提示，对应已定的三种输入：voice 语音、typing 打字、word_choice
/// 选字。技术方案的对白示例没有这个字段，三种输入是玩法而不是模型输出，因此这里只是提案，并且可选。schema 不规定它和 choices 必须如何搭配。
enum InputModeHint {
  voice('voice'),
  typing('typing'),
  wordChoice('word_choice'),
  ;

  const InputModeHint(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, InputModeHint> byWire = {
    'voice': InputModeHint.voice,
    'typing': InputModeHint.typing,
    'word_choice': InputModeHint.wordChoice,
  };

  static InputModeHint fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}

/// 注入方式，取自技术方案示例：NPC 复用句式、目标需要、场景道具。不增加显式纠错或测验类取值。
enum WeaknessStrategy {
  npcReusesForm('npc_reuses_form'),
  goalRequires('goal_requires'),
  propInScene('prop_in_scene'),
  ;

  const WeaknessStrategy(this.wire);

  /// JSON string for this value.
  final String wire;

  static const Map<String, WeaknessStrategy> byWire = {
    'npc_reuses_form': WeaknessStrategy.npcReusesForm,
    'goal_requires': WeaknessStrategy.goalRequires,
    'prop_in_scene': WeaknessStrategy.propInScene,
  };

  static WeaknessStrategy fromWire(String wire, {String path = ''}) {
    return enumFromWire(wire, byWire, path);
  }
}
