# Quantilica — Workspace de Desenvolvimento

Este repositório é o **workspace de desenvolvimento** do ecossistema Quantilica. Não é um pacote instalável — ele coordena o desenvolvimento local de todos os pacotes do ecossistema usando [`uv` workspaces](https://docs.astral.sh/uv/concepts/workspaces/).

---

## Setup local

**Pré-requisitos:** Python >= 3.12, [`uv`](https://docs.astral.sh/uv/getting-started/installation/)

Clone todos os sub-repositórios e sincronize o workspace de uma vez:

```bash
./bootstrap.sh    # Linux/macOS
./bootstrap.ps1   # Windows (PowerShell)
```

Isso clona cada sub-repositório dentro deste diretório e cria um único `.venv` compartilhado com todos os pacotes instalados como editable installs. Mudanças em qualquer pacote são imediatamente visíveis nos demais.

---

## Pacotes

### Infraestrutura

| Pacote | Descrição |
|---|---|
| [`quantilica-core`](https://github.com/Quantilica/quantilica-core) | Utilitários base: HTTP, storage, logging, manifestos de proveniência |
| [`quantilica-analytics`](https://github.com/Quantilica/quantilica-analytics) | Processamento analítico: Polars, Parquet, schemas |
| [`quantilica-cli`](https://github.com/Quantilica/quantilica-cli) | CLI unificada com arquitetura de plugins via entry points |
| [`quantilica-cloud`](https://github.com/Quantilica/quantilica-cloud) | Plugin de CLI para sincronizar manifestos com um catálogo na nuvem |
| [`quantilica-catalog`](https://github.com/Quantilica/quantilica-catalog) | Catálogo de dados e modelo canônico de observações |

### Coletores de dados

| Pacote | Fonte | Descrição |
|---|---|---|
| [`sidra-fetcher`](https://github.com/Quantilica/sidra-fetcher) | IBGE/SIDRA | Cliente da API de Agregados e SIDRA |
| [`sidra-sql`](https://github.com/Quantilica/sidra-sql) | IBGE/SIDRA | Carregamento de tabelas SIDRA em PostgreSQL |
| [`comex-fetcher`](https://github.com/Quantilica/comex-fetcher) | MDIC | Dados de comércio exterior (importação/exportação) |
| [`datasus-fetcher`](https://github.com/Quantilica/datasus-fetcher) | DATASUS | Microdados de saúde (FTP) |
| [`inmet-fetcher`](https://github.com/Quantilica/inmet-fetcher) | INMET | Dados meteorológicos (BDMEP) |
| [`pdet-fetcher`](https://github.com/Quantilica/pdet-fetcher) | MTE/PDET | Microdados de trabalho (CAGED, RAIS) |
| [`rtn-fetcher`](https://github.com/Quantilica/rtn-fetcher) | STN | Dados fiscais (RTN) |
| [`tesouro-direto-fetcher`](https://github.com/Quantilica/tesouro-direto-fetcher) | STN | Dados do Tesouro Direto |
| [`bcb-sgs-fetcher`](https://github.com/Quantilica/bcb-sgs-fetcher) | BCB/SGS | Séries temporais do Banco Central |
| [`bcb-sgs-sql`](https://github.com/Quantilica/bcb-sgs-sql) | BCB/SGS | Carregamento de séries do BCB SGS em PostgreSQL |

### Pipelines ETL

| Pacote | Descrição |
|---|---|
| [`sidra-pipelines`](https://github.com/Quantilica/sidra-pipelines) | Catálogo declarativo de pipelines SIDRA (fetch.toml + transform.sql) |
| [`bcb-sgs-pipelines`](https://github.com/Quantilica/bcb-sgs-pipelines) | Catálogo declarativo de pipelines BCB SGS (fetch.toml + transform.sql) |

### Outros Repositórios

| Repositório | Descrição |
|---|---|
| [`docs`](https://github.com/Quantilica/docs) | Portal de documentação pública (`docs.quantilica.com`), gerado com MkDocs |
| [`quantilica.github.io`](https://github.com/Quantilica/quantilica.github.io) | Site institucional e landing page da Quantilica, construído com Hugo |

---

## Comandos de desenvolvimento

O workspace usa [`just`](https://github.com/casey/just) para tarefas comuns:

```bash
just sync           # sincroniza todos os pacotes (uv sync --all-packages)
just test <pacote>  # pytest para um pacote específico
just lint           # ruff check no workspace inteiro
just fmt            # ruff format no workspace inteiro
just check          # lint + fmt-check juntos
```

Sem `just`, use os equivalentes diretamente:

```bash
uv sync --all-packages
uv run --package sidra-fetcher pytest sidra-fetcher/tests/ -v
uv run ruff check .
```

---

## Estrutura do workspace

```
Quantilica/              ← este repo (meta-repo / workspace)
├── pyproject.toml       ← configuração do uv workspace
├── ruff.toml            ← configuração de linting (canônica para todos os pacotes)
├── justfile             ← tarefas de desenvolvimento
├── bootstrap.sh         ← clone + sync (Linux/macOS)
├── bootstrap.ps1        ← clone + sync (Windows)
├── CLAUDE.md            ← instruções para Claude Code
├── AGENTS.md            ← instruções para agentes de IA
├── GEMINI.md            ← instruções para Gemini CLI
├── quantilica-core/     ← sub-repositório (infraestrutura)
├── quantilica-analytics/ ← sub-repositório (infraestrutura)
├── quantilica-cli/      ← sub-repositório (infraestrutura)
├── quantilica-catalog/  ← sub-repositório (infraestrutura)
├── sidra-pipelines/     ← sub-repositório (pipelines ETL)
├── bcb-sgs-pipelines/   ← sub-repositório (pipelines ETL)
├── docs/                ← sub-repositório (documentação MkDocs)
└── quantilica.github.io/ ← sub-repositório (site Hugo)
```

> Cada subdiretório é um repositório Git independente com seu próprio histórico e ciclo de release.
