# Quantilica Ecosystem — Claude Code Context

This is the **development workspace** for the Quantilica ecosystem: a collection of Python packages for collecting, normalizing, and analyzing Brazilian public data. This root directory is not a publishable package — it is a uv workspace that coordinates local development across all packages.

---

## Package Ecosystem

### Infrastructure

| Package | Description |
|---|---|
| `quantilica-core` | Foundation layer: HTTP client (httpx), structured logging, atomic storage, SHA-256 download manifests, execution manifests for data provenance |
| `quantilica-analytics` | Analytical data layer: Polars DataFrames, PyArrow, Parquet I/O, schema validation |
| `quantilica-cli` | Unified CLI with plugin architecture — discovers fetchers via `quantilica.fetchers` entry points, no hard dependencies on fetcher packages |
| `quantilica-catalog` | Unified data catalog and canonical observation model |

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
| `bcb-sgs-sql` | (depends on bcb-sgs-fetcher) | Loads BCB SGS data into PostgreSQL |

### ETL

| Package | Description |
|---|---|
| `sidra-pipelines` | Declarative ETL catalog: `fetch.toml` + `transform.sql` files per pipeline, wide/pivot output pattern |

### Dependency graph

```
quantilica-core  (no internal deps)
├── quantilica-analytics
│   └── quantilica-catalog  (also depends on quantilica-analytics)
├── quantilica-cli
├── sidra-fetcher
│   └── sidra-sql
├── bcb-sgs-fetcher
│   └── bcb-sgs-sql
├── comex-fetcher
├── datasus-fetcher
├── inmet-fetcher
├── pdet-fetcher
├── rtn-fetcher
└── tesouro-direto-fetcher
```

---

## Application Layer

This workspace directory also contains **private web applications** in their own subdirectories. These are not members of the uv workspace — each has its own `uv.lock`, dependency set, and per-app conventions.

When working inside an application subdirectory, follow **that repo's own** `CLAUDE.md` and `ruff` config — do not apply workspace package conventions, and do not expect `uv sync --all-packages` to install it.

---

## uv Workspace

This workspace uses a single shared `.venv`. All packages are installed as editable installs, so changes to any package are immediately reflected in all others.

```bash
# Sync all packages (run from workspace root)
uv sync --all-packages

# Run a script in the workspace environment
uv run python -c "from quantilica.core.http import HttpClient"

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
- **Linting/formatting:** `ruff` — `line-length = 88`, rules: `E, F, I, UP, B`
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

---

## `.gitignore` convention for applications

The public docs site (`docs/normas/gitignore.md`) covers only the **library/fetcher** template. Applications (`-db` apps, `sidra-pipelines`, `docs`) are private and follow an extended template that **versions `uv.lock`** (deploy reproducibility) and adds web-runtime patterns.

Template for application repos:

```gitignore
# Build / packaging
__pycache__/
*.py[cod]
*.egg-info/
build/
dist/

# Virtual envs e caches do uv
.venv/
.uv-cache/
# uv.lock é versionado em apps (deploy reproduzível)

# Caches de teste / lint / tipos
.pytest_cache/
.ruff_cache/
.mypy_cache/

# Cobertura
.coverage
.coverage.*
htmlcov/

# Runtime web
instance/
db.sqlite3
db.sqlite3-journal
/static
/media

# Build de docs (mkdocs / sphinx)
site/
docs/_build/

# Editor / IDE / OS
.vscode/
.idea/
.DS_Store
Thumbs.db
*.swp

# Logs e env locais
*.log
.env
.env.local

# Claude
.claude/
```

Key differences from the library template:

- `uv.lock` is **not** ignored — applications commit it for reproducible deploys.
- Adds web-runtime block: `instance/`, `db.sqlite3*`, `/static`, `/media`.
- Adds docs-build block: `site/`, `docs/_build/`.

Drop `/static`, `/media`, or the runtime block in apps that don't serve assets (JSON-only APIs, ETL catalogs, doc sites). Repo-specific entries (`data/`, `*.ini`, `.pgpass`, etc.) go below the template under a `# Específico do repo` header.
