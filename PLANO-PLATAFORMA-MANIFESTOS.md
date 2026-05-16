# Plano — Plataforma de Manifestos Quantilica

> Documento de planejamento. Não é código nem contrato — é a visão de como
> evoluir o sistema de manifestos de arquivos JSON locais para uma plataforma
> SaaS de proveniência e observabilidade de dados públicos brasileiros.

---

## 1. Contexto e visão

### O problema atual

Hoje cada download produz um arquivo `.manifest.json` ao lado do dado:

```
rtn/
  rtn@20250513T120000.xlsx
  rtn@20250513T120000.xlsx.manifest.json
```

`DownloadManifest` (em `quantilica-core/src/quantilica_core/manifests.py`)
registra origem, SHA-256, tamanho e timestamp. Funciona, mas:

- Os manifestos são **escritos e quase nunca lidos** — não há ferramenta para
  consultá-los.
- Não há **visão agregada**: "o que foi coletado essa semana?", "qual dataset
  está desatualizado?", "esse arquivo mudou desde a última coleta?".
- `RunManifest` existe mas **nenhum fetcher o usa**.

O layout lado a lado em si é uma decisão deliberada (o manifesto acompanha o
dado); o que falta é uma camada de leitura/agregação por cima dele.

### A visão

Transformar o manifesto — que já é um bom *contrato de dados* — na base de uma
plataforma em quatro camadas, cada uma entregando valor de forma independente:

```
┌─────────────────────────────────────────────────────────────┐
│ Camada 4 — quantilica-manifests-db (SaaS, FastAPI + HTMX)    │
│   PostgreSQL multi-tenant + API REST + UI web + alertas      │
└───────────────────────────▲─────────────────────────────────┘
                            │ HTTP (API key)
┌───────────────────────────┴─────────────────────────────────┐
│ Camada 3 — quantilica-cloud (plugin CLI, opt-in)             │
│   Lê manifestos locais → sincroniza com a nuvem              │
└───────────────────────────▲─────────────────────────────────┘
                            │ lê arquivos
┌───────────────────────────┴─────────────────────────────────┐
│ Camada 2 — quantilica-cli (comandos de inspeção local)       │
│   list / show / status — sem banco, sem rede                 │
└───────────────────────────▲─────────────────────────────────┘
                            │ produz
┌───────────────────────────┴─────────────────────────────────┐
│ Camada 1 — quantilica-core (manifestos, offline-first)       │
│   DownloadManifest enriquecido, escrito ao lado do dado      │
└───────────────────────────────────────────────────────────────┘
```

**Princípio-chave:** a coleta (Camadas 1-2) nunca depende de rede ou banco.
Sincronizar com a nuvem (Camadas 3-4) é sempre opt-in.

---

## 2. Princípios de arquitetura

1. **Offline-first.** Um fetcher roda numa máquina sem internet e sem banco. O
   manifesto local é a fonte da verdade; a nuvem é uma réplica/índice.
2. **`quantilica-core` permanece magro.** Sem dependências de banco ou HTTP-server.
3. **Opt-in por instalação.** Quem não quer nuvem não instala `quantilica-cloud`.
   Discovery via entry points, exatamente como os fetchers.
4. **O manifesto é o contrato.** Todas as camadas falam o mesmo schema versionado.
   Mudanças de schema são aditivas (campos opcionais + `manifest_version`).
5. **Multi-tenancy desde o dia 1 no servidor.** Todo registro tem `tenant_id`.

---

## 3. Camada 1 — `quantilica-core` (mudanças mínimas)

### 3.1 Layout dos manifestos — lado a lado (decisão mantida)

Os manifestos continuam sendo escritos **ao lado do arquivo de dados**, com o
sufixo `.manifest.json`:

```
bdmep/2020/
  inmet-bdmep_2020@20250513.zip
  inmet-bdmep_2020@20250513.zip.manifest.json
```

Decisão tomada em 2026-05-15: manter o layout atual. O manifesto fica colado ao
dado que descreve — mover/copiar um diretório de dados leva o manifesto junto, e
não há estrutura paralela a manter sincronizada. As camadas superiores
(`cli`, `cloud`) localizam manifestos por glob de `**/*.manifest.json`. Nenhuma
mudança de layout ou comando de migração é necessária.

### 3.2 Manifesto versionado

