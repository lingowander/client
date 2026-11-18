import 'dart:convert';

/// Rejection used by every lingo_protocol constructor and `fromJson`.
///
/// 容错策略是失败并指出位置，不是猜测或降级：
///
/// * 未知字段被拒绝，不忽略，也不放进扩展 map。
/// * 未知枚举被拒绝，不改写成 `neutral` 或其他默认值。
/// * 不认识的 `schema_name` / `schema_version` 被拒绝，不按别的版本解读。
/// * 可选字段的缺省是省略该键，解码为 `null`。JSON `null` 会被拒绝。
///
/// [path] 是 JSON Pointer。手写构造时则是字段名。调用方捕获本异常后应丢弃
/// 整份载荷，不要用已经读到的部分字段继续往下走。
final class LingoProtocolException implements Exception {
  const LingoProtocolException({required this.path, required this.message});

  final String path;
  final String message;

  @override
  String toString() => 'LingoProtocolException($path): $message';
}

/// Appends one JSON Pointer token. An empty [path] means the document root.
String childPath(String path, Object token) {
  final escaped = token.toString().replaceAll('~', '~0').replaceAll('/', '~1');
  return '$path/$escaped';
}

String _here(String path) => path.isEmpty ? '/' : path;

Map<String, Object?> _asObject(Object? json, String path) {
  if (json is! Map) {
    throw LingoProtocolException(path: _here(path), message: '期望 JSON 对象。');
  }
  final map = <String, Object?>{};
  for (final entry in json.entries) {
    final key = entry.key;
    if (key is! String) {
      throw LingoProtocolException(path: _here(path), message: '对象的键不是字符串。');
    }
    map[key] = entry.value as Object?;
  }
  return map;
}

/// Reads a closed object. Keys outside [allowed] are rejected.
Map<String, Object?> readObject(
  Object? json,
  String path,
  Set<String> allowed,
) {
  final map = _asObject(json, path);
  final unknown = [
    for (final key in map.keys)
      if (!allowed.contains(key)) key,
  ]..sort();
  if (unknown.isNotEmpty) {
    final names = unknown.map(jsonEncode).join('、');
    throw LingoProtocolException(
      path: _here(path),
      message: '未知字段 $names。lingo_protocol 的对象是封闭的：'
          '未知字段会被拒绝，不会被忽略，也不会被保留。',
    );
  }
  return map;
}

/// How many known properties a decoded object actually carried.
///
/// Required fields are always counted. Optional fields count only when the
/// decoded value is non-null, which matches "the key was present".
void checkPropertyCount(
  String path, {
  required int present,
  int? minProperties,
  int? maxProperties,
}) {
  if (minProperties != null && present < minProperties) {
    throw LingoProtocolException(
      path: _here(path),
      message: '至少需要 $minProperties 个字段，实际有 $present 个。',
    );
  }
  if (maxProperties != null && present > maxProperties) {
    throw LingoProtocolException(
      path: _here(path),
      message: '最多允许 $maxProperties 个字段，实际有 $present 个。',
    );
  }
}

Never _missing(String path, String key) {
  throw LingoProtocolException(
    path: childPath(path, key),
    message: '缺少必填字段 $key。',
  );
}

Never _rejectNull(String path, String key) {
  throw LingoProtocolException(
    path: childPath(path, key),
    message: '字段 $key 不能是 null。可选字段用省略表示缺省。',
  );
}

String validateString(
  String value,
  String path, {
  int? minLength,
  int? maxLength,
  RegExp? pattern,
  String? format,
}) {
  if (minLength != null && value.length < minLength) {
    throw LingoProtocolException(
      path: path,
      message: '长度不能小于 $minLength。',
    );
  }
  if (maxLength != null && value.length > maxLength) {
    throw LingoProtocolException(
      path: path,
      message: '长度不能大于 $maxLength。',
    );
  }
  if (format != null) {
    if (format != 'uuid') {
      throw LingoProtocolException(
        path: path,
        message: '解码器不支持 format $format。',
      );
    }
    if (!_uuidPattern.hasMatch(value)) {
      throw LingoProtocolException(
        path: path,
        message: '不是带连字符的 UUID（xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）。',
      );
    }
  }
  if (pattern != null && !pattern.hasMatch(value)) {
    throw LingoProtocolException(
      path: path,
      message: '不符合 pattern ${pattern.pattern}。',
    );
  }
  return value;
}

