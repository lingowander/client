# 依赖许可扫描

这是临时白名单，待 W1-03 定稿后对齐。W1-03 定稿前，本检查不作为正式许可证政策。

持续集成里的 `license-scan` job 对 pub workspace 的全部已解析依赖做扫描，包括传递依赖、开发依赖、Flutter / Dart SDK 依赖，以及仓库内的 path 包。规则在 [`tool/license_policy.yaml`](../tool/license_policy.yaml)。允许列表目前是 MIT、BSD-2-Clause、BSD-3-Clause、Apache-2.0、ISC、Zlib，与 GPL-3.0 兼容的 copyleft（`GPL-3.0`、`LGPL-2.1`、`LGPL-3.0`、`AGPL-3.0`），以及 Flutter 引擎第三方声明里已经识别到的其它宽松许可（`MIT-0`、`MIT-Modern-Variant`、`MIT-open-group`、`BSL-1.0`、`ECL-2.0`、`ICU`、`FTL`、`SGI-B-2.0`、`NAIST-2003`、`NCSA`、`libpng-2.0`、`Unicode-DFS-2016`、`HPND`、`CC0-1.0`、`public-domain`）。`GPL-2.0`、专有许可和无法识别的文本会使 job 失败。用长横线隔开的第三方声明会逐段识别，不能只取第一段的结果。

## 例外

MPL-2.0 以及其它需要人工审查的许可不能直接放进允许列表。把它们写进规则文件的 `exceptions`，每条都要有包名、许可和引入理由。

MPL-2.0 当前没有条目。

当前例外：

| 包名 | 许可 | 引入理由 |
| --- | --- | --- |
| `sky_engine` | `LicenseRef-NVIDIA-2002` | Flutter 引擎第三方声明里的 glslang 含有 2002 年 NVIDIA 版权许可：允许使用、修改和再分发，必须保留声明，不授予专利或商标。它不是 MIT、BSD 或 Apache 的标准文本，所以不放进自动允许列表。 |

## 本地运行

在仓库根目录执行 `dart pub get` 之后：

```bash
cd tool/license_scan
dart pub get
dart test
dart run bin/check_licenses.dart --repo-root ../..
```

扫描只读本地的 pub 缓存、Flutter SDK 和仓库里的 `LICENSE`。不访问许可数据库，也不使用密钥或付费服务。

识别库是 [pana](https://pub.dev/packages/pana)（BSD-3-Clause）自带的 SPDX 全文匹配，置信度阈值 0.9。`pana` 把 GNU GPL 第 2 版文本标成 `GPL-2.0`，不能区分 “only” 和 “or later”。因为 GPL-2.0-only 不能并入 GPL-3.0-only 的程序，`GPL-2.0` 一律失败；确认某个包是 GPL-2.0-or-later 之后，再用例外写明依据。仓库自身的 `LICENSE` 是 GPL-3.0，会标成允许的 `GPL-3.0`。没有单独许可文件的 workspace 成员沿用这份根许可。

`tool/license_scan` 不在 pub workspace 里，避免把扫描器的依赖算进客户端。该目录有自己的 `pubspec.lock`。扫描这个工具本身时加上 `--allow-absent-exceptions`，因为产品依赖上的例外不会出现在工具的解析结果里。产品 workspace 的扫描不使用这个开关。

## English

Temporary allowlist only. It is not the formal license policy until W1-03 is finalized. The CI job scans every resolved workspace dependency, including transitive and dev dependencies. MPL-2.0 and other licenses that need review belong in `exceptions` with a package name, SPDX id, and reason. There is no MPL-2.0 entry. The one current exception is `sky_engine` / `LicenseRef-NVIDIA-2002`, explained above. Detection uses pana's bundled SPDX texts offline.
