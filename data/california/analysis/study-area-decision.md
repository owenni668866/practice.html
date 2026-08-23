# Study-area decision: California pilot

## Decision

Use **California alone** for the first tract-level PFAS and demographic analysis. Do not expand to Oregon and Washington yet.

## Evidence

The statewide GAMA PFAS file contains:

- 1,238,578 analyte-result records
- 12,951 unique wells
- 12,035 unique coordinate locations (coordinates rounded to five decimal places)
- 42 PFAS analytes
- 184,140 classified detections and 1,052,547 classified nondetects
- a 14.89% detection rate among classified results
- observations from 2016 through 2026
- complete usable coordinates for all records
- statewide geographic coverage from 32.5778 to 41.9656 latitude and -124.281628 to -114.208476 longitude
- records from DDW, GeoTracker, USGS, NWIS, and WRD

This provides ample sample size, chemical diversity, detection/nondetection variation, temporal depth, and statewide spatial coverage for a California pilot.

## Important limitations for the next phase

1. The analyte row is not the unit of spatial analysis. Repeated analytes, dates, and samples must be aggregated to a well and then tract-level measure.
2. Sampling is targeted and uneven, not a probability sample of California communities. A tract with no tested well cannot be treated as PFAS-free.
3. Nondetects are left-censored and reporting limits vary. The first analysis should report detection frequency separately from concentration and test more than one nondetect substitution rule.
4. Concentrations are strongly right-skewed: classified detections have a median of 6.8, a 95th percentile of 430, and a maximum of 5,180,000 in the source units. Use log-scaled summaries and inspect extreme values before modeling.
5. Data sources represent different monitoring programs and well categories. Source, year, analyte, and well category should be retained as design variables rather than pooled without adjustment.
6. Census tracts characterize nearby residents, not necessarily the population served by a sampled drinking-water well. Public-water-system service areas are a better exposure geography when available; tract joins should be described as proximity/context analysis.

## Recommended first tract-level outcomes

- any PFAS detection in the tract
- number of tested wells and number of sampling events
- proportion of classified results detected
- maximum detected PFOA, PFOS, and selected PFAS concentration
- median detected concentration, only where enough detections exist
- most recent sampling year

The immediate next step is to spatially assign unique wells to California Census tracts, aggregate without counting repeated analyte rows as independent sites, join ACS demographic estimates and margins of error, and map both PFAS outcomes and sampling intensity.
