# lingo_protocol

语遇 Lingowander 的回合契约，JSON Schema draft 2020-12，当前是 v0。Dart 类型由 schema 生成，放在本目录。Go 类型还没有生成。本目录不接模型服务，样例都是虚构对白。

三份载荷各自带 `$id` 和整数 `schema_version`。共享定义在 `common`，载荷用 `$ref` 引用。对象都写了 `additionalProperties: false`，字段是 snake_case。没有使用 `oneOf`、`anyOf` 或 `allOf`。

## 目录

| 路径 | 作用 |
| --- | --- |
| `schema/common.schema.json` | 语言对、id、`task_type` 等共享定义。它本身不是一份回合载荷。 |
| `schema/turn_output.schema.json` | 对白模型每一回合的输出。 |
| `schema/turn_analysis.schema.json` | 回合后分析。 |
| `schema/weakness_plan.schema.json` | 无感薄弱点注入计划。 |
| `examples/<契约>/valid_*.json` | 应当通过的样例。每份契约至少两个。 |
| `examples/<契约>/invalid_*.json` | 应当被拒绝的样例。每份契约至少一个。 |
| `validate.py` | 校验全部样例，并检查下面列出的对齐约定。 |
| `lib/` | Dart 类型。`src/generated/` 由 schema 生成；`src/decode.dart` 和 `src/turn_id.dart` 是手写的。 |
| `tool/generate_types.py` | 从 `schema/` 生成 Dart。`--check` 确认生成物没有过期。 |
| `test/` | Dart 测试。正例要同时通过 JSON Schema 校验和类型往返，反例两边都拒绝。 |

`turn_output` 的两个合法样例都是「咖馆开局」：中文母语的学习者在这一场说英语，NPC 是 `npc_mika`。样例是虚构对白，不是真实用户数据。

## 用法

在客户端仓库根目录执行：

```bash
pip install -r packages/lingo_protocol/requirements.txt
python3 packages/lingo_protocol/validate.py
```

合法样例必须通过，非法样例必须失败。脚本只用 Python 和 `jsonschema`（开发依赖，MIT，不进客户端运行时），不访问网络，也不调用模型。

同一套检查也可以这样跑：

```bash
python3 -m unittest packages/lingo_protocol/tests/test_examples.py
```

Dart 类型在 `packages/lingo_protocol` 里检查。测试会调用上面的 Python 校验器，所以要先装 `requirements.txt`。

```bash
cd packages/lingo_protocol
dart pub get
python3 tool/generate_types.py --check
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos
dart test
```

没有运行时依赖。开发依赖是 `test` 和 `lints`，许可都是 BSD-3-Clause。JSON Schema 校验继续用已经在用的 Python `jsonschema`（MIT），只在开发和测试里调用。没有使用 pub.dev 上许可显示为 unknown 的 `json_schema` 包。

## 已对齐的约定

这些是和本契约一起定下来的字段约定。

1. 语言对在 `turn_output`、`turn_analysis`、`weakness_plan` 里都是对象 `pair`：`{src, tgt}`，两个值都是语言代码字符串。`src` 与 `tgt` 相同表示纯游戏。字符串 `zh>en` 不是载荷字段。
2. `lang_pair_key` 定义在 common，pattern 是 `^[a-z]{2,3}(-[A-Za-z0-9]+)*>[a-z]{2,3}(-[A-Za-z0-9]+)*$`。它只给需要 map 键的地方用。三份 v0 载荷没有这种 map，所以没有引用它。文档里的纯游戏记法 `zh=zh` 不符合这个 pattern；同语派生键是 `zh>zh`。
3. `turn_id`、`profile_id`、`event_id` 是 UUID 字符串（`format: uuid`）。`event_id` 建议用 UUIDv7，方便按时间排序；schema 不检查版本位。`scene_id` 是 `^s_[0-9]{4,}$`，例如 `s_0042`。
4. `schema_version` 一律是整数。三份契约各自从 0 独立递增。文档里的 `turn_output@1` 只是写法，不是字段值。档案上的存档迁移版本不在本目录。
5. common 里的 `task_type` 枚举是 `scene_plan`、`turn`、`bridge`、`turn_analysis`、`summarize`、`skeleton`。它属于请求，三份输出载荷不重复携带。
6. `turn_id` 由客户端生成，放在请求里，用于幂等和重放。`turn_output` 和 `turn_analysis` 必须回显它。`weakness_plan` 不回显。
7. 台词上的 `translation` 不是必填。字段保留为可选，并标注「待定：译文由谁生成」。