Adicionar `manifest_version: int = 2` ao `DownloadManifest`. Leitores tratam
ausência do campo como versão 1.

---

## 4. Manifestos mais ricos

O `DownloadManifest` atual tem o essencial de proveniência. Para virar base de
uma plataforma de observabilidade, vale enriquecer — **tudo opcional, aditivo**.
Campos agrupados por finalidade:

### 4.1 Impressão digital de conteúdo (além do SHA-256)

| Campo | Tipo | Para quê |
|---|---|---|
| `content_type` | str | `text/csv`, `application/zip`… |
| `schema_hash` | str | hash das colunas/tipos — detecta mudança estrutural |
| `row_count` | int | nº de linhas (tabular) |
| `column_count` | int | nº de colunas |
| `temporal_extent` | [str, str] | menor/maior período coberto (ex.: `2020-01` … `2025-04`) |
| `geographic_extent` | list[str] | UFs/municípios cobertos |

### 4.2 Metadados do lado da fonte

| Campo | Tipo | Para quê |
|---|---|---|
| `source_etag` | str | ETag HTTP — detecta "não mudou" sem baixar |
| `source_last_modified` | str | header `Last-Modified` |
| `source_published_at` | str | data de publicação declarada pela fonte |
| `expected_cadence` | str | `daily`, `monthly`, `irregular` — base para SLA de frescor |

### 4.3 Linhagem (lineage)

| Campo | Tipo | Para quê |
|---|---|---|
| `derived_from` | list[str] | SHA-256 dos artefatos de entrada (transforms do `sidra-pipelines`) |
| `pipeline_id` | str | qual pipeline gerou |

Isso permite o **grafo de dependências**: "IBGE mudou a tabela X → estes
downstreams são afetados".

### 4.4 Sinais de qualidade

| Campo | Tipo | Para quê |
|---|---|---|
| `validation_status` | str | `passed` / `failed` / `skipped` |
| `null_ratio` | float | proporção de nulos — detecta publicação quebrada |
| `diff_from_previous` | dict | `{rows_added, rows_removed, cells_changed}` vs. coleta anterior |

### 4.5 Execução / ambiente (reprodutibilidade)

| Campo | Tipo | Para quê |
|---|---|---|
| `duration_ms` | int | tempo de download |
| `retry_count` | int | nº de tentativas |
| `environment` | dict | OS, versão Python, hash do `uv.lock` |
| `data_license` | str | licença / atribuição exigida |

### 4.6 Como introduzir sem quebrar nada

- Todos os campos novos são `Optional` com default — dataclass frozen continua válido.
- Quem produz preenche o que conseguir; quem consome trata ausência graciosamente.
- Fingerprint tabular (`row_count`, `schema_hash`) calculado preferencialmente
  no `quantilica-io` (já tem Polars/PyArrow), não no core.
- `diff_from_previous` calculado pela camada de sync ou pelo servidor, comparando
  com o manifesto anterior de mesmo `dataset_id`/`resource_id`.

---

## 5. Camada 2 — `quantilica-cli` (inspeção local)

Novo subcomando `manifests`, sem dependências novas — só lê os arquivos
`*.manifest.json` do storage root.

```
quantilica manifests list   [--source rtn] [--dataset bdmep] [--since 7d]
quantilica manifests show    <arquivo>
quantilica manifests status                 # datasets desatualizados vs. cadência
quantilica manifests tree                    # grafo de linhagem (derived_from)
quantilica manifests export  --format jsonl   # dump para pipe/scripts
```

### Implementação

- Arquivo novo: `quantilica-cli/src/quantilica_cli/manifests.py` — um `typer.Typer`
  montado em `cli.py` com `app.add_typer(manifests_app, name="manifests")`.
- Função `iter_manifests(storage_root)` que faz glob de `**/*.manifest.json` e
  desserializa em `DownloadManifest`.
- Renderização com `rich.Table` (já é dependência do CLI).
- `status` compara `fetched_at` com `expected_cadence` e marca atrasados.

**Valor isolado:** mesmo sem nuvem, o usuário ganha visibilidade sobre o que
coletou. Esta camada deve ser a primeira a ser construída.

---

## 6. Camada 3 — `quantilica-cloud` (sync, opt-in)

Pacote novo no workspace, registrado como plugin CLI:

