# ASSETS（素材清单）

> 模板草稿（W1-03），须律师/法务确认。放在 `assets/ASSETS.md`。每个入库素材一行；`sha256` 用 `sha256sum` 生成；
> 由 `tools/licenses/check_assets_manifest.py` 在 CI 中检查「磁盘文件 ⇄ 清单」一致。
> 许可信息的机器可读来源是 `REUSE.toml` / `<文件>.license`，本清单是人读的登记表，两者必须一致。
> 素材许可与代码的 GPL-3.0-only 分开声明（见 docs/compliance/asset-licensing.md）。

## 填写规则

- `provenance`（来源类别）：`A` 脚本生成 · `B` 成员原创 · `C` AI 生成/AI 辅助 · `D` 第三方素材。（Flutter 绘制的图形是 Dart 源码，放 `app/lib`，按 GPL-3.0-only，不在本清单。）
- `licence`：SPDX 标识符，只能是 `CC0-1.0`、`CC-BY-4.0`、`CC-BY-SA-4.0`、`GPL-3.0-only`、`GPL-3.0-or-later` 之一（增加需走许可政策评审）。
- `statement_id`：对应《作者授权声明》编号（见 `docs/compliance/author-authorization-statement.md`），脚本生成类填负责人签署的声明编号。
- `C` 类必填：工具名与版本、模型名/版本与生成日期、提示词与迭代记录的存放位置（保留原始记录，不要事后复现）、做选择与修改的人。
- `D` 类必填：`upstream_source`（原始链接 + 原许可）；许可不兼容或不明者不得入库（见许可政策的禁止/需审查表）。
- `status`：`placeholder`（M0 占位，终将替换）或 `final`。

## 清单

| path | sha256 | kind | provenance | author_or_tool | model_version_date | prompt_record | licence | copyright_notice | statement_id | upstream_source | status | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| <placeholder/generated/bg_room_01.png> | <64 hex> | image | A | tools/assets/gen_placeholders.py@<commit> | | | CC0-1.0 | 2026 <COPYRIGHT HOLDER> | <AUTH-0001> | | placeholder | 脚本输出，随机种子 <n> |
| <placeholder/original/portrait_A.png> | <64 hex> | image | B | <作者姓名> | | | CC-BY-SA-4.0 | 2026 <作者姓名> | <AUTH-0002> | | placeholder | 作者自行授权，见声明 |
| <placeholder/ai-assisted/bg_street_01.png> | <64 hex> | image | C | <工具名 版本> | <模型 版本 / 2026-11-xx> | <records/2026-11-xx-bg_street_01.json 的位置> | CC0-1.0 | 2026 <指导生成并筛选修改的人> | <AUTH-0003> | | placeholder | 人的选择与修改说明：<…> |
