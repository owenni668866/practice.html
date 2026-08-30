# State data

- `california/` contains California Census tracts, PFAS monitoring sources, converted GeoJSON, and analysis output.
- `oregon/` contains Oregon PFAS sites and statewide Census tracts. `washington-county-census-tracts.geojson` is Washington County, Oregon.
- `washington/` contains Washington State PFAS sites and statewide Census tracts.
- `west-coast-pfas-stations.geojson` combines and normalizes the three state PFAS site inventories for mapping.
- `west-coast-state-boundaries.geojson` contains the three official Census state boundaries.
- `analysis/` contains the station-to-tract crosswalk, 2024 ACS demographics, compound-specific tract averages, observation counts, map lookup data, and source bulk tables.
- `national/` contains national EPA layers, the state-by-state site inventory, and other United States data used by the research maps.
- `europe/` contains the European comparison dataset.
- `usgs/` contains USGS downloads, metadata, and data dictionaries.
- `analysis/comparability/` documents why the three state inventories can be compared for availability and coverage but not pooled concentration.

Interactive HTML maps remain in the repository root and load their datasets from these folders. `west-coast-pfas-census-map.html` is the common three-state view.