```toml
# quantilica-cloud/pyproject.toml
[project.entry-points."quantilica.fetchers"]
cloud = "quantilica_cloud.plugin:app"
```

> Nota: hoje o grupo de entry points é `quantilica.fetchers` e o CLI monta tudo
> sob `quantilica fetch <name>`. Para `cloud` aparecer como `quantilica cloud …`
> (e não `quantilica fetch cloud`), o `cli.py` precisa de um pequeno ajuste:
> aceitar um segundo grupo, p.ex. `quantilica.commands`, montado na raiz do app.

### Comandos

```
quantilica cloud login      --api-key <key>      # grava credencial em ~/.quantilica/
quantilica cloud sync       [--since 7d] [--dry-run]
quantilica cloud status                            # diferença local vs. nuvem
quantilica cloud watch                             # sync contínuo (daemon leve)
```

### Comportamento do `sync`

1. Reusa `iter_manifests()` da Camada 2 para ler manifestos locais.
2. Calcula quais ainda não estão na nuvem (compara SHA-256 + `fetched_at`).
3. `POST /v1/manifests:batch` com os novos, em lotes, com retry/backoff
   (reusa `HttpClient` do `quantilica-core`).
4. Idempotente — reenviar o mesmo manifesto não duplica (server faz upsert por
   `(tenant_id, sha256, dataset_id)`).

### Dependências

- `quantilica-core` (HTTP client, manifests).
- Nada de banco. Credenciais em `~/.quantilica/credentials.toml`.

**Modo self-hosted:** `--endpoint http://localhost:8000` aponta para um servidor
próprio. O mesmo binário serve cloud e self-hosted.

---

## 7. Camada 4 — SaaS de manifestos (`quantilica-manifests-db`)

### 7.0 Stack: FastAPI + HTMX

O SaaS é um repositório novo, **`quantilica-manifests-db`**, construído com
**FastAPI + HTMX** — stack escolhido pelo usuário por ser mais moderno.

- **FastAPI** — a API REST `/v1/...`, com validação via Pydantic e OpenAPI
  automático. Os modelos Pydantic espelham o schema do `DownloadManifest` v2.
- **HTMX** — a UI web do catálogo: HTML renderizado no servidor (Jinja2), com
  fragmentos atualizados via HTMX. Sem SPA, sem build de frontend.
- Este app é a oportunidade natural de preencher o extra `fastapi` do
  `quantilica-web` (hoje um stub) com infraestrutura compartilhável.

**Relação com os apps `-db` existentes:** `bcb-sgs-metadata-db`,
`datasus-metadata-db`, `ibge-sidra-metadata-db` e `tddata-db` são apps Flask e
servem de referência para a *forma* — PostgreSQL com schema dedicado, deploy via
Docker Compose, configuração por variáveis de ambiente prefixadas. Mas o
`quantilica-manifests-db` **não** copia o stack Flask deles: usa FastAPI + HTMX.

As diferenças de propósito vs. os apps `-db` atuais são três:

1. **Multi-tenant** — os apps `-db` são catálogos públicos de uma única fonte;
   este isola dados por `tenant_id` (+ Row-Level Security).
2. **API de escrita autenticada** — recebe `POST /v1/manifests:batch` do
   `quantilica-cloud`, autenticado por API key (os apps atuais só leem).
3. **Comercial** — tem planos, cobrança e o catálogo público da comunidade.

### 7.1 Componentes

| Componente | Tecnologia | Papel |
|---|---|---|
| API REST | FastAPI (Pydantic + OpenAPI) | ingestão e consulta de manifestos (`/v1/...`) |
| UI web | HTMX + Jinja2 (renderização no servidor) | exploração do catálogo, sem SPA |
| Banco | PostgreSQL (Supabase / Neon / RDS), schema dedicado | armazenamento multi-tenant |
| Worker | fila assíncrona (ex.: ARQ / Dramatiq, afins de FastAPI) | cálculo de diff, alertas de frescor, anomalias |
| Cache / rate limit | Redis | caching de queries, limite por tenant |
| Deploy | Docker Compose | mesma topologia dos apps `-db` |

> **Decisão (2026-05-15):** FastAPI + HTMX, definido pelo usuário. O lado
> FastAPI do `quantilica-web` deixa de ser stub e passa a hospedar a
> infraestrutura compartilhada (config, auth por API key, error handlers).

