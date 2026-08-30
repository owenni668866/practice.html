# West Coast PFAS dataset comparability review

## Decision

Do **not** pool the numeric concentration fields from the California, Oregon, and Washington site-inventory GeoJSON files for concentration correlations. The files share a convenient map schema, but they do not retain concentration units, laboratory methods, detection or reporting limits, result qualifiers, exact sample dates, or a consistent definition of `total_pfas` and `pfas_level`. They also mix environmental matrices, monitoring programs, facilities, suspected sources, and repeated records at the same named coordinate.

The three inventories can be compared for **data availability and mapped monitoring coverage** when counts are labeled as inventory records or unique named-coordinate sites. State-specific concentration analysis is appropriate only after returning to source records and harmonizing analyte, unit, matrix, sample type, method, reporting limit, qualifier, and time period. The California raw files support that work; equivalent Oregon and Washington raw result tables are not currently present in this repository.

This decision supersedes treating PFOA in `data/analysis/concentration/` as a fully comparable West Coast outcome. Those coefficients remain an exploratory diagnostic of the compiled inventory only and must not be interpreted as exposure or regulatory-monitoring estimates.

## What is in the three-state layer

The state GeoJSON files use nearly the same fields: site name, state, broad industry, matrix, year, PFOA, PFOS, total PFAS, a source-reported PFAS level, notes/links, coordinates, and an object identifier. The combined layer contains 589 records, but a record is not consistently a unique monitoring station:

| State | Inventory records | Unique named-coordinate sites | Year span | Matrices represented |
|---|---:|---:|---|---|
| California | 532 | 266 | 2014–2025 | Drinking water, groundwater, soil, surface water |
| Oregon | 16 | 16 | 2010–2023 | Drinking water, groundwater, surface water |
| Washington | 41 | 21 | 2016–2023 | Drinking water, groundwater, soil |

California and Washington contain repeated records at the same site coordinate, often representing different records or reported values. Counting all features as stations would therefore overstate site density.

## Directly comparable variables

The following can be compared across the three inventory files with the stated limitations:

- Geographic coordinates and state, for mapping coverage.
- Inventory-record availability for PFOA, PFOS, and `total_pfas`, as presence/absence of a populated field—not as comparable concentration.
- Unique site availability after deduplicating by site name and coordinates.
- Broad calendar year for temporal coverage; it is not an exact sample date and 15 records have no year.
- Broad matrix and industry labels for descriptive inventory summaries. Categories are not controlled consistently enough for precise rate comparisons.
- Census-tract placement, tract coverage, and ACS demographic context.

## Variables that cannot be pooled directly

| Topic | Comparability problem | Required harmonization |
|---|---|---|
| PFOA and PFOS numeric values | Field names match, but no unit field is retained and source programs/matrices differ. | Verify original units; convert to a common unit; restrict to a common matrix and sample type. |
| `total_pfas` | The compound list contributing to a total is not recorded and can differ by method, program, and year. | Recalculate from a documented common analyte panel and consistent nondetect rule. |
| `pfas_level` | A generic source-reported display value; it may reflect total PFAS or another reported quantity. | Do not use analytically; derive a named outcome from source result rows. |
| Nondetects | Zero, blank, a reporting limit, and true nondetection cannot be distinguished reliably in the inventory. | Retain result qualifier and reporting/detection limit; apply explicit censoring rules. |
| Detection/reporting limits | Neither is included. Limits vary by analyte, lab, method, and date. | Join or obtain row-level limits from original monitoring data. |
| Sampling standards and laboratory methods | No method, QA/QC, sample type, or monitoring-program identifier is retained. | Restrict or adjust by method/program and review QA flags. |
| Dates | Only a broad year is present. | Use exact collection dates and define a common time window. |
| Site counts | A feature is not consistently a unique site; California has 532 records at 266 named-coordinate sites and Washington 41 at 21. | Deduplicate to a documented site key; separately count samples and results. |
| Exposure interpretation | Sites include drinking water, groundwater, soil, surface water, facilities, and suspected sources. | Analyze matrices and site types separately; use service areas for drinking-water exposure when possible. |

## California raw-data advantage

California has additional source tables under `data/california/pfas/` that are not equivalent to the simplified site inventory:

- GAMA statewide PFAS: approximately 1.24 million analyte-result rows, 42 analytes, 2016–2026, normalized result/modifier, units, reporting limits, dates, coordinates, well identifiers/categories, source fields, and some analytical-method information. The dominant normalized unit is ng/L.
- State Water Project: 2,981 result rows, 43 analytes, 2020–2026, ng/L, explicit detection and reporting limits, `ND` reporting, exact sample dates, flags, labs, and EPA 537M/1633/1633A methods.
- DDW ordered monitoring: 2019–2020 drinking-water monitoring near targeted facility types, retained as the downloaded workbook and converted GeoJSON.
- UCMR3 summary: 2013–2015 PFOS/PFOA drinking-water summary; the downloaded summary lacks coordinates in the conversion used here.

These California programs themselves should not be pooled without accounting for well type, monitoring purpose, method, reporting limit, repeated sampling, and time. They nevertheless provide the fields needed for a defensible California-only harmonization. Oregon and Washington currently have only the simplified inventory in this project.

## Availability and monitoring density

Density comparisons use unique named-coordinate sites, not raw feature counts. Population denominators are summed 2020–2024 ACS tract estimates.

| State | Unique sites | Monitored tracts | All tracts | Tracts monitored | Unique sites per million people |
|---|---:|---:|---:|---:|---:|
| California | 266 | 237 | 9,129 | 2.60% | 6.77 |
| Oregon | 16 | 14 | 1,001 | 1.40% | 3.76 |
| Washington | 21 | 18 | 1,784 | 1.01% | 2.69 |

Coverage is sparse and strongly uneven in all states. California has both the highest absolute availability and the highest density by these measures. These figures describe what is represented in this repository, not the complete universe of testing performed by each state.

## Analysis rule going forward

1. Use California as the pilot for concentration analysis, starting from raw GAMA or another single documented program.
2. Define one matrix, analyte, unit, time window, and nondetect treatment before computing tract averages.
3. Treat monitoring availability as a separate outcome from measured concentration.
4. Report Oregon and Washington coverage descriptively until equivalent row-level monitoring results and metadata are acquired.
5. Keep the common map layer for visualization, but label numeric values as source-reported and non-harmonized.
