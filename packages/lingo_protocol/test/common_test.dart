import 'dart:math';

import 'package:lingo_protocol/lingo_protocol.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('common string conventions match the schema checks', () {
    for (final value in ['zh>en', 'zh-Hans>en', 'zh>zh']) {
      expect(() => checkLangPairKey(value, 'lang_pair_key'), returnsNormally);
    }
    expect(
      () => checkLangPairKey('zh=zh', 'lang_pair_key'),
      throwsA(isA<LingoProtocolException>()),
    );
    expect(() => checkSceneId('s_0042', 'scene_id'), returnsNormally);
    expect(
      () => checkSceneId('s_cafe_opening', 'scene_id'),
      throwsA(isA<LingoProtocolException>()),
    );
    expect(
      () => LanguagePair.fromJson({
        'source_lang': 'zh',
        'target_lang': 'en',
      }),
      throwsA(isA<LingoProtocolException>()),
    );
    final turnId = '00000000-0000-4000-8000-000000000001';
    expect(() => checkTurnId(turnId, 'turn_id'), returnsNormally);
    expect(
      () => checkTurnId(turnId.toUpperCase(), 'turn_id'),
      returnsNormally,
    );
    expect(
      () => checkTurnId('not-a-uuid', 'turn_id'),
      throwsA(isA<LingoProtocolException>()),
    );
    expect(
      () => checkTurnId('00000000000040008000000000000001', 'turn_id'),
      throwsA(isA<LingoProtocolException>()),
    );
    for (final value in TaskType.values) {
      expect(TaskType.fromWire(value.wire), value);
    }
    expect(
      () => TaskType.fromWire('quiz'),
      throwsA(isA<LingoProtocolException>()),
    );
  });

  test('generateTurnId is a version-4 uuid the schema accepts', () {
    final id = generateTurnId(random: Random(1));
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(generateTurnId(random: Random(1)), id);
    final json = decodeObject(
      exampleText('turn_output', 'valid_cafe_opening.json'),
    );
    json['turn_id'] = id;
    expect(schemaAccepts('turn_output', json), isTrue);
    expect(TurnOutput.fromJson(json).turnId, id);

    final upper = '00000000-0000-4000-8000-000000000001'.toUpperCase();
    json['turn_id'] = upper;
    expect(schemaAccepts('turn_output', json), isTrue);
    expect(TurnOutput.fromJson(json).turnId, upper);
  });

  test('pure-game pair and empty weakness targets round-trip', () {
    final plan = WeaknessPlan.fromJson(
      decodeJson(exampleText('weakness_plan', 'valid_zh_zh_empty.json')),
    );
    expect(plan.pair.src, 'zh');
    expect(plan.pair.tgt, 'zh');
    expect(plan.targets, isEmpty);
    expect(
      () => plan.targets.add(
        WeaknessTarget(
          weaknessId: 'w12',
          strategy: WeaknessStrategy.goalRequires,
          budgetPerScene: 1,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('decodePayload rejects an unknown schema_name', () {
    final json =
        decodeObject(exampleText('turn_output', 'valid_cafe_opening.json'));
    json['schema_name'] = 'turn_output@1';
    expect(schemaAccepts('turn_output', json), isFalse);
    expect(
      () => decodePayload(json),
      throwsA(
        isA<LingoProtocolException>().having(
          (error) => error.path,
          'path',
          '/schema_name',
        ),
      ),
    );
    expect(() => decodePayload(<Object>['turn_output']),
        throwsA(isA<LingoProtocolException>()));
  });
}