### 7.2 Modelo de dados (PostgreSQL)

```sql
-- Isolamento de tenant
CREATE TABLE tenants (
    id            UUID PRIMARY KEY,
    name          TEXT NOT NULL,
    plan          TEXT NOT NULL DEFAULT 'free',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE api_keys (
    id            UUID PRIMARY KEY,
    tenant_id     UUID NOT NULL REFERENCES tenants(id),
    key_hash      TEXT NOT NULL,           -- nunca a chave em claro
    label         TEXT,
    last_used_at  TIMESTAMPTZ,
    revoked_at    TIMESTAMPTZ
);

-- Núcleo: cada manifesto sincronizado
CREATE TABLE manifests (
    id                UUID PRIMARY KEY,
    tenant_id         UUID NOT NULL REFERENCES tenants(id),
    source_id         TEXT NOT NULL,
    dataset_id        TEXT NOT NULL,
    resource_id       TEXT,
    url               TEXT,
    sha256            TEXT NOT NULL,
    size_bytes        BIGINT NOT NULL,
    fetched_at        TIMESTAMPTZ NOT NULL,
    producer          TEXT,
    producer_version  TEXT,
    manifest_version  INT NOT NULL DEFAULT 2,
    -- campos ricos da seção 4, normalizados ou em JSONB:
    fingerprint       JSONB,    -- row_count, schema_hash, temporal_extent…
    source_meta       JSONB,    -- etag, last_modified, cadence…
    quality           JSONB,    -- validation_status, null_ratio…
    lineage           JSONB,    -- derived_from, pipeline_id
    metadata          JSONB,    -- campo livre original
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, sha256, dataset_id)
);

CREATE INDEX idx_manifests_tenant_dataset
    ON manifests (tenant_id, source_id, dataset_id, fetched_at DESC);

-- Catálogo derivado: estado atual de cada dataset
CREATE TABLE datasets (
    tenant_id          UUID NOT NULL REFERENCES tenants(id),
    source_id          TEXT NOT NULL,
    dataset_id         TEXT NOT NULL,
    latest_manifest_id UUID REFERENCES manifests(id),
    latest_fetched_at  TIMESTAMPTZ,
    expected_cadence   TEXT,
    is_stale           BOOLEAN DEFAULT false,
    PRIMARY KEY (tenant_id, source_id, dataset_id)
);
```

**Isolamento:** toda query carrega `WHERE tenant_id = :current`. Em PostgreSQL,
reforçar com **Row-Level Security (RLS)** — política que amarra o `tenant_id` ao
contexto da sessão, defesa em profundidade contra bug de query.

**Catálogo público (opcional):** uma view materializada agrega, sobre os tenants
que optaram por publicar, dados desidentificados — base do "catálogo da
comunidade" (ver seção 8).

