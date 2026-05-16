# Quantilica Ecosystem — Agent Instructions

This is the **development workspace** for the Quantilica ecosystem: a set of Python packages for collecting, normalizing, and analyzing Brazilian public data (economic, health, meteorological, fiscal, labor). This root directory is a uv workspace, not a publishable package.

---

## Packages and dependencies

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

Additional package: `sidra-pipelines` — declarative ETL pipelines (TOML + SQL), no Python package deps on the above.

`quantilica-cloud` is a `quantilica-cli` plugin (`quantilica.commands` entry-point group) that syncs download manifests to a cloud catalog.

---

## Application layer

The workspace directory also contains **deployed web applications** — a separate tier from the packages above:

| Application | Description |
|---|---|
| `quantilica-web` | Shared Flask/FastAPI infrastructure: `create_flask_app()` factory, config, security, cache, auth |
| `bcb-sgs-metadata-db` | Flask + Celery + PostgreSQL + Redis — BCB SGS metadata/series mirror |
| `datasus-metadata-db` | Flask + PostgreSQL — DATASUS FTP metadata change tracker |
| `ibge-sidra-metadata-db` | Flask + PostgreSQL — IBGE/SIDRA metadata explorer |
| `tddata-db` | Flask + PostgreSQL — Tesouro Direto data explorer |
| `quantilica.github.io` | Hugo static site (organization GitHub Pages) |

Applications differ from packages: they are **private repos**, **not uv workspace members** (own `uv.lock`, own deps, own Python pin), built on **Flask + PostgreSQL + Docker**, and may use different conventions (e.g. `bcb-sgs-metadata-db` uses ruff `line-length 120`). They are not installed by `uv sync --all-packages`. When working inside an application, follow that repo's own `CLAUDE.md`/`ruff` config — not the workspace package conventions.

---

## Workspace setup

```bash
uv sync --all-packages   # creates shared .venv with all packages as editable installs
uv run <command>         # run any command in the workspace environment
```

Do not modify `uv.lock` manually. Do not use `pip` directly — always use `uv`.

---

## Development rules

- Python >= 3.12, build backend: `hatchling`
- Linting and formatting: `ruff` (`line-length = 79`, rules `E, F, I, UP, B`)
- Tests: `pytest` >= 8.0
- Imports: alphabetical order (stdlib → third-party → local), all at the top of the file
- Declare dependencies in `pyproject.toml`; use `uv add` to add new ones

---

## Key architecture decisions

- **Plugin system:** fetchers register as `quantilica.fetchers` entry points; `quantilica-cli` discovers them dynamically — never add fetchers as direct deps of `quantilica-cli`
- **Manifests:** all fetchers produce `DownloadManifest` and `ExecutionManifest` (SHA-256, source URL, timestamps) via `quantilica-core`
- **Atomic writes:** always use `quantilica-core` storage utilities for file output
- **SIDRA transforms:** wide/pivot format — variables become columns, not rows

---

## Repository structure

Each subdirectory (`quantilica-core/`, `sidra-fetcher/`, etc.) is an independent git repository with its own release cycle. The root repo tracks only workspace-level files (`pyproject.toml`, `uv.lock`, this file).