## 字段总览

必填字段写在前面。类型细节以 schema 文件为准。

### turn_output

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `schema_name` | 是 | 固定为 `turn_output`。 |
| `schema_version` | 是 | 整数 `0`。 |
| `turn_id` | 是 | 回显客户端生成的 UUID。 |
| `pair` | 是 | `{src, tgt}`。 |
| `speaker` | 是 | 说话角色 id，例如 `npc_mika`。 |
| `lines` | 是 | 至少一句。每句含 `line_id`、`lang`、`text`、`expression`。`translation` 可选。 |
| `lines[].expression` | 是 | 提案，待评审。只保留这一个表情字段，枚举为 `neutral`、`smile`、`happy`、`surprised`、`sad`、`troubled`。 |
| `choices` | 否 | 选项。每项含 `id`、`lang`、`text`、`intent`。 |
| `input_mode_hint` | 否 | `voice`、`typing`、`word_choice`。 |
| `scene_state` | 是 | `beat_id`、`goal_progress`（`advancing`、`stalled`、`resolved`）、`tension`。`next_beat_hint` 可选。 |
| `proposed_events` | 否 | `event_key` 与 `evidence`。`evidence_line_ids` 可选。这里用事件键，不用 `event_id`。 |
| `image_requests` | 否 | `slot`（`background`、`expression`、`cg`）和 `priority`（`low`、`normal`）。可选 `npc_id`、`semantic_key`、`camera`。`slot` 取值 `expression` 表示立绘槽位，不是第二个表情字段。 |
| `memory_notes` | 否 | `kind`、`text`、`entities`。`confidence` 可选。 |
| `meta` | 是 | `prompt_id` 与 `prompt_version`。 |

`lines` 和 `choices` 的 `text` 是玩家可见内容，里面不能出现学习元信息。schema 查不了这句话，要靠后续的语义校验。`proposed_events` 只是提议。

### turn_analysis

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `schema_name` | 是 | 固定为 `turn_analysis`。 |
| `schema_version` | 是 | 整数 `0`。 |
| `turn_id` | 是 | 回显本回合的 UUID。 |
| `pair` | 是 | `{src, tgt}`。分析按这个语言对分桶。 |
| `intent_success` | 是 | 沟通意图是否达成。不是给玩家看的分数。 |
| `observations` | 是 | 可为空。每项含 `kind`（`grammar`、`lexical`、`pragmatic`、`pronunciation`）、`descriptor`、`evidence_span`、`severity`。错误点和词汇或语法上被注意到的条目都在这里，没有单独的命中列表。 |
| `level_evidence` | 是 | `production` 与 `comprehension`，都在 0 到 1。 |
| `engagement_signals` | 是 | `turn_length` 与 `choice_diversity`。 |
| `analysis_confidence` | 否 | 0 到 1。阈值未定。 |

### weakness_plan

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `schema_name` | 是 | 固定为 `weakness_plan`。 |
| `schema_version` | 是 | 整数 `0`。 |
| `pair` | 是 | `{src, tgt}`。 |
| `targets` | 是 | 可为空。纯游戏样例就是空数组。 |
| `targets[].weakness_id` | 是 | 薄弱点 id。 |
| `targets[].strategy` | 是 | `npc_reuses_form`、`goal_requires`、`prop_in_scene`。 |
| `targets[].budget_per_scene` | 是 | 这一场的次数上限。示例值 1 不是 schema 默认值。 |
| `targets[].kind` | 否 | 与分析观察相同的四类。 |
| `targets[].scene_constraints` | 否 | `scene_ids` 用 `scene_id`，`beat_ids` 用普通标识。 |
| `targets[].cooldown.min_scenes_between` | 否 | 至少隔开的场数。单位用「场」仍是提案。 |

## Dart 类型

线上字段保持 snake_case。Dart 字段用驼峰，`toJson` 写回原来的键。类型不可变：字段是 `final`，数组在构造时复制成不可修改的列表。`==` 和 `hashCode` 按字段值比较。

`lines[].translation` 生成成 `String?`。省略该键解码为 `null`，编码时不再写出这个键。字段仍标注「待定：译文由谁生成」，类型没有替它决定译文从哪来。

