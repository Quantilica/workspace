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
| `quantilica-cloud` | CLI plugin for syncing download manifests to a cloud catalog; registered under the `quantilica.commands` entry-point group |

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
| `bcb-sgs-fetcher` | BCB SGS API | Central Bank time-series |

### ETL

| Package | Description |
|---|---|
| `sidra-pipelines` | Declarative ETL catalog: `fetch.toml` + `transform.sql` files per pipeline, wide/pivot output pattern |

### Dependency graph

```
quantilica-core  (no internal deps)
├── quantilica-io
├── quantilica-cli
│   └── quantilica-cloud  (also depends on quantilica-core)
├── sidra-fetcher
│   └── sidra-sql
├── bcb-sgs-fetcher
├── comex-fetcher
├── datasus-fetcher
├── inmet-fetcher
├── pdet-fetcher
├── rtn-fetcher
└── tesouro-direto-fetcher
```

---

## Application Layer

The workspace directory also holds **deployed web applications** — a tier distinct from the packages above, with their own repos and conventions.

| Application | Description |
|---|---|
| `quantilica-web` | Shared web infrastructure package: `create_flask_app()` factory, base config, security, cache, auth — consumed by every `-db` app |
| `bcb-sgs-metadata-db` | Flask + Celery + PostgreSQL + Redis — mirrors BCB SGS metadata and time-series; admin panel, LLM reports |
| `datasus-metadata-db` | Flask + PostgreSQL — tracks changes to DATASUS FTP file metadata over time |
| `ibge-sidra-metadata-db` | Flask + PostgreSQL — explorer for IBGE/SIDRA survey metadata |
| `tddata-db` | Flask + PostgreSQL — Tesouro Direto bond data explorer, portfolio returns |
| `quantilica.github.io` | Hugo static site — the organization's GitHub Pages |

**Packages vs. Applications:** packages are reusable libraries/tools — uv workspace members, public (MIT), pure Python, strict shared conventions (ruff `line-length 79`, Python 3.12). Applications are deployed web services — **private repos**, **not uv workspace members** (own `uv.lock`, own deps, own Python pin), built on **Flask + PostgreSQL + Redis + Docker**, with per-app conventions (e.g. `bcb-sgs-metadata-db` uses ruff `line-length 120`). Applications sit downstream of the packages and are not installed by `uv sync --all-packages`. Inside an application, follow that repo's own `CLAUDE.md`/`ruff` config.

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
