# Quantilica Ecosystem — Gemini CLI Context

This is the **development workspace** for the Quantilica ecosystem: a collection of Python packages for collecting, normalizing, and analyzing Brazilian public data. This root directory is not a publishable package — it is a uv workspace that coordinates local development across all packages.

---

## Package Ecosystem

### Infrastructure

| Package | Description |
|---|---|
| `quantilica-core` | Foundation layer: HTTP client (httpx), structured logging, atomic storage, SHA-256 download manifests, execution manifests for data provenance |
| `quantilica-io` | Analytical data layer: Polars DataFrames, PyArrow, Parquet I/O, schema validation |
| `quantilica-cli` | Unified CLI with plugin architecture — discovers fetchers via `quantilica.fetchers` entry points, no hard dependencies on fetcher packages |

### Data Fetchers

| Package | Data Source | Domain |
|---|---|---|
| `sidra-fetcher` | IBGE SIDRA & Agregados API | Economic statistics, price indices, demographics |
| `sidra-sql` | (depends on sidra-fetcher) | Loads SIDRA data into PostgreSQL |
| `comex-fetcher` | MDIC/Comex Stat | Foreign trade (imports/exports) |
| `datasus-fetcher` | DATASUS FTP | Health microdata |
| `inmet-fetcher` | INMET BDMEP | Meteorological station data |
| `pdet-fetcher` | MTE/PDET | Labor microdata (CAGED, RAIS) |
| `rtn-fetcher` | Tesouro Nacional (STN) | Fiscal data (RTN) |
| `tesouro-direto-fetcher` | Tesouro Direto (STN) | Government bonds data |

### ETL

| Package | Description |
|---|---|
| `sidra-pipelines` | Declarative ETL catalog: `fetch.toml` + `transform.sql` files per pipeline, wide/pivot output pattern |

### Dependency graph

```
quantilica-core  (no internal deps)
├── quantilica-io
├── quantilica-cli
├── sidra-fetcher
│   └── sidra-sql
├── comex-fetcher
├── datasus-fetcher
├── inmet-fetcher
├── pdet-fetcher
├── rtn-fetcher
└── tesouro-direto-fetcher
```

---

## uv Workspace

This workspace uses a single shared `.venv`. All packages are installed as editable installs, so changes to any package are immediately reflected in all others.

```bash
# Sync all packages (run from workspace root)
uv sync --all-packages

# Run a script in the workspace environment
uv run python -c "from quantilica_core import HttpClient"

# Run tests for a specific package
uv run --package sidra-fetcher pytest sidra-fetcher/tests/
```

Do not modify `uv.lock` manually. Always use `uv add` to add new dependencies.

---

## Development Conventions

- **Python:** >= 3.12
- **Build backend:** `hatchling`
- **Package manager:** `uv` (never use `pip` directly)
- **Linting/formatting:** `ruff` — `line-length = 79`, rules: `E, F, I, UP, B`
- **Testing:** `pytest` (>= 8.0)
- **Imports:** alphabetical order within each group (stdlib → third-party → local), at the top of the file

---

## Architecture Patterns

### Plugin system (fetchers)
Each fetcher registers a Typer sub-app via entry points:
```toml
[project.entry-points."quantilica.fetchers"]
comex = "comex_fetcher.plugin:app"
```
`quantilica-cli` discovers and mounts all installed fetchers automatically. Never add fetcher packages as direct dependencies of `quantilica-cli`.

### Manifest system
`quantilica-core` provides `DownloadManifest` and `ExecutionManifest` for data provenance tracking (SHA-256 checksums, source URLs, timestamps). All fetchers must produce manifests alongside downloaded data.

### Storage layer
Use `quantilica-core`'s storage utilities for atomic file writes. Downloaded files must be written atomically to avoid partial/corrupt state.

### SIDRA transform pattern
`sidra-pipelines` uses a wide/pivot output: SIDRA variables become columns, not rows. Transforms are defined in `transform.toml` + `.sql` files.