/// Integers the schema accepts as `type: integer`.
///
/// A JSON number with no fractional part is an integer, so `1.0` is accepted
/// and stored as `1`. Doubles are accepted only inside ±2^53, where every
/// integer is exact. Larger JSON integers become imprecise in `dart:convert`
/// and are rejected instead of rounded.
int validateInteger(
  Object? value,
  String path, {
  int? minimum,
  int? maximum,
}) {
  if (value is bool || value is! num) {
    throw LingoProtocolException(path: path, message: '期望整数。');
  }
  final int integer;
  if (value is int) {
    integer = value;
  } else {
    final asDouble = value.toDouble();
    if (!asDouble.isFinite || asDouble != asDouble.roundToDouble()) {
      throw LingoProtocolException(path: path, message: '期望整数，不能带小数。');
    }
    if (asDouble.abs() > _maxExactInteger) {
      throw LingoProtocolException(
        path: path,
        message: '整数超出 Dart 能精确表示的 JSON 数字范围（±2^53），已拒绝而不是四舍五入。',
      );
    }
    integer = asDouble.toInt();
  }
  if (minimum != null && integer < minimum) {
    throw LingoProtocolException(path: path, message: '不能小于 $minimum。');
  }
  if (maximum != null && integer > maximum) {
    throw LingoProtocolException(path: path, message: '不能大于 $maximum。');
  }
  return integer;
}

double validateNumber(
  Object? value,
  String path, {
  num? minimum,
  num? maximum,
}) {
  if (value is bool || value is! num) {
    throw LingoProtocolException(path: path, message: '期望数字。');
  }
  final number = value.toDouble();
  if (!number.isFinite) {
    throw LingoProtocolException(path: path, message: '数字必须是有限值。');
  }
  if (minimum != null && number < minimum) {
    throw LingoProtocolException(path: path, message: '不能小于 $minimum。');
  }
  if (maximum != null && number > maximum) {
    throw LingoProtocolException(path: path, message: '不能大于 $maximum。');
  }
  return number;
}

String readConstString(
  Map<String, Object?> json,
  String key,
  String path,
  String expected,
) {
  final value = readRequiredString(json, key, path);
  if (value != expected) {
    throw LingoProtocolException(
      path: childPath(path, key),
      message: '$key 必须是 ${jsonEncode(expected)}，实际是 ${jsonEncode(value)}。'
          '不认识的取值会被拒绝。',
    );
  }
  return value;
}

int readConstInt(
  Map<String, Object?> json,
  String key,
  String path,
  int expected,
) {
  final value = readRequiredInteger(json, key, path);
  if (value != expected) {
    throw LingoProtocolException(
      path: childPath(path, key),
      message: '$key 必须是 $expected，实际是 $value。不认识的契约版本会被拒绝，不会按别的版本猜测。',
    );
  }
  return value;
}

String readRequiredString(
  Map<String, Object?> json,
  String key,
  String path, {
  void Function(String value, String path)? check,
  int? minLength,
  int? maxLength,
  RegExp? pattern,
  String? format,
}) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (value is! String) {
    throw LingoProtocolException(path: pointer, message: '期望字符串。');
  }
  if (check != null) {
    check(value, pointer);
    return value;
  }
  return validateString(
    value,
    pointer,
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
  );
}

String? readOptionalString(
  Map<String, Object?> json,
  String key,
  String path, {
  void Function(String value, String path)? check,
  int? minLength,
  int? maxLength,
  RegExp? pattern,
  String? format,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final pointer = childPath(path, key);
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (value is! String) {
    throw LingoProtocolException(path: pointer, message: '期望字符串。');
  }
  if (check != null) {
    check(value, pointer);
    return value;
  }
  return validateString(
    value,
    pointer,
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
  );
}

int readRequiredInteger(
  Map<String, Object?> json,
  String key,
  String path, {
  int? minimum,
  int? maximum,
}) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  return validateInteger(value, pointer, minimum: minimum, maximum: maximum);
}

double readRequiredNumber(
  Map<String, Object?> json,
  String key,
  String path, {
  void Function(double value, String path)? check,
  num? minimum,
  num? maximum,
}) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (check != null) {
    if (value is bool || value is! num) {
      throw LingoProtocolException(path: pointer, message: '期望数字。');
    }
    final number = value.toDouble();
    check(number, pointer);
    return number;
  }
  return validateNumber(value, pointer, minimum: minimum, maximum: maximum);
}

double? readOptionalNumber(
  Map<String, Object?> json,
  String key,
  String path, {
  void Function(double value, String path)? check,
  num? minimum,
  num? maximum,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final pointer = childPath(path, key);
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (check != null) {
    if (value is bool || value is! num) {
      throw LingoProtocolException(path: pointer, message: '期望数字。');
    }
    final number = value.toDouble();
    check(number, pointer);
    return number;
  }
  return validateNumber(value, pointer, minimum: minimum, maximum: maximum);
}

bool readRequiredBool(Map<String, Object?> json, String key, String path) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (value is! bool) {
    throw LingoProtocolException(path: pointer, message: '期望布尔值。');
  }
  return value;
}