### 7.3 API REST (v1)

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/v1/manifests:batch` | ingestão em lote (usado pelo `sync`) |
| `GET` | `/v1/manifests` | lista com filtros `source`, `dataset`, `since`, `sha256` |
| `GET` | `/v1/manifests/{id}` | detalhe de um manifesto |
| `GET` | `/v1/datasets` | catálogo de datasets do tenant |
| `GET` | `/v1/datasets/{id}/history` | linha do tempo de versões |
| `GET` | `/v1/datasets/{id}/diff?from=&to=` | diferença entre duas versões |
| `GET` | `/v1/freshness` | datasets atrasados vs. cadência esperada |
| `GET` | `/v1/lineage/{sha256}` | grafo de dependências (upstream/downstream) |
| `POST` | `/v1/webhooks` | registra webhook para eventos |
| `GET` | `/v1/catalog/public` | catálogo público da comunidade |

Autenticação: header `Authorization: Bearer <api_key>`. Rate limiting por tenant
(Redis). Versionamento por prefixo `/v1/`.

### 7.4 Workers assíncronos

- **Diff worker** — ao ingerir manifesto novo, compara com o anterior do mesmo
  dataset e preenche `diff_from_previous`.
- **Freshness worker** — cron que marca `is_stale` quando `now - latest_fetched_at`
  excede a cadência esperada; dispara alertas.
- **Anomaly worker** — detecta outliers (tamanho/linhas fora do padrão histórico).
- **Webhook dispatcher** — entrega eventos (Slack, e-mail, HTTP).

---

## 8. Ideias de negócio — SaaS

A plataforma é, em essência, um **catálogo de proveniência e observabilidade
para dados públicos brasileiros**. Abaixo, ângulos de produto — do mais direto
ao mais ambicioso.

### 8.1 Produtos centrais

**A. Monitor de frescor ("status page" dos dados públicos)**
Alerta quando uma fonte que você depende não atualizou no prazo, ou atualizou
inesperadamente. IBGE, BCB, DATASUS, CAGED publicam em cadências irregulares —
hoje as equipes descobrem por acaso. Vira o "Datadog dos dados públicos".

**B. Feed de mudanças / changelog de dados**
Assine um dataset, receba o que mudou entre versões: linhas adicionadas, valores
revisados. BCB e IBGE **revisam séries históricas silenciosamente** — a plataforma
torna isso visível. Killer feature para mesas de pesquisa macro.

**C. Detecção de anomalias antes da ingestão**
"Esse arquivo costuma ter 50 MB; hoje veio com 2 MB" → publicação upstream
quebrada. Avisa **antes** de você ingerir lixo no pipeline.

**D. Catálogo da comunidade (efeito de rede)**
O SHA-256 de um arquivo público é igual para todos. A plataforma deduplica entre
usuários: "IBGE publicou a tabela SIDRA 6579 hoje às 14:32 — 1.204 usuários já
têm essa versão". Quanto mais usuários, mais rico o catálogo. Free tier alimenta
o catálogo; isso vira o fosso competitivo.

### 8.2 Ângulos adjacentes

**E. Reprodutibilidade e citação acadêmica**
Registro permanente e citável de qual versão exata de um dado público foi usada
numa análise. Gera uma "citação" tipo DOI: *"IBGE PNAD, SHA-256 abc…, coletado
2026-03-01"*. Mercado: universidades, revistas científicas, think tanks.

**F. Governança e compliance**
Para bancos e fintechs: prova de linhagem para auditoria (reporte BACEN, LGPD).
"De onde veio esse número, quando, de qual fonte oficial." Audit log imutável.

**G. Mirror verificado / CDN de dados públicos**
Fontes oficiais são lentas e instáveis. Como o manifesto traz URL + SHA-256, a
plataforma serve uma cópia em cache, verificada por checksum. Download confiável
e rápido — cobra por banda/armazenamento.

**H. Análise de impacto via grafo de linhagem**
"IBGE mudou a tabela X" → a plataforma mostra os 12 pipelines/dashboards
downstream afetados. Vende-se para times de dados com muitos pipelines encadeados.

**I. Webhooks / event bus**
"Dispare meu DAG do Airflow / notifique meu Slack quando o CAGED publicar."
Integra a plataforma ao stack de orquestração do cliente.

**J. Observabilidade de ETL**
Dashboards de duração de execução, taxa de falha, volume de dados ao longo do
tempo — usando `RunManifest` + campos de execução da seção 4.5.

### 8.3 Modelo de planos

| Plano | Público | Inclui |
|---|---|---|
| **Free / self-hosted** | indivíduos, OSS | catálogo próprio, leitura do catálogo público |
| **Pro** | analistas, pesquisadores | catálogo privado, alertas de frescor, feed de diff |
| **Team** | times de dados | multiusuário, RBAC, webhooks, catálogo compartilhado |
| **Enterprise** | bancos, governo | SSO, audit log, SLA, VPC/on-prem, exportação de compliance |

**Monetização além de assinatura:** medição de uso de API; banda do mirror
verificado; conectores premium; relatórios de compliance sob demanda.

### 8.4 Clientes-alvo

- Consultorias e casas de pesquisa econômica (o próprio nicho da Quantilica).
- Bancos e gestoras — mesas de research macro.
- Setor público e órgãos de controle.
- Academia e think tanks.
- Jornalismo de dados.
- Fintechs de crédito (dados alternativos).

### 8.5 Estratégia de entrada (go-to-market)

1. **Open source primeiro.** Os fetchers e o CLI já são abertos — são o funil.
   Quem usa o ecossistema é o lead natural da nuvem.
2. **Free tier alimenta o catálogo público.** Efeito de rede: o produto melhora
   sozinho conforme cresce a base.
3. **Conteúdo + SEO.** Cada dataset público vira uma página indexável ("CAGED
   março 2026 — metadados, frequência, histórico"). Tráfego orgânico de quem
   pesquisa dados públicos brasileiros.
4. **Land and expand.** Entra grátis pelo monitor de frescor; expande para diff,
   webhooks, compliance.

---

## 9. Roadmap incremental

Cada fase entrega valor sozinha — não há big bang.

### Fase 0 — Fundação (`quantilica-core`)
- Campo `manifest_version`.
- Layout dos manifestos mantido lado a lado (sem mudança).

### Fase 1 — Inspeção local (`quantilica-cli`)
- Subcomando `quantilica manifests` (`list`, `show`, `status`).
- **Entregável:** visibilidade local, zero rede. Já útil sozinho.

### Fase 2 — Manifestos ricos
- Campos da seção 4, preenchidos progressivamente (fingerprint via `quantilica-io`).
- Atualizar fetchers para popular `expected_cadence`, `source_etag` etc.

### Fase 3 — Sync (`quantilica-cloud`)
- Pacote novo + ajuste no `cli.py` para grupo `quantilica.commands`.
- `login`, `sync`, `status` contra um servidor self-hosted.

### Fase 4 — SaaS MVP (novo repo `quantilica-manifests-db`)
- Repositório novo, **FastAPI + HTMX**, PostgreSQL, Docker; reusa a *forma* dos
  apps `-db` (schema dedicado, env-vars, Docker Compose), não o stack Flask.
- Schema multi-tenant (`tenants`, `api_keys`, `manifests`, `datasets`) + RLS.
- API FastAPI: `POST /v1/manifests:batch` + endpoints de consulta da seção 7.3,
  autenticados por API key (dependency que valida `Authorization: Bearer`).
- UI HTMX mínima: catálogo de datasets e histórico.
- Produto comercial: **monitor de frescor** (8.1.A).

### Fase 5 — Diferenciação
- Workers de diff e anomalia; feed de mudanças (8.1.B/C).
- Webhooks; grafo de linhagem.
- Catálogo público da comunidade (8.1.D).

---

## 10. Riscos e decisões em aberto

| Tema | Questão | Recomendação inicial |
|---|---|---|
| API server | FastAPI ou Flask? | **Resolvido (usuário):** FastAPI + HTMX — stack mais moderno; preenche o extra `fastapi` do `quantilica-web` |
| Repo do SaaS | App separado ou dentro do `quantilica-web`? | **Resolvido:** repo novo `quantilica-manifests-db`; `quantilica-web` é só a infraestrutura compartilhada |
| Fila de workers | Celery (como o `bcb-sgs-metadata-db`) ou alternativa async? | Em aberto — preferir algo idiomático com FastAPI/async (ex.: ARQ, Dramatiq) |
| Banco gerenciado | Supabase, Neon ou RDS? | Supabase no MVP (Postgres + auth + REST automática aceleram) |
| Schema rico | Colunas dedicadas ou JSONB? | JSONB nos grupos da seção 4; promover a coluna o que for muito consultado |
| Privacidade | O que pode ir ao catálogo público? | Só metadados de fontes **públicas**; opt-in explícito por tenant |
| Cálculo de diff | Cliente ou servidor? | Servidor (worker) — cliente não deve depender de ter a versão anterior |
| `quantilica-cloud` no workspace | Adicionar aos `members`? | Sim, na Fase 3, com `uv sync --all-packages` |

---

## 11. Resumo

O manifesto que já existe é um bom contrato de proveniência. O plano o
transforma, sem reescritas, na base de quatro camadas:

1. **core** continua offline-first, com manifestos lado a lado e campos ricos;
2. **cli** dá inspeção local imediata;
3. **cloud** sincroniza, opt-in, com qualquer servidor;
4. **`quantilica-manifests-db`** — novo app **FastAPI + HTMX**, multi-tenant,
   é o SaaS de observabilidade de dados públicos.

A Camada 4 reusa a *forma* dos apps `-db` (PostgreSQL com schema dedicado, deploy
Docker, config por env-vars), mas com stack próprio: FastAPI para a API e HTMX
para a UI. O produto comercial nasce do monitor de frescor e cresce para diff,
linhagem e um catálogo de comunidade com efeito de rede — sempre alimentado pelo
ecossistema open source que já existe.
