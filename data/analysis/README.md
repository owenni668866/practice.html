# West Coast PFAS–Census tract analysis

## Outputs

- `west-coast-pfas-stations-with-tract-demographics.csv`: one row per compiled PFAS location, including coordinates, tract and state identifiers, PFAS measures, population, racial/ethnic measures, and median household income.
- `west-coast-pfas-stations-with-tract-demographics.geojson`: map-ready version of the station-level join.
- `west-coast-tract-pfas-demographics.csv`: one row for every California, Oregon, and Washington Census tract, including zero-monitoring tracts.
- `west-coast-tract-compound-averages.csv`: long-format averages and observation counts by tract and PFAS measure.
- `acs-2024-tract-demographics.csv`: tract demographics before the PFAS aggregation.
- `west-coast-tract-map-data.json`: compact tract lookup used by the interactive West Coast map.
- `spatial-join-summary.json`: coverage and join diagnostics.
- `west-coast-pfas-stations-unmatched.csv`: unmatched audit file; it currently contains zero records.

## Demographic definitions

Demographics use the 2020–2024 ACS five-year estimates. Total population comes from B01003. Race and ethnicity come from B03002. Tract files include percentages for non-Hispanic White, Black, American Indian/Alaska Native, Asian, Native Hawaiian/Pacific Islander, other race, and multiracial residents, plus Hispanic/Latino residents of any race. These categories are mutually exclusive. “People of color” is total B03002 population minus non-Hispanic White-alone population. Median household income comes from B19013 and is expressed in 2024 inflation-adjusted dollars. Selected margins of error are retained in the tract files.

## Concentration analysis

The `concentration` subfolder contains monitored-tract-only PFOA correlations, state and monitoring-coverage sensitivity checks, a complete analytic extract, preliminary findings, and interactive scatter plots. Run `analyze_pfas_concentration.ps1` from the repository root to reproduce these files.

## PFAS aggregation

The source inventory contains 589 location records. All 589 were assigned to a 2024 Census tract; 269 tracts contain one or more locations. Tract averages are calculated independently for PFOA, PFOS, total PFAS, and the source-reported PFAS level. Each average has its own observation count and station count.

PFOA is the initial primary comparable measure because it has the strongest coverage among identified individual compounds: 467 observations, compared with 351 for PFOS. Total PFAS has 516 observations but may combine different analyte lists, so it is retained without treating it as chemically uniform. The source-reported PFAS level has 589 observations but may represent different compounds, matrices, units, and years.

## Interpretation limits

This is a spatial-context analysis, not an exposure estimate. A tract containing a monitoring point is not necessarily the point’s service area, and residents may obtain water elsewhere. Monitoring was targeted and uneven; zero observed stations does not imply zero PFAS. Tract averages are descriptive and do not make repeated observations statistically independent.

Sources: U.S. Census Bureau TIGERweb ACS 2024 boundaries and 2024 ACS five-year table-based summary files B01003, B03002, and B19013.
