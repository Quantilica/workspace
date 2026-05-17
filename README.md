# Quantilica — Workspace de Desenvolvimento

Este repositório é o **workspace de desenvolvimento** do ecossistema Quantilica. Não é um pacote instalável — ele coordena o desenvolvimento local de todos os pacotes do ecossistema usando [`uv` workspaces](https://docs.astral.sh/uv/concepts/workspaces/).

---

## Setup local

**Pré-requisitos:** Python >= 3.12, [`uv`](https://docs.astral.sh/uv/getting-started/installation/)

Clone cada sub-repositório dentro deste diretório e então sincronize o workspace:

```bash
uv sync --all-packages
```

Isso cria um único `.venv` compartilhado com todos os pacotes instalados como editable installs. Mudanças em qualquer pacote são imediatamente visíveis nos demais.

---

## Pacotes

### Infraestrutura

| Pacote | Versão | Descrição |
|---|---|---|
| [`quantilica-core`](https://github.com/Quantilica/quantilica-core) | 0.2.0 | Utilitários base: HTTP, storage, logging, manifestos de proveniência |
| [`quantilica-io`](https://github.com/Quantilica/quantilica-io) | 0.1.0 | Processamento analítico: Polars, Parquet, schemas |
| [`quantilica-cli`](https://github.com/Quantilica/quantilica-cli) | 0.1.0 | CLI unificada com arquitetura de plugins via entry points |
| [`quantilica-cloud`](https://github.com/Quantilica/quantilica-cloud) | 0.1.0 | Plugin de CLI para sincronizar manifestos de download com um catálogo na nuvem |

### Coletores de dados

| Pacote | Versão | Fonte | Descrição |
|---|---|---|---|
| [`sidra-fetcher`](https://github.com/Quantilica/sidra-fetcher) | 0.6.1 | IBGE/SIDRA | Cliente da API de Agregados e SIDRA |
| [`sidra-sql`](https://github.com/Quantilica/sidra-sql) | 1.1.0 | IBGE/SIDRA | Carregamento de tabelas SIDRA em PostgreSQL |
| [`comex-fetcher`](https://github.com/Quantilica/comex-fetcher) | 1.5.2 | MDIC | Dados de comércio exterior (importação/exportação) |
| [`datasus-fetcher`](https://github.com/Quantilica/datasus-fetcher) | 0.4.1 | DATASUS | Microdados de saúde (FTP) |
| [`inmet-fetcher`](https://github.com/Quantilica/inmet-fetcher) | 0.2.0 | INMET | Dados meteorológicos (BDMEP) |
| [`pdet-fetcher`](https://github.com/Quantilica/pdet-fetcher) | 0.1.1 | MTE/PDET | Microdados de trabalho (CAGED, RAIS) |
| [`rtn-fetcher`](https://github.com/Quantilica/rtn-fetcher) | 0.1.0 | STN | Dados fiscais (RTN) |
| [`tesouro-direto-fetcher`](https://github.com/Quantilica/tesouro-direto-fetcher) | 2.1.1 | STN | Dados do Tesouro Direto |
| [`bcb-sgs-fetcher`](https://github.com/Quantilica/bcb-sgs-fetcher) | 0.1.0 | BCB/SGS | Séries temporais do Banco Central |

### Pipelines ETL

| Pacote | Descrição |
|---|---|
| [`sidra-pipelines`](https://github.com/Quantilica/sidra-pipelines) | Catálogo declarativo de pipelines SIDRA (fetch.toml + transform.sql) |

---

## Aplicações

Além dos pacotes (bibliotecas e ferramentas), o diretório do workspace também abriga as **aplicações web** da Quantilica. São uma camada distinta: repositórios **privados**, **não** são membros do uv workspace, têm o próprio `uv.lock` e ciclo de deploy, e rodam sobre **Flask + PostgreSQL + Docker**.

| Aplicação | Descrição |
|---|---|
| [`bcb-sgs-metadata-db`](https://github.com/Quantilica/bcb-sgs-metadata-db) | App Flask + Celery + PostgreSQL + Redis — espelho de metadados e séries do BCB/SGS |
| [`datasus-metadata-db`](https://github.com/Quantilica/datasus-metadata-db) | App Flask + PostgreSQL — rastreador de mudanças nos metadados do FTP do DATASUS |
| [`ibge-sidra-metadata-db`](https://github.com/Quantilica/ibge-sidra-metadata-db) | App Flask + PostgreSQL — explorador de metadados do IBGE/SIDRA |
| [`tddata-db`](https://github.com/Quantilica/tddata-db) | App Flask + PostgreSQL — explorador de dados do Tesouro Direto |
| [`quantilica.github.io`](https://github.com/Quantilica/quantilica.github.io) | Site estático (Hugo) — GitHub Pages da organização |

> Os pacotes são públicos (MIT) e seguem convenções compartilhadas estritas; as aplicações são privadas e cada uma define as próprias convenções. `uv sync --all-packages` instala apenas os pacotes, não as aplicações.

---

## Estrutura do workspace

```
Quantilica/              ← este repo (meta-repo / workspace)
├── pyproject.toml       ← configuração do uv workspace
├── uv.lock              ← lock file compartilhado
├── CLAUDE.md            ← instruções para Claude Code
├── AGENTS.md            ← instruções para agentes de IA
├── GEMINI.md            ← instruções para Gemini CLI
├── quantilica-core/     ← sub-repositório
├── quantilica-io/       ← sub-repositório
├── quantilica-cli/      ← sub-repositório
├── sidra-fetcher/       ← sub-repositório
└── ...
```

> Cada subdiretório é um repositório Git independente com seu próprio histórico e ciclo de release.
