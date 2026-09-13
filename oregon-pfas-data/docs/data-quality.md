# 数据字典与质量说明

## 粒度与来源

主表每行是一个 program × PWSID × facility × sample point × collection date × SampleID × analyte × method 的分析记录；该候选键在当前快照无重复。保留所有原始结果，不自动去重。SampleID 可能随方法/实验室不同而变化，不能将不同 SampleID 数直接称为采样瓶数或现场采样次数。另报 point-date 组合，但同日也可能多次采样，不宣称是独立样本数。

两个 EPA ZIP 的所有 `All_*.txt` 分区均筛选 `State=OR`，不只按 OR 开头 PWSID 筛选。未按实际地理位置重新分配其他州/部落记录，州字段之外的地理覆盖仍待核对。原始层保留所有分析物；处理层只保留 PFAS。下载 ZIP 的 URL 路径年份不是快照年份，应查 manifest 哈希与随附说明。

## 主表字段

| 字段 | 含义/规则 |
|---|---|
| program | UCMR3 或 UCMR5；不可无条件合并浓度比较 |
| pws_id / pws_name | 官方公共供水系统 ID / 名称；ID 按字符串保留 |
| size_class | EPA 原始规模编码；未推断精确服务人数 |
| facility_id / facility_name | 系统内设施；ID 不保证跨轮次稳定 |
| water_type | 原始水源类型编码；不等于另行采集的原水样 |
| sample_point_id / sample_point_type | 系统内点位；当前 PFAS 全部为 EP（入网点） |
| collection_date | ISO 日期；UCMR5 有 108 条 2026 年记录，保留并标注 |
| sample_id / sample_event_code | 原始实验室样品标识 / 轮次事件编码 |
| analyte / method | 分析物简称 / 原始 EPA 方法标签 |
| result_status | detected：达到报告限；below_mrl：低于报告限，不等于 0 |
| result_sign | 原始 `<` 或 `=` |
| result_ng_l | 检出值；未检出为空；绝不以 MRL、MRL/2 或 0 替代 |
| mrl_ng_l | 最小报告限，ng/L；不是健康或合规阈值 |
| original_result / original_units / original_mrl | 原始数值与单位；µg/L × 1000 = ng/L |
| source_file / source_csv_line | 原始 UTF-8 CSV 文件及行号（含标题行） |

## 已执行检查

执行 `python3 scripts/check.py`，另见机器可读 `data/processed/audit.json`。

- 原始 CSV 的 SHA-256 与 manifest 一致；处理行可逐行追溯原始 CSV。
- PFAS 原始行与输出行一一对应，不丢失、不重复、不混入 lithium 等非 PFAS。
- 数值转换、未检出保留为空、检出值不低于 MRL、日期与必填标识有效。
- 候选分析记录键无重复；系统和分析物汇总与主表一致。
- Owen 的 92 条 UCMR5 检出记录按系统、设施、点位、日期、样品、分析物及浓度全部匹配；仅存作 reference，未二次加入。

## 发现与风险

| 问题 | 证据与影响 | 处理 |
|---|---|---|
| 高：只有检出子集会丢分母 | 原子集 92 条；官方 UCMR5 PFAS 共 21,261 条 | 已补 21,169 条低于 MRL 记录；任何检测比例都注明分母 |
| 高：跨轮次报告限不一致 | 新轮次 7 条 PFOA / 26 条 PFOS 检出均低于旧轮次 MRL | 提供共同阈值敏感性表，不宣称污染增减 |
| 高：全州覆盖仍不完整 | 无 OHA 逐条结果及全州有效系统名录；私人井另属范围 | 不计算全州监测覆盖率；OHA 入口列待补 |
| 高：质心不是采样位置 | Owen 对照层含服务区/ZIP 质心 | 地图仅显示系统代表位置，不做人群暴露或 tract 浓度关联 |
| 中：轮次名义时间不等于实际日期 | UCMR5 108 条记录晚于 2025-12-31 | 保留；尚未确认是补采、重采还是其他情况；趋势分析应单列敏感性 |
| 中：不同方法的样品 ID 不一定代表独立现场采样 | UCMR5 的 SampleID 组合数多于单分析物结果数 | 报分析记录数；同点同日与 SampleID 组合分开，不等同瓶数 |
| 中：州名单是计划名单 | 下载 PDF 标注 as of 10/8/2021 | 不将计划系统自动标记为已检测 |

确定性高的是当前下载中可复核的数量、字段与阈值差异；未核实的采样原因、全州缺口和制度效果不得作为结论。

## 待补清单

1. OHA `https://yourwater.oregon.gov/pfascounty.php` / `pfas.php`：2026-09-06 多次 HTTPS 连接超时，未取得逐条结果；不是确认“没有结果”。保留官方网站链接，后续成功下载后单独记录 program、source、报告限与样品标识，并先查与 UCMR5 重复。
2. OHA 全州有效供水系统名录与规模、供水人口、类型、服务区边界：建立适用分母。现有 2021 年 PDF 不能替代。
3. 州级专项与小系统项目的分析物组合、质量控制和实际完成记录。
4. 若扩展至地表水/地下水/土壤/私人井，分介质建表，不能把潜在污染源清单当测量结果。

这些缺项意味着本版是可复现的 **Oregon EPA UCMR PFAS 数据底座**，不是俄勒冈所有 PFAS 资料的完整汇编。

## 地图层补充（2026-09-06）

新增 EPA PFAS Analytic Tools 的 UCMR5 位置查询快照（`data/location-source.json`）。127 个 UCMR5 系统均按 PWSID 匹配，其中 124 个坐标有效，3 个无坐标，后者仍保留在搜索列表中。与每个系统的分析物汇总连接，坐标未用于浓度计算或人口普查区赋值。底图为灰度矢量，检测状态采用独立的橙色/青灰色符号。
