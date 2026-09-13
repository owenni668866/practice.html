# PFAS · Oregon monitoring evidence

俄勒冈 PFAS 监测研究，2026-09-06 建立。独立于 Owen 原仓库的新项目。

**先研究“监测设计如何影响我们看见的污染”，再讨论监测制度怎样改进。**
现有标准和方法已经存在；覆盖范围、分析物组合、报告限、监测时间与数据公开方式的差异，需要用数据检验。

## 已完成的数据底座

| 数据 | PFAS 分析记录 | 供水系统 | 分析物 | 检出记录 |
|---|---:|---:|---:|---:|
| EPA UCMR3 | 2,526 | 65 | 6 | 0 |
| EPA UCMR5 | 21,261 | 127 | 29 | 92 |

跨轮次共有 133 个不同 PWSID。这里“一条记录”是一个分析物的分析结果，不是一瓶水、一个站点或一个人。数据是公共饮用水系统入网点（EP）结果，不涵盖俄勒冈全部环境介质或私人井。

- Owen 原来的 Oregon UCMR5 **92 条检出记录全部与官方完整下载匹配**；保留来源对照，不重复叠加。
- 补入 UCMR5 **21,169 条低于报告限的记录**，并加入 UCMR3 历史基线。未检出数值保留为空，报告限另列，绝不填 0。
- 官方 UCMR5 快照的实际采样日期为 2023-01-09 至 **2026-06-08**；其中 108 条记录在 2026 年，虽超出名义 2023–2025 轮次，但按原始文件保留，原因尚未核实。
- **尚未齐全**：OHA 2021–2023 专项及后续小系统项目的逐条结果，州网站连接超时；已保留 OHA 页面及 2021 年计划名单，不能以名单推定检测完成。尚未接入私人井、地表水、土壤或全州系统名录分母。

## 打开成果

在线访问 [Oregon PFAS 网站](https://jakobzhao.github.io/pfas/)：全屏 MapLibre 地图，CARTO Positron 灰度矢量底图，支持分析物、检出状态、系统名称筛选及点位详情。124 个系统有官方代表位置，3 个无坐标系统仍在列表中。GitHub Pages 从 main 分支根目录发布，推送更新后自动重新部署。仓库保持私有，Pages 网站公开可访问。地图需要联网获取矢量瓦片。原有统计报告保留在 [report.html](report.html)，可离线打开。

- [结果主表](data/processed/oregon-pfas-results.csv)：23,787 条 PFAS 记录，单位统一 ng/L。
- [系统汇总](data/processed/system-summary.csv)：每轮次 × PWSID。
- [分析物、方法与报告限](data/processed/analyte-method-limits.csv)。
- [按旧报告限重判新数据](data/processed/common-analyte-threshold-comparison.csv)。
- [研究策略](docs/research-strategy.md)、[数据字典与质量说明](docs/data-quality.md)。
- [数据审计 notebook](notebooks/audit.ipynb)：可重新执行审计和匹配。

## 复现与更新

Python 3.10+，分析仅用标准库；联网下载另需 curl。

```bash
python3 scripts/build.py                 # 离线：从已提交的原始 OR 快照重建
python3 scripts/reconcile_owen.py         # 与保留的 Owen 检出子集逐条核对
python3 scripts/report.py                # 重建 report.html 离线报告
python3 scripts/build_map.py             # 重建地图汇总与灰度矢量样式
python3 scripts/check.py                 # 验证行数、主键、单位、未检出和来源行
```

主动更新到 EPA 网站当前文件（会替换快照，请审查 git diff）：

```bash
python3 scripts/build.py --download
python3 scripts/reconcile_owen.py
python3 scripts/report.py
python3 scripts/build_map.py
python3 scripts/check.py
```

`data/raw/epa` 是两个全国 ZIP 分区中 `State.strip() == 'OR'` 的全部分析物原样字段抽取，CSV 采用 UTF-8。PFAS 筛选和单位转换仅发生在 processed 层；UCMR5 排除 lithium，UCMR3 保留六种 PFAS。原始 ZIP 在被忽略的 `.cache/`；来源 URL、ZIP SHA-256、抽取时间、成员文件和 CSV SHA-256 保存在 [source_manifest.json](data/source_manifest.json)。首次缓存下载后才记录抽取时间，因此该字段不是服务器发布日期。资料 PDF 保存在 `data/reference`。

## GitHub 同步

本目录是独立 Git 仓库，remote 为 `jakobzhao/pfas`，私有。首次版本已上传。后续同步为普通 Git 操作，不是后台自动上传：

```bash
git pull --ff-only
# 修改后先查看变更，再提交需要同步的文件
git status
git add README.md docs data scripts notebooks index.html
git commit -m "Update Oregon PFAS evidence"
git push
```

在另一台机器：`gh repo clone jakobzhao/pfas`。不要在多台机器同时改同一份 Google Drive 同步目录中的 `.git`；推荐每台机器独立 clone 后通过 Git 同步。

## 来源与解释边界

主数据来自 [EPA UCMR 官方下载](https://www.epa.gov/dwucmr/occurrence-data-unregulated-contaminant-monitoring-rule)。Owen 对照来源：[practice.html](https://github.com/owenni668866/practice.html)，固定 commit `6a47de9f4acea3ff049d85cd573ac931913cf7cb`。其坐标多为服务区或 ZIP 质心，不是真实采样坐标，本项目不据此将检测结果归给一个人口普查区的居民。

当前结果可用于监测设计与可比性分析，不能直接估计全州患病风险、居民暴露或法规合规情况。MRL 是报告限，不是健康标准。跨轮次检测率不可直接作污染趋势解释。

## 地图位置与底图

地图仅展示 UCMR5，按 PWSID 连接 EPA PFAS Analytic Tools 的位置字段；[查询来源与哈希](data/location-source.json)。全量匹配 127 个系统，124 个有坐标、3 个缺失。点是服务区/ZIP/县域质心，不是采样点；不以颜色推断居民暴露或法规违规。旧的检出子集坐标不再限制地图覆盖。

MapLibre GL JS 5.6.2 文件及许可保存在 `assets/vendor/`；[CARTO Positron](https://github.com/CartoDB/basemap-styles) 原样式在 `data/reference/carto-positron-style.json`，由 `scripts/build_map.py` 转换所有 paint 颜色为灰度。底图 source 类型为 vector，瓦片为 MVT；保留 CARTO / OpenStreetMap 署名。

本地预览：`python3 -m http.server 8768 --bind 127.0.0.1`，浏览器访问 `http://127.0.0.1:8768/`。重建地图数据后再推送，GitHub Pages 会自动发布。

## 预算约束下的监测选点规划

[打开选点规划页面](https://jakobzhao.github.io/pfas/planner.html)。设置总预算、单样分析费、轮次、每轮空白/平行样和其他费用；调整历史检出、证据缺口和供水类型权重，比较同预算的历史检出优先与固定种子随机方案，导出包含全部参数的 CSV。费用默认值仅为假设，不是报价；清单是系统级候选，不是已获准入的现场采样点。

`python3 scripts/build_planner.py` 从 UCMR5 原始结果生成规划属性；`node tests/planner.test.mjs` 验证预算与选择逻辑。核心评分公式在 `assets/planner-core.mjs` 和页面方法说明中。真正未监测系统分母与潜在污染源尚未齐全，因此不预测污染风险或宣称最优选点；自建候选是待核实的用户记录，只存于当前浏览器。
