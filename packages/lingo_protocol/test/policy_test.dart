import 'package:lingo_protocol/lingo_protocol.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('unknown fields are rejected and not preserved', () {
    final json = _opening();
    json['emotion'] = 'warm';
    expect(schemaAccepts('turn_output', json), isFalse);
    final error = _rejection(() => TurnOutput.fromJson(json));
    expect(error.path, '/');
    expect(error.message, contains('未知字段'));
    expect(error.message, contains('emotion'));
    expect(error.message, contains('不会被忽略'));
  });

  test('replacing expression with emotion is an unknown field', () {
    final json = _opening();
    final lines = json['lines'] as List<dynamic>;
    final line = Map<String, dynamic>.from(lines[0] as Map);
    line['emotion'] = line.remove('expression');
    lines[0] = line;
    expect(schemaAccepts('turn_output', json), isFalse);
    final error = _rejection(() => TurnOutput.fromJson(json));
    expect(error.message, contains('未知字段'));
    expect(error.message, contains('emotion'));
  });

  test('unknown enum values are rejected and not coerced', () {
    final original = decodeJson(
      exampleText('turn_output', 'invalid_expression.json'),
    );
    expect(schemaAccepts('turn_output', original), isFalse);
    final error = _rejection(() => TurnOutput.fromJson(original));
    expect(error.path, '/lines/0/expression');
    expect(error.message, contains('未知枚举'));
    expect(error.message, contains('warm'));
    expect(error.message, contains('不会被改写'));
  });

  test('every line expression round-trips and passes the schema', () {
    final json = decodeObject(
      exampleText('turn_output', 'invalid_expression.json'),
    );
    final line = (json['lines'] as List<dynamic>)[0] as Map<String, dynamic>;
    for (final expression in TurnLineExpression.values) {
      line['expression'] = expression.wire;
      expect(schemaAccepts('turn_output', json), isTrue,
          reason: expression.wire);
      final output = TurnOutput.fromJson(json);
      expect(output.lines.single.expression, expression);
      expect(jsonEqual(json, output.toJson()), isTrue, reason: expression.wire);
    }
  });

  test('a wrong schema_version is rejected', () {
    final json = _opening();
    json['schema_version'] = 1;
    expect(schemaAccepts('turn_output', json), isFalse);
    final error = _rejection(() => decodePayload(json));
    expect(error.path, '/schema_version');
    expect(error.message, contains('不会按别的版本猜测'));
  });

  test('integral 0.0 is schema_version 0 and encodes as 0', () {
    final json = _opening();
    json['schema_version'] = 0.0;
    expect(schemaAccepts('turn_output', json), isTrue);
    final output = TurnOutput.fromJson(json);
    expect(output.schemaVersion, 0);
    expect(output.toJson()['schema_version'], 0);
    expect(jsonEqual(json, output.toJson()), isTrue);
  });

  test('JSON null is not a missing optional translation', () {
    final json = _opening();
    final line = (json['lines'] as List<dynamic>)[0] as Map<String, dynamic>;
    line['translation'] = null;
    expect(schemaAccepts('turn_output', json), isFalse);
    final error = _rejection(() => TurnOutput.fromJson(json));
    expect(error.path, '/lines/0/translation');
    expect(error.message, contains('不能是 null'));
  });

  test('omitted translation stays omitted and empty choices stay empty', () {
    final opening = TurnOutput.fromJson(
      decodeJson(exampleText('turn_output', 'valid_cafe_opening.json')),
    );
    expect(opening.lines[0].translation, isNotNull);
    expect(opening.lines[1].translation, isNull);
    final encodedLines = opening.toJson()['lines'] as List<dynamic>;
    final second = encodedLines[1] as Map<dynamic, dynamic>;
    expect(second.containsKey('translation'), isFalse);

    final remembered = decodeObject(
      exampleText('turn_output', 'valid_cafe_order_remembered.json'),
    );
    final omitted = TurnOutput.fromJson(remembered);
    expect(omitted.choices, isNull);
    expect(omitted.toJson().containsKey('choices'), isFalse);

    final emptyChoices = decodeObject(
      exampleText('turn_output', 'valid_cafe_order_remembered.json'),
    );
    emptyChoices['choices'] = <Object>[];
    expect(schemaAccepts('turn_output', emptyChoices), isTrue);
    final empty = TurnOutput.fromJson(emptyChoices);
    expect(empty.choices, isEmpty);
    expect(empty.toJson().containsKey('choices'), isTrue);
    expect(empty == omitted, isFalse);
  });

  test('decoded lists are unmodifiable and detached from the input', () {
    final line = TurnLine(
      lineId: 'l1',
      lang: 'en',
      text: 'Hello.',
      expression: TurnLineExpression.smile,
    );
    final lines = <TurnLine>[line];
    final output = _minimal(lines);
    lines.clear();
    expect(output.lines, hasLength(1));
    expect(
      () => output.lines.add(line),
      throwsUnsupportedError,
    );
  });

  test('equal payloads compare equal and a different turn id does not', () {
    final source = exampleText('turn_output', 'valid_cafe_opening.json');
    final first = TurnOutput.fromJson(decodeJson(source));
    final second = TurnOutput.fromJson(decodeJson(source));
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    final other = _opening();
    other['turn_id'] = '00000000-0000-4000-8000-000000000099';
    expect(TurnOutput.fromJson(other) == first, isFalse);
  });

  test('hand built values must satisfy the schema constraints', () {
    expect(
      () => TurnLine(
        lineId: 'L1',
        lang: 'en',
        text: 'Hello.',
        expression: TurnLineExpression.neutral,
      ),
      throwsA(isA<LingoProtocolException>()),
    );
    expect(
      () => TurnLine(
        lineId: 'l1',
        lang: 'en',
        text: '',
        expression: TurnLineExpression.neutral,
      ),
      throwsA(isA<LingoProtocolException>()),
    );
    expect(
      () => LanguagePair(src: 'zh', tgt: 'EN'),
      throwsA(isA<LingoProtocolException>()),
    );
    expect(() => SceneConstraints(), throwsA(isA<LingoProtocolException>()));
    expect(
      () => SceneConstraints(sceneIds: ['cafe']),
      throwsA(isA<LingoProtocolException>()),
    );
    final constraints = SceneConstraints(beatIds: ['b1']);
    expect(constraints.toJson(), {
      'beat_ids': ['b1']
    });
  });

  test('closed level_evidence rejects an extra dimension', () {
    final json = decodeObject(
      exampleText('turn_analysis', 'valid_zh_en_order.json'),
    );
    final evidence = json['level_evidence'] as Map<String, dynamic>;
    evidence['fluency'] = 0.2;
    expect(schemaAccepts('turn_analysis', json), isFalse);
    final error = _rejection(() => TurnAnalysis.fromJson(json));
    expect(error.path, '/level_evidence');
    expect(error.message, contains('未知字段'));
  });

  test('budget 1.0 is an integer and encodes as 1', () {
    final json = decodeObject(
      exampleText('weakness_plan', 'valid_zh_en_cafe.json'),
    );
    final target =
        (json['targets'] as List<dynamic>)[0] as Map<String, dynamic>;
    target['budget_per_scene'] = 1.0;
    expect(schemaAccepts('weakness_plan', json), isTrue);
    final plan = WeaknessPlan.fromJson(json);
    expect(plan.targets.first.budgetPerScene, 1);
    expect(jsonEqual(json, plan.toJson()), isTrue);
  });

  test('integers outside the exact JSON range are rejected', () {
    final source = exampleText(
      'weakness_plan',
      'valid_zh_en_cafe.json',
    ).replaceFirst(
      '"budget_per_scene": 1',
      '"budget_per_scene": 100000000000000000000',
    );
    expect(schemaAcceptsSource('weakness_plan', source), isTrue);
    final error = _rejection(() => WeaknessPlan.fromJson(decodeJson(source)));
    expect(error.message, contains('2^53'));
  });

  test('strategy, observation kind, and goal enums round-trip', () {
    final plan = decodeObject(
      exampleText('weakness_plan', 'invalid_strategy.json'),
    );
    final target =
        (plan['targets'] as List<dynamic>)[0] as Map<String, dynamic>;
    for (final strategy in WeaknessStrategy.values) {
      target['strategy'] = strategy.wire;
      expect(schemaAccepts('weakness_plan', plan), isTrue,
          reason: strategy.wire);
      expect(
        WeaknessPlan.fromJson(plan).targets.single.strategy,
        strategy,
      );
    }

    final analysis = decodeObject(
      exampleText('turn_analysis', 'invalid_kind.json'),
    );
    final observation =
        (analysis['observations'] as List<dynamic>)[0] as Map<String, dynamic>;
    for (final kind in ObservationKind.values) {
      observation['kind'] = kind.wire;
      expect(schemaAccepts('turn_analysis', analysis), isTrue,
          reason: kind.wire);
      expect(
        TurnAnalysis.fromJson(analysis).observations.single.kind,
        kind,
      );
    }

    final output = _opening();
    final state = output['scene_state'] as Map<String, dynamic>;
    for (final progress in GoalProgress.values) {
      state['goal_progress'] = progress.wire;
      expect(schemaAccepts('turn_output', output), isTrue,
          reason: progress.wire);
      expect(TurnOutput.fromJson(output).sceneState.goalProgress, progress);
    }
  });
}

Map<String, dynamic> _opening() {
  return decodeObject(exampleText('turn_output', 'valid_cafe_opening.json'));
}

LingoProtocolException _rejection(void Function() body) {
  try {
    body();
  } on LingoProtocolException catch (error) {
    return error;
  }
  fail('expected LingoProtocolException');
}

TurnOutput _minimal(List<TurnLine> lines) {
  return TurnOutput(
    turnId: '00000000-0000-4000-8000-000000000010',
    pair: LanguagePair(src: 'zh', tgt: 'en'),
    speaker: 'npc_mika',
    lines: lines,
    sceneState: SceneState(
      beatId: 'b1',
      goalProgress: GoalProgress.advancing,
      tension: 0.2,
    ),
    meta: PromptMeta(promptId: 'turn', promptVersion: '0.3.1'),
  );
}