T enumFromWire<T>(String wire, Map<String, T> byWire, String path) {
  final value = byWire[wire];
  if (value != null) {
    return value;
  }
  final allowed = byWire.keys.join('、');
  throw LingoProtocolException(
    path: path,
    message: '未知枚举值 ${jsonEncode(wire)}。允许：$allowed。未知枚举不会被改写成默认值。',
  );
}

T readRequiredEnum<T>(
  Map<String, Object?> json,
  String key,
  String path,
  Map<String, T> byWire,
) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (value is! String) {
    throw LingoProtocolException(path: pointer, message: '期望字符串枚举。');
  }
  return enumFromWire(value, byWire, pointer);
}

T? readOptionalEnum<T>(
  Map<String, Object?> json,
  String key,
  String path,
  Map<String, T> byWire,
) {
  if (!json.containsKey(key)) {
    return null;
  }
  final pointer = childPath(path, key);
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  if (value is! String) {
    throw LingoProtocolException(path: pointer, message: '期望字符串枚举。');
  }
  return enumFromWire(value, byWire, pointer);
}

typedef ModelDecoder<T> = T Function(Object? json, {String path});

T readRequiredModel<T>(
  Map<String, Object?> json,
  String key,
  String path,
  ModelDecoder<T> decode,
) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  return decode(value, path: pointer);
}

T? readOptionalModel<T>(
  Map<String, Object?> json,
  String key,
  String path,
  ModelDecoder<T> decode,
) {
  if (!json.containsKey(key)) {
    return null;
  }
  final pointer = childPath(path, key);
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  return decode(value, path: pointer);
}

List<T> _decodeList<T>(
  Object? value,
  String pointer,
  T Function(Object? item, String itemPath) decodeItem, {
  int? minItems,
  int? maxItems,
}) {
  if (value is! List) {
    throw LingoProtocolException(path: pointer, message: '期望数组。');
  }
  if (minItems != null && value.length < minItems) {
    throw LingoProtocolException(
      path: pointer,
      message: '至少需要 $minItems 项，实际有 ${value.length} 项。',
    );
  }
  if (maxItems != null && value.length > maxItems) {
    throw LingoProtocolException(
      path: pointer,
      message: '最多允许 $maxItems 项，实际有 ${value.length} 项。',
    );
  }
  final items = <T>[
    for (var i = 0; i < value.length; i++)
      decodeItem(value[i] as Object?, childPath(pointer, i)),
  ];
  return List<T>.unmodifiable(items);
}

List<T> readRequiredList<T>(
  Map<String, Object?> json,
  String key,
  String path,
  T Function(Object? item, String itemPath) decodeItem, {
  int? minItems,
  int? maxItems,
}) {
  final pointer = childPath(path, key);
  if (!json.containsKey(key)) {
    _missing(path, key);
  }
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  return _decodeList(
    value,
    pointer,
    decodeItem,
    minItems: minItems,
    maxItems: maxItems,
  );
}

List<T>? readOptionalList<T>(
  Map<String, Object?> json,
  String key,
  String path,
  T Function(Object? item, String itemPath) decodeItem, {
  int? minItems,
  int? maxItems,
}) {
  if (!json.containsKey(key)) {
    return null;
  }
  final pointer = childPath(path, key);
  final value = json[key];
  if (value == null) {
    _rejectNull(path, key);
  }
  return _decodeList(
    value,
    pointer,
    decodeItem,
    minItems: minItems,
    maxItems: maxItems,
  );
}

String readStringItem(
  Object? item,
  String path, {
  void Function(String value, String path)? check,
  int? minLength,
  int? maxLength,
  RegExp? pattern,
  String? format,
}) {
  if (item is! String) {
    throw LingoProtocolException(path: path, message: '期望字符串。');
  }
  if (check != null) {
    check(item, path);
    return item;
  }
  return validateString(
    item,
    path,
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
  );
}

bool deepListEquals<T>(List<T>? left, List<T>? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left == null || right == null || left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

int deepListHash(List<Object?>? items) {
  if (items == null) {
    return null.hashCode;
  }
  return Object.hashAll(items);
}

// 2^53. Every integer in this closed range is exact as an IEEE-754 double.
const int _maxExactInteger = 9007199254740992;

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
