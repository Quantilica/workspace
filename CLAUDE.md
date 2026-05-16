# Quantilica Ecosystem — Claude Code Context

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

Beyond the library/tool packages above, the workspace directory also holds **deployed web applications**. These are a distinct tier — different repos, different conventions — and must be treated separately.

| Application | Description |
|---|---|
| `quantilica-web` | Shared web infrastructure package: `create_flask_app()` factory, base config, security, cache, auth, error handlers — consumed by every `-db` app (also has a FastAPI extra, currently a stub) |
| `bcb-sgs-metadata-db` | Flask + Celery + PostgreSQL + Redis app — mirrors BCB SGS metadata and time-series; admin panel, LLM reports, Telegram alerts, S3 image storage |
| `datasus-metadata-db` | Flask + PostgreSQL app — tracks changes to DATASUS FTP file metadata over time |
| `ibge-sidra-metadata-db` | Flask + PostgreSQL app — explorer for IBGE/SIDRA survey metadata |
| `tddata-db` | Flask + PostgreSQL app — Tesouro Direto bond data explorer with portfolio-returns calculations |
| `quantilica.github.io` | Hugo static site — the organization's GitHub Pages |

### Packages vs. Applications — the two tiers

| | Packages (core, io, cli, cloud, fetchers, pipelines) | Applications (`-db` apps, `quantilica-web`) |
|---|---|---|
| Role | Reusable libraries / CLI tools | Deployed web services |
| uv workspace member | Yes — shared `.venv`, synced by `uv sync --all-packages` | No — own `uv.lock`, own dependency set |
| Visibility | Public (MIT) | Private |
| Stack | Pure Python, `hatchling` | Flask + PostgreSQL + Redis + Docker |
| Conventions | Strict shared: ruff `line-length 79`, Python 3.12 | Per-app — e.g. `bcb-sgs-metadata-db` uses ruff `line-length 120`; Python pin varies (3.10–3.14) |

The applications sit **downstream** of the packages: they load data/metadata into PostgreSQL and expose web UIs and JSON APIs. When working inside an application directory, follow **that repo's own** `CLAUDE.md` and `ruff` config — do not assume the workspace package conventions, and do not expect `uv sync --all-packages` to install it.

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

To add a new package to the workspace, add its directory name to the `members` list in the root `pyproject.toml` and re-run `uv sync --all-packages`.

Each package directory is an independent git repository with its own history and release cycle.

---

## Development Conventions

- **Python:** >= 3.12
- **Build backend:** `hatchling`
- **Package manager:** `uv` (never use `pip` directly)
- **Linting/formatting:** `ruff` — `line-length = 79`, rules: `E, F, I, UP, B`
- **Testing:** `pytest` (>= 8.0)
- **Imports:** alphabetical order within each group (stdlib → third-party → local), at the top of the file
- **Dependencies:** declare in `pyproject.toml` with minimum version pins; use `uv add` to add new ones

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

---

## Per-package CLAUDE.md

Individual packages may have their own `CLAUDE.md` with package-specific context. Those take precedence over this file for package-specific work.
