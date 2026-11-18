<!-- SPDX-License-Identifier: GPL-3.0-only -->

# 评测与质量（W1-09）

这里是语遇客户端的评测集 v0。只使用 mock 服务商和占位数据，不接真实模型，不放密钥，也不收录真实用户内容。

属性测试包在 `packages/lingo_testkit`。W1-02 合入后，根目录已经是 pub workspace，贡献说明要求不要在子目录另留一份锁文件，所以这个包注册为 workspace 成员，而不是留在 `evals/property/`。

协议 schema（`turn_output`、`turn_analysis`、`weakness_plan` 与 OpenAPI v0）仍由 W1-04 起草。`packages/lingo_protocol` 目前只导出包名，没有这些类型。

## 目录

```text
evals/
  README.md                 本说明
  ASSERTIONS.md             确定性断言约定
  schema/eval_case.schema.json
  cases/                    正式用例（目前都是占位示例）
  tools/                    校验脚本、依赖锁定和故意写坏的夹具
packages/lingo_testkit/     属性测试骨架，workspace 成员
```

## 用例格式

一条用例是一个 YAML 对象，字段包括：

- `id`
- `language_pair`：`source` 与 `target`。二者相同表示纯游戏，不产生学习档案
- `scene`：世界状态与角色状态的占位
- `input`：`voice`（语音）、`typing`（打字）或 `word_pick`（选词）
- 可选的 `language_switches`：回合中途切换语言对
- `expectations.deterministic` 与可选的 `expectations.scored`
- `tags`
- `prd_features`：如 `F07`、`F09`。示例中的编号只示范格式，还没有和 PRD 核对

`schema_version` 为 `"0"` 时，`data_status` 只能是 `placeholder`。`runtime.provider` 只能是 `mock`。

三条示例：

- `cases/placeholder_reward_once.yaml`：打字，奖励只结算一次
- `cases/placeholder_language_switch.yaml`：语音，回合中从 zh→en 切到 zh→ja
- `cases/placeholder_pure_game.yaml`：选词，源语言等于目标语言

它们都依赖 lingo_protocol 草案。`turn_id`、`utterances` 等字段名是占位，等 W1-04 定稿后再改。断言怎么写见 [ASSERTIONS.md](ASSERTIONS.md)。

## 校验

```bash
python3 -m pip install -r evals/tools/requirements.txt
python3 evals/tools/validate_cases.py
python3 evals/tools/test_validate_cases.py
```

校验脚本确认 `evals/cases/` 下每个用例都符合 schema，并做少量跨字段检查。它不执行模型，也不读取 `evals/tools/fixtures/invalid/`。

属性测试随 workspace 一起解析。在仓库根目录：

```bash
dart pub get
dart analyze --fatal-infos packages/lingo_testkit
dart test packages/lingo_testkit
```

`lingo_core` 与 `lingo_protocol` 还没有奖励账本、画像或协议类型。`lingo_testkit` 依赖这两个包，只为了接上 workspace；工厂仍返回参考实现。说明见 [`packages/lingo_testkit/README.md`](../packages/lingo_testkit/README.md)。
