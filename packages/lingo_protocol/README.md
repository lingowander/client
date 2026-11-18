# lingo_protocol

语遇 Lingowander 的回合契约，JSON Schema draft 2020-12，当前是 v0。客户端（Dart）和服务端（Go）以后可以从这里生成类型。本目录只放契约、样例和校验，不接模型服务，也不生成业务代码。

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

这里只建议工具，本 PR 不生成代码。生成前把 `schema/` 下的四个文件一起交给生成器，让它按 `$id` 解析引用。如果某个生成器不会跨文件解析 URN，先把 `$ref` 打成单文件再生成，例如用 `@apidevtools/json-schema-ref-parser`。

- Go 结构体：[atombender/go-jsonschema](https://github.com/atombender/go-jsonschema) 或 [omissis/go-jsonschema](https://github.com/omissis/go-jsonschema)。
- Go 校验：[santhosh-tekuri/jsonschema](https://github.com/santhosh-tekuri/jsonschema) 的 v6 支持 draft 2020-12。技术方案只写了「jsonschema 库」，具体库还没定，这是建议。
- Dart 结构体：先打包 `$ref`，再用 [quicktype](https://github.com/glideapps/quicktype) 的 `--lang dart --src-lang schema`。线上字段保持 snake_case；Dart 字段若用驼峰，用明确的 JSON 键注解对应，不要改线上名字。
- 生成出来的类型不能代替校验。模型输出在两端都还要用 schema 再验一次。

OpenAPI、Flutter 工程和 Go 模块不在本目录。仓库骨架由别的任务负责。
