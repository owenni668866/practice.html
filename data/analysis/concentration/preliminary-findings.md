# Preliminary tract-level PFAS concentration analysis

## Analytic sample

The concentration analysis includes only Census tracts with at least one PFOA measurement and a nonmissing tract-level average. Unmonitored tracts are excluded and are never assigned a concentration of zero. PFOA is used because it has the strongest comparable compound coverage in the compiled station data.

The analytic sample contains 217 monitored tracts: 196 in California, 7 in Oregon, and 14 in Washington. California therefore accounts for 90% of the sample. There are 428 PFOA observations in California, 8 in Oregon, and 31 in Washington.

## Preliminary correlations

Coefficients below compare tract characteristics with tract-average PFOA. `r raw` is Pearson correlation with the untransformed average, `r log` is Pearson correlation with log10(PFOA + 1), and `rho` is Spearman rank correlation.

| Geography | Measure | Complete tracts | r raw | r log | rho |
|---|---|---:|---:|---:|---:|
| Pooled West Coast | Population | 217 | -0.076 | -0.076 | -0.047 |
| Pooled West Coast | People of color | 208 | -0.032 | 0.000 | -0.014 |
| Pooled West Coast | Asian, non-Hispanic | 208 | -0.044 | -0.036 | 0.086 |
| Pooled West Coast | Median household income | 203 | -0.049 | 0.064 | 0.084 |
| California | Population | 196 | -0.074 | -0.063 | -0.016 |
| California | People of color | 188 | -0.040 | -0.023 | -0.049 |
| California | Asian, non-Hispanic | 188 | -0.045 | -0.023 | 0.088 |
| California | Median household income | 183 | -0.045 | 0.113 | 0.132 |
| Oregon | Population | 7 | -0.449 | 0.013 | -0.296 |
| Oregon | People of color | 7 | 0.098 | 0.335 | 0.371 |
| Oregon | Asian, non-Hispanic | 7 | -0.218 | 0.056 | -0.115 |
| Oregon | Median household income | 7 | -0.166 | 0.024 | 0.111 |
| Washington | Population | 14 | -0.298 | -0.436 | -0.496 |
| Washington | People of color | 13 | 0.453 | 0.396 | 0.458 |
| Washington | Asian, non-Hispanic | 13 | -0.061 | -0.193 | 0.058 |
| Washington | Median household income | 13 | -0.500 | -0.391 | -0.472 |

The complete CSV reports these coefficients for every mutually exclusive race/ethnicity percentage, not only the four measures highlighted above.

## Interpretation and sensitivity

The pooled and California coefficients are small and do not show a strong preliminary linear or monotonic association. The within-state-demeaned Pearson coefficients are also small: population -0.076, people of color -0.034, Asian -0.045, and income -0.049. This indicates that the pooled raw correlations are not being substantially produced by differences in state means.

Washington has moderate preliminary coefficients for population, people of color, and income, but only 13–14 complete tracts. Oregon has only seven tracts. These state samples are too small and uneven to treat their coefficients as stable or directly comparable. Results should therefore be presented separately by state, with California as the only current sample suitable for the main next-stage analysis.

Monitoring intensity is not strongly correlated with tract-average PFOA in this sample: `r = -0.024` for station count and `r = -0.021` for PFOA observation count. However, this does not eliminate selection bias because monitoring locations were not selected randomly. The PFOA distribution is extremely right-skewed, and source units/matrices have not been fully harmonized. Log and rank correlations are more defensible than raw Pearson coefficients at this stage.

## Recommended next question

Focus the next analysis on California and ask whether tract demographics are associated with the probability of being monitored and, separately, with log-transformed PFOA among monitored tracts. Before modeling concentration, harmonize units and sample matrices and investigate the highest-concentration outliers.