`turn_id` 用 `generateTurnId` 生成，得到带连字符的 UUID 第 4 版。请求对象不在这套 schema 里，所以这里只提供 id，不提供请求类型。`turn_output` 和 `turn_analysis` 回显这个 id；`weakness_plan` 没有这个字段。

### 未知字段和未知枚举

解码遇到契约外的数据时，策略是失败并指出位置，不是猜测、丢掉或改成默认值。信号是 `LingoProtocolException`。`path` 是 JSON Pointer；手写构造时则是字段名。调用方捕获之后应丢掉整份载荷。

1. 未知字段：拒绝。异常里有字段名。不忽略，不放进扩展 map，也不参与 `toJson`。这和 schema 里的 `additionalProperties: false` 一致。
2. 未知枚举：拒绝。异常里有原始字符串和允许的取值。不会把不认识的表情改成 `neutral`，也不会发明一个 unknown 哨兵。
3. 错误的 `schema_name` 或 `schema_version`：拒绝。不按另一个版本解读。
4. 类型、pattern、format、范围、`minItems`、`minProperties` 不满足：拒绝。
5. 可选字段缺省：这是唯一保留下来的空缺。键不出现时解码为 `null`，编码时省略该键。JSON `null` 不合法，因为 schema 没有把这些字段标成可空。省略和空数组不是一回事，往返时保持原样。
6. JSON 数字 `1` 和 `1.0` 在整数约束上看成同一个数，编码时写成整数。`type: number` 的字段在 Dart 里是 `double`。

`format: uuid` 按本目录的校验脚本断言：必须是带连字符的 8-4-4-4-12 十六进制，不检查版本位。不接受去掉连字符，也不接受 `urn:uuid:` 前缀。

整数若超出 Dart 能从 JSON 数字里精确还原的范围（约 ±2^53），解码直接拒绝，不四舍五入。schema 本身不设上界，这个限制写在这里，避免静默丢精度。

生成器只实现 v0 schema 实际用到的关键字。schema 如果新出现 `oneOf`、`format` 以外的取值，或对象不再写 `additionalProperties: false`，生成脚本会失败，不会悄悄忽略。改完 schema 后重新生成，CI 用 `--check` 确认提交的 Dart 和 schema 一致。

## 版本策略

`schema_version` 是每份契约自己的整数，从 0 开始。改一份契约只递增那一份，另外两份保持不动。不要在同一个整数下改变字段的含义。

下面这些改动都要递增该契约的 `schema_version`，并修改 schema 里的 `const`：

- 删除或重命名字段，或改变类型。
- 改变枚举值的含义，或删掉一个仍被旧载荷使用的枚举值。
- 把可选字段改成必填，或把数值范围、pattern 收紧到旧载荷不再合法。

只增加可选字段，或在枚举末尾增加取值，对旧数据是兼容的，但新 schema 的 `const` 已经变了，写着旧 `schema_version` 的载荷不能拿去套新 schema。校验器遇到不认识的 `schema_version` 就拒绝，不猜。

旧字段保留一个周期后再删除：周期内同时接受当前版本和上一版本。周期有多长，文档没有写，这里不规定天数。v0 目前只有一个版本，校验脚本按文件名选择 schema，还没有多版本分流。

提示词版本是另一套编号。`meta.prompt_version` 只检查 `主.次.修` 的形态。提示词行为变化需要评测对比，那是发布流程，不是 schema 能替它做的检查。

## 生成 Dart 与 Go 类型

Dart 类型已经由 `tool/generate_types.py` 生成。脚本自己解析四个文件的 `$id` 和 URN `$ref`，不需要先把 schema 打成单文件。Go 仍然没有生成，下面只是建议：

- Go 结构体：[atombender/go-jsonschema](https://github.com/atombender/go-jsonschema) 或 [omissis/go-jsonschema](https://github.com/omissis/go-jsonschema)。
- Go 校验：[santhosh-tekuri/jsonschema](https://github.com/santhosh-tekuri/jsonschema) 的 v6 支持 draft 2020-12。技术方案只写了「jsonschema 库」，具体库还没定，这是建议。

生成出来的 Dart 类型会拒绝封闭对象里的未知字段和未知枚举，但不能代替 schema 校验。模型输出在两端都还要用 schema 再验一次。Dart 测试因此会调用 `validate.py`。

OpenAPI、Flutter 工程和 Go 模块不在本目录。仓库骨架由别的任务负责。
