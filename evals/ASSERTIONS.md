<!-- SPDX-License-Identifier: GPL-3.0-only -->

# 确定性断言约定

评测用例分两列期望：`expectations.deterministic` 与可选的 `expectations.scored`。确定性断言判断结构、不变量和预算，结果只有通过或失败。评分型断言只记录模型或评审给出的印象，v0 不设通过阈值，不能决定用例成败。

用例文件的格式由 `evals/schema/eval_case.schema.json` 描述。本约定描述这些断言在运行器里应如何执行。v0 的校验脚本只检查用例文件本身，不调用模型。

## 必须用确定性断言的内容

下面这些行为一旦进入用例范围，就写成确定性断言。不要改用 LLM 评审来判断它们。

| 行为 | 断言类型 | 通过条件 |
| --- | --- | --- |
| 输出结构符合协议 schema | `schema_conforms` | JSON 通过指定草案 schema |
| 某份协议对象不应出现 | `schema_absent` | 该对象缺席，或显式为空且不带学习内容 |
| 必填字段存在 | `required_fields` | 列出的字段都存在且不是 null |
| 同一个 `reward_key` 只结算一次 | `reward_key_once` | 该 key 的成功结算次数 ≤ 1；重放不再增加 |
| 语言对分桶不串 | `language_pair_isolation` | 只读写声明的（源语言，目标语言）桶 |
| 不出现分数、等级、百分比 | `forbidden_content` | 结构化字段与玩家可见文本都没有禁用内容 |
| 字数预算 | `length_budget` | 玩家可见文本的 Unicode 标量值数量 ≤ `max_chars` |
| 延迟预算 | `latency_budget` | 单回合 mock 回放耗时 ≤ `max_ms` |

每条用例至少包含一条 `schema_conforms`，以及覆盖 `score`、`level`、`percentage` 两种表面（`structured_fields` 与 `player_visible_text`）的 `forbidden_content`。带 `reward` 标签的用例要有 `reward_key_once`。带 `language-pair` 标签的用例要有 `language_pair_isolation`。带 `budget` 标签的用例要有 `length_budget` 或 `latency_budget`。带 `pure-game` 标签时，源语言必须等于目标语言，并且用 `schema_absent` 声明 `weakness_plan` 缺席、用 `language_pair_isolation` 声明 `expect_learning_profile: false`。

`max_chars` 与 `max_ms` 在示例里是占位预算，用来固定字段形状，不是产品指标。

## 断言类型与写法

确定性断言与评分型断言使用不同的 `type` 闭集。写错列会被 schema 拒绝。

### `schema_conforms`

```yaml
type: schema_conforms
target: turn_output   # turn_output | turn_analysis | weakness_plan
```

`target` 是 lingo_protocol 草案的名字。W1-04 定稿前，运行器只应检查“是一个对象，且以后能挂上该 schema”，不要把示例里的字段名写成永久契约。

### `schema_absent`

```yaml
type: schema_absent
target: weakness_plan
```

用于纯游戏：源语言等于目标语言时，不产出学习计划。

### `required_fields`

```yaml
type: required_fields
target: turn_output
fields:
  - turn_id
  - utterances
```

只检查存在性，不检查文案。字段名在 W1-04 之前都是占位。

### `reward_key_once`

```yaml
type: reward_key_once
reward_key: placeholder.reward.greeting
```

运行器把同一 `reward_key` 的重复事件、乱序事件、换语言后重放的同一对白、以及整段重玩都送入账本。成功结算次数必须 ≤ 1。冷却区间内的再次尝试不得新增结算。冷却结束也不打开第二次结算。冷却按 key 计，不把其他 key 一起锁住。

### `language_pair_isolation`

```yaml
type: language_pair_isolation
source: zh
target: en
expect_learning_profile: true
```

`expect_learning_profile: false` 只用于源语言等于目标语言的纯游戏桶。该桶保持没有学习档案。其他语言对的信号不得改变这个桶；切回原来的语言对时，看到的是该桶自己的后续状态，而不是一份新档案。

### `forbidden_content`

```yaml
type: forbidden_content
surfaces:
  - structured_fields
  - player_visible_text
kinds:
  - score
  - level
  - percentage
```

`structured_fields`：载荷里不得出现表示分数、等级、百分比的字段（包括同义的数值槽）。`player_visible_text`：玩家能读到的字符串不得匹配这些禁用内容。匹配使用固定规则（字段名表、数字加百分号、明确的等级标记），不用另一只模型来判断。

### `length_budget`

```yaml
type: length_budget
target: player_visible_text
max_chars: 280
unit: unicode_scalars
```

按 Unicode 标量值计数，不按 UTF-8 字节，也不按模型 token。

### `latency_budget`

```yaml
type: latency_budget
scope: turn
max_ms: 1500
```

只度量本用例声明的 mock 回放。不连接真实模型，也不把网络抖动算进产品 SLO。

## 模型输出不确定时怎么断言

回合文本会变。确定性断言不把某一次生成的句子写成期望答案。

- 运行配置只能是 `provider: mock`。`mode: replay` 回放夹具，`mode: fixed_seed` 固定种子。v0 示例里的 `fixture_id` 只是占位名字，仓库不附带夹具，也不要据此去请求真实服务。
- 断言结构和不变量：schema、必填字段、`reward_key` 结算次数、语言对分桶、禁用内容、字数和延迟。
- 不断言措辞。不比较 NPC 的原句，不要求同义词表，不把“回答是否自然”放进确定性列。
- 需要固定输入时，固定的是玩家输入、语言对、场景占位状态和种子，不是模型的用词。

## 评分型断言如何隔离

评分型断言放在 `expectations.scored`，类型只有 `llm_judge` 和 `rubric_score`。

```yaml
scored:
  - type: llm_judge
    rubric_id: placeholder.rubric.naturalness
    provider: mock
    dimension: placeholder.dimension.naturalness
    record_only: true
  - type: rubric_score
    rubric_id: placeholder.rubric.helpfulness
    provider: mock
    scale: placeholder.scale.unit-interval
    record_only: true
```

隔离规则：

- `record_only` 必须为 `true`。schema 不提供 `min_score`、`threshold` 或任何通过条件。写上多余字段会被拒绝。
- 评分服务商同样只能是 `mock`。
- 确定性校验失败则用例失败。评分缺失、评分高低、评审模型拒答，都不改变这个结果。
- 不要把 `llm_judge` 写进 `deterministic`，也不要把 `reward_key_once` 之类写进 `scored`。两列的类型闭集互斥。
- 评审提示词如果将来落地，放在别的任务里维护。本目录的评分项只记录“要评哪一个占位维度”。

## 校验器额外门禁

`evals/tools/validate_cases.py` 在 schema 之外再检查：

- `evals/cases/` 下用例 `id` 不重复。
- 源语言等于目标语言时，必须有对应的 `language_pair_isolation`，且 `expect_learning_profile` 为 `false`。
- 任意 `language_pair_isolation` 只要源语言等于目标语言，`expect_learning_profile` 就必须为 `false`。
- 第一条 `language_switches` 的 `from_pair` 等于用例起始 `language_pair`，且每个 `to_pair` 都有一条隔离断言。
- 标签与断言类型的对应关系见上文“必须用确定性断言的内容”。

`evals/tools/fixtures/invalid/` 里是故意写坏的文件，校验器不会把它们当作正式用例。
