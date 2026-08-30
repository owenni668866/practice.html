# PFAS mapping and Census tract analysis

The main three-state project is `west-coast-pfas-census-map.html`. Website files and reproducible PowerShell scripts remain in the repository root; all downloaded, derived, and supporting data files are organized under `data/`.

Key documentation:

- `data/README.md` — data directory structure
- `data/analysis/README.md` — spatial join and demographic outputs
- `data/analysis/comparability/west-coast-pfas-comparability-review.md` — California/Oregon/Washington comparability decision
- `data/analysis/concentration/preliminary-findings.md` — exploratory monitored-tract correlations and limitations

Serve the repository through a local web server rather than opening map files directly so browser `fetch()` calls can load GeoJSON and JSON dependencies.
