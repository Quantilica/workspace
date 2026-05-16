# Fase 4 — `quantilica-manifests-db`: Plano detalhado do SaaS

## Contexto

As Fases 0–3 da [plataforma de manifestos](PLANO-PLATAFORMA-MANIFESTOS.md)
estão concluídas: o `quantilica-core` produz manifestos ricos (v2), o
`quantilica-cli` os inspeciona localmente e o `quantilica-cloud` os sincroniza
via `POST /v1/manifests:batch` — mas **não existe servidor** que receba esse
sync. A Fase 4 cria esse servidor: `quantilica-manifests-db`, um SaaS
multi-tenant de **observabilidade e proveniência de dados públicos brasileiros**.

É o lado-servidor do `quantilica-cloud` e o produto comercial da plataforma.

**Decisões já tomadas** (usuário, 2026-05-15):
- Stack: **FastAPI + HTMX** (não Flask).
- Hospedagem: **self-hosted** (Docker Compose em VPS própria).
- Billing: **adiado** — lançamento em **beta gratuito por convite**.
- Infra FastAPI compartilhada: **preencher o stub `quantilica-web.fastapi`** desde já.

---

## 1. Visão do produto

`quantilica-manifests-db` é o **plano de controle** dos pipelines de dados
públicos. Times que coletam dados públicos brasileiros (com os fetchers
Quantilica ou qualquer outra ferramenta) sincronizam seus `DownloadManifest`
para o SaaS e ganham:

- **Catálogo consultável** — o que foi coletado, quando, de onde, em que versão.
- **Monitor de frescor** — alerta quando um dataset não atualiza no prazo, ou
  atualiza fora do esperado. *(produto-cunha do MVP)*
- **Feed de mudanças** — diff entre versões de um dataset (linhas/valores).
- **Linhagem** — grafo de dependências entre artefatos derivados.
- **Detecção de anomalia** — arquivo fora do padrão histórico antes da ingestão.
- **Catálogo público da comunidade** — efeito de rede entre tenants.

Posicionamento: *"o Datadog dos dados públicos brasileiros"*.

---

## 2. Público-alvo

### Personas

| Persona | Contexto | Dor | O que valoriza |
|---|---|---|---|
| **Analista macro** | Gestora / consultoria econômica | Descobre dado desatualizado por acaso; revisões silenciosas do IBGE/BCB | Alertas de frescor, feed de mudanças |
| **Engenheiro de dados** | Time de plataforma rodando pipelines | Sem observabilidade dos pipelines; quebra em cascata quando a fonte muda | Webhooks, grafo de linhagem, API |
| **Pesquisador** | Academia / think tank | Precisa reproduzir/citar a versão exata do dado | Registro permanente de proveniência |

### ICP do beta

Times pequenos de dados (2–10 pessoas) em **casas de pesquisa econômica e
gestoras** — já usam fetchers Quantilica ou raspam as mesmas fontes, sentem a
dor de frescor de forma aguda e têm orçamento. É também o nicho da própria
Quantilica, o que dá acesso direto a design partners.

---

## 3. Plano de negócios

### Estratégia de beta (fase atual — billing adiado)

- **Beta gratuito, por convite.** Meta: 10–20 design partners nos primeiros
  3–6 meses.
- Objetivo do beta: validar o produto-cunha (monitor de frescor), recolher
  feedback e **semear o catálogo público** (efeito de rede).
- Métricas de sucesso: nº de tenants ativos, nº de manifestos sincronizados,
  nº de datasets monitorados, taxa de engajamento com alertas, retenção 4 semanas.
- Sem cobrança = burn mínimo: a escolha self-hosted mantém o custo de infra
  baixo (VPS + e-mail transacional + domínio).

### Modelo de planos (pós-beta)

| Plano | Público | Inclui |
|---|---|---|
| **Free / self-hosted** | indivíduos, OSS | catálogo próprio, leitura do catálogo público |
| **Pro** | analistas, pesquisadores | catálogo privado, alertas de frescor, feed de diff |
| **Team** | times de dados | multiusuário, RBAC, webhooks, catálogo compartilhado |
| **Enterprise** | bancos, governo | SSO, audit log, SLA, exportação de compliance |

Preços exatos a definir com base no beta. Gatilhos de tier: nº de datasets
monitorados, nº de usuários, frequência de sync, canais de alerta.

### Go-to-market

1. **Funil open source** — usuários de `quantilica-cli`/fetchers/`quantilica-cloud`
   são o lead natural; o `cloud sync` já aponta para a nuvem.
2. **Conteúdo + SEO** — cada dataset público vira página indexável.
3. **Rede Quantilica** — acesso direto a consultorias e gestoras como design partners.
4. **Land & expand** — entra grátis pelo monitor de frescor; expande para diff,
   webhooks, compliance.

### Fosso competitivo

O **catálogo público da comunidade**: o SHA-256 de um arquivo público é igual
para todos. Quanto mais tenants, mais rico o sinal cross-tenant ("o IBGE
publicou a tabela X hoje"). O produto melhora sozinho com a adoção.

### Riscos

- Adoção depende de `quantilica-cloud` ganhar tração primeiro.
- Nicho de dados públicos pode ser estreito — mitigar mirando o uso B2B.
- Privacidade: metadados de manifestos de tenants são sensíveis — isolamento
  rígido e catálogo público estritamente opt-in.

---

## 4. Arquitetura

### Visão geral

```
  quantilica-cloud (clientes)
        │  POST /v1/manifests:batch   (Authorization: Bearer qm_…)
        ▼
┌─────────────────────────────────────────────────────────┐
│  quantilica-manifests-db  (Docker Compose, VPS própria)   │
│                                                           │
│  ┌─────────────┐   ┌──────────┐   ┌───────────────────┐  │
│  │ web         │   │ worker   │   │ reverse proxy      │  │
│  │ FastAPI     │   │ ARQ      │   │ Caddy (TLS auto)   │  │
│  │ API + HTMX  │   │ async    │   └───────────────────┘  │
│  └─────┬───────┘   └────┬─────┘                          │
│        │                │                                │
│   ┌────▼────────────────▼────┐    ┌──────────────────┐   │
│   │ PostgreSQL (multi-tenant │    │ Redis            │   │
│   │  + Row-Level Security)   │    │ cache/fila/limit │   │
│   └──────────────────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Componentes

| Componente | Tecnologia | Papel |
|---|---|---|
| `web` | FastAPI + Uvicorn (atrás de Gunicorn) | API REST `/v1` **e** UI HTMX (Jinja2) no mesmo processo |
| `worker` | ARQ (fila async sobre Redis) | diff, checagem de frescor (cron), anomalia, despacho de alertas/webhooks |
| `postgres` | PostgreSQL 16+ | armazenamento multi-tenant com RLS |
| `redis` | Redis 7+ | cache de queries, rate limit, broker do ARQ |
| proxy | Caddy | TLS automático, reverse proxy |

Um único app FastAPI serve API e UI — a UI HTMX consome endpoints internos que
renderizam fragmentos de HTML; a API `/v1` é JSON. Auth diferente para cada
(sessão para a UI, API key para a `/v1`).

### Infra FastAPI compartilhada — `quantilica-web.fastapi`

O stub `quantilica-web/src/quantilica_web/fastapi/` será preenchido como parte
da Fase 4, espelhando o lado `flask/`. Conteúdo (o próprio comentário do stub
já lista o escopo):

| Módulo | Conteúdo |
|---|---|
| `app_factory.py` | `create_fastapi_app()` — CORS, middlewares, lifespan (pools de DB/Redis), routers, error handlers |
| `config.py` | `BaseWebSettings` (Pydantic Settings) — validação de `SECRET_KEY`, de nome de schema |
| `auth.py` | dependencies `require_api_key()` e `require_user()`; hashing de senha (argon2) |
| `errors.py` | handlers 401/403/404/422/500 — JSON para `/v1`, HTML para a UI |
| `security.py` | middleware de cabeçalhos de segurança (espelha o `flask/security.py`) |
| `pagination.py` | helper de paginação keyset/cursor |
| `health.py` | router `GET /health` |

> Reuso: `quantilica-web/src/quantilica_web/flask/*` é o molde direto de cada
> módulo equivalente. A lógica (validação de schema, fallback de cache,
> cabeçalhos) é portável; só a camada de framework muda.

### Multi-tenancy

- **`tenant_id`** em toda tabela de dados.
- **Resolução de tenant**: a API key (`/v1`) e a sessão de usuário (UI) resolvem
  para um `tenant_id` via dependency do FastAPI.
- **Row-Level Security (PostgreSQL)**: a cada request, a sessão de banco recebe
  `SET app.tenant_id = :id`; políticas RLS filtram todas as tabelas
  tenant-scoped. Defesa em profundidade contra bug de query — o isolamento não
  depende de o ORM lembrar do `WHERE tenant_id`.

---

## 5. Stack e requisitos

### Stack Python

| Camada | Escolha | Justificativa |
|---|---|---|
| Runtime | Python 3.13 | base do Dockerfile do `bcb-sgs-metadata-db` |
| Web | FastAPI + Uvicorn (workers via Gunicorn) | decisão do usuário; async nativo |
| UI | HTMX + Jinja2 + Bootstrap 5 | server-rendered, sem build de frontend; Bootstrap mantém consistência com os apps `-db` |
| ORM | SQLAlchemy 2.0 **async** + `asyncpg` | idiomático com FastAPI async |
| Migrations | **Alembic** | *desvio consciente* dos apps `-db` (que usam SQL cru + `create_all`) — um SaaS com tenants pagantes precisa de evolução de schema versionada e segura |
| Validação | Pydantic v2 + `pydantic-settings` | modelos de request/response e config |
| Fila async | **ARQ** | Redis-based, idiomático com async (vs. Celery dos apps Flask) |
| Auth | `argon2-cffi` (senhas), API keys com hash SHA-256 | — |
| Rate limit | `slowapi` ou limitador Redis próprio | limite por tenant |
| Contrato de dados | dependência de `quantilica-core` | reusa `DownloadManifest`/`MANIFEST_VERSION` como fonte única do schema; os modelos Pydantic espelham-no |
| Infra compartilhada | `quantilica-web[fastapi]` | factory, auth, errors, health |

### Serviços de terceiros

| Serviço | Uso | Recomendação |
|---|---|---|
| E-mail transacional | alertas, convites de beta, conta | provedor com boa entregabilidade (Resend / Brevo) — não SMTP próprio |
| Telegram Bot API | canal de alerta alternativo | reusar o padrão do `bcb-sgs-metadata-db` (`telegram_notifier.py`) |
| Error tracking | rastreio de exceções | Sentry (self-hosted ou free tier) |
| TLS / DNS | HTTPS | Caddy (Let's Encrypt automático) |
| Pagamento | — | **fora de escopo** (billing adiado) |
| Object storage | — | não necessário no MVP (manifestos são JSON pequeno) |

### Infraestrutura (self-hosted)

- **Docker Compose** com serviços `web`, `worker`, `postgres`, `redis`, `caddy`.
- `Dockerfile` multi-stage com `uv` (molde: `bcb-sgs-metadata-db/Dockerfile`).
- Config por variáveis de ambiente prefixadas `QMANIFESTS_*` (padrão dos apps `-db`).
- Backups: `pg_dump` agendado (cron no host ou serviço dedicado no compose).

### Variáveis de ambiente (principais)

```
QMANIFESTS_DATABASE_URI       DSN PostgreSQL (asyncpg)
QMANIFESTS_DATABASE_SCHEMA    schema dedicado (default: quantilica_manifests)
QMANIFESTS_SECRET_KEY         chave de sessão (mín. 32 chars)
QMANIFESTS_REDIS_URL          Redis (cache, rate limit, ARQ)
QMANIFESTS_BASE_URL           URL pública (links em e-mails/webhooks)
QMANIFESTS_EMAIL_API_KEY      provedor de e-mail transacional
QMANIFESTS_TELEGRAM_BOT_TOKEN opcional — canal de alerta
QMANIFESTS_SENTRY_DSN         opcional — error tracking
```

---

## 6. Modelo de dados (PostgreSQL)

Schema dedicado, todas as tabelas tenant-scoped sob RLS. Migrations geridas por
Alembic.

| Tabela | Campos-chave | Notas |
|---|---|---|
| `tenants` | `id`, `name`, `slug`, `plan`, `created_at` | organização |
| `users` | `id`, `tenant_id`, `email`, `password_hash`, `role`, `last_login_at` | login da UI; `role` ∈ admin/member |
| `api_keys` | `id`, `tenant_id`, `key_hash`, `prefix`, `label`, `last_used_at`, `revoked_at` | chave em claro só no momento da criação |
| `manifests` | `id`, `tenant_id`, `source_id`, `dataset_id`, `resource_id`, `url`, `sha256`, `size_bytes`, `fetched_at`, `producer`, `manifest_version`, `fingerprint` JSONB, `source_meta` JSONB, `quality` JSONB, `lineage` JSONB, `metadata` JSONB | núcleo; `UNIQUE(tenant_id, sha256, dataset_id)` torna a ingestão idempotente |
| `datasets` | `tenant_id`, `source_id`, `dataset_id`, `latest_manifest_id`, `latest_fetched_at`, `expected_cadence`, `is_stale`, `manifest_count` | projeção do estado atual; mantida na ingestão |
| `alert_rules` | `id`, `tenant_id`, seletor de dataset, `condition` (stale/changed/anomaly), `channel`, `target`, `enabled` | regras de alerta |
| `alert_events` | `id`, `tenant_id`, `rule_id`, `fired_at`, `payload`, `delivered_at` | histórico de disparos |
| `webhooks` | `id`, `tenant_id`, `url`, `secret`, `events[]`, `enabled` | entrega de eventos |

Índices: `manifests(tenant_id, source_id, dataset_id, fetched_at DESC)`,
`manifests(tenant_id, sha256)`. RLS: política por tabela via
`current_setting('app.tenant_id')`.

Os grupos ricos (`fingerprint`, `source_meta`, `quality`, `lineage`) ficam em
JSONB; promover a coluna dedicada o que se mostrar muito consultado.

---

## 7. API REST `/v1` e UI HTMX

### API REST (consumida por `quantilica-cloud` e usuários programáticos)

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/v1/manifests:batch` | ingestão em lote — idempotente via `UNIQUE` |
| `GET` | `/v1/manifests` | lista com filtros `source`, `dataset`, `since`, `sha256` |
| `GET` | `/v1/manifests/{id}` | detalhe |
| `GET` | `/v1/datasets` | catálogo de datasets do tenant |
| `GET` | `/v1/datasets/{id}/history` | linha do tempo de versões |
| `GET` | `/v1/datasets/{id}/diff?from=&to=` | diferença entre versões |
| `GET` | `/v1/freshness` | datasets atrasados vs. cadência |
| `GET` | `/v1/lineage/{sha256}` | grafo de dependências |
| `POST` | `/v1/webhooks` | registra webhook |

Auth: `Authorization: Bearer qm_<key>`. Rate limit por tenant. Versionamento por
prefixo `/v1/`. OpenAPI automático em `/v1/docs`.

### UI HTMX (sessão de usuário)

Páginas: login/convite · dashboard de frescor · lista de datasets · detalhe de
dataset (histórico + diff) · configuração de alertas · gestão de API keys ·
configurações da conta. Server-rendered (Jinja2), interatividade via HTMX.

### Workers (ARQ)

- **diff** — ao ingerir manifesto novo, compara com o anterior do mesmo dataset
  e preenche `quality.diff_from_previous`.
- **freshness** — cron periódico; marca `datasets.is_stale` e dispara
  `alert_rules` do tipo `stale`.
- **anomaly** — detecta outliers de tamanho/linhas vs. histórico.
- **dispatch** — entrega de `alert_events` e webhooks (e-mail, Telegram, HTTP).

---

## 8. Roadmap de implementação

| Marco | Entregável |
|---|---|
| **M0 — Fundação** | Repo `quantilica-manifests-db`; preencher `quantilica-web.fastapi`; Docker Compose; Alembic baseline; `/health` |
| **M1 — Ingestão** | `POST /v1/manifests:batch` + auth por API key + multi-tenancy + RLS. **`quantilica-cloud sync` funciona de verdade contra o servidor** |
| **M2 — Consulta** | Endpoints de query `/v1` + projeção `datasets` mantida na ingestão |
| **M3 — UI** | UI HTMX: catálogo, detalhe de dataset, histórico; login de usuário |
| **M4 — Frescor (produto-cunha)** | Worker de freshness + `alert_rules` + entrega por e-mail/Telegram |
| **M5 — Beta** | Convites, onboarding, gestão de API keys na UI; beta gratuito por convite |
| **Pós-beta** | Feed de diff, webhooks, grafo de linhagem, catálogo público, billing |

Cada marco do M1 em diante entrega valor verificável de ponta a ponta.

---

## 9. Arquivos e estrutura propostos

Repo novo `quantilica-manifests-db/` (repo Git independente, privado, **não**
membro do uv workspace — como os apps `-db`):

```
quantilica-manifests-db/
├── pyproject.toml            deps; [project.scripts] qmanifests-admin
├── Dockerfile                multi-stage uv (molde: bcb-sgs-metadata-db)
├── docker-compose.yaml       web, worker, postgres, redis, caddy
├── alembic.ini  /  migrations/
├── src/quantilica_manifests_db/
│   ├── app.py                create_app() via quantilica-web.fastapi
│   ├── config.py             Settings (QMANIFESTS_*)
│   ├── db.py                 engine async, sessão, SET app.tenant_id
│   ├── models.py             SQLAlchemy 2.0
│   ├── schemas.py            modelos Pydantic (espelham DownloadManifest)
│   ├── auth.py               dependencies de API key / sessão
│   ├── routers/              v1_manifests, v1_datasets, v1_freshness, ui_*
│   ├── workers/              arq: diff, freshness, anomaly, dispatch
│   ├── templates/            Jinja2 + HTMX
│   └── cli.py                qmanifests-admin: create-db, create-tenant, issue-key
└── tests/
```

### Arquivos existentes a reutilizar

- `quantilica-web/src/quantilica_web/flask/*` — molde de cada módulo do novo
  `quantilica_web/fastapi/`.
- `bcb-sgs-metadata-db/Dockerfile`, `docker-compose.yaml`, `config.py` — molde
  de deploy e configuração.
- `quantilica-core/src/quantilica_core/manifests.py` — contrato `DownloadManifest`
  v2 (fonte única do schema dos manifestos).
- `quantilica-cloud/src/quantilica_cloud/client.py` — define o contrato que o
  servidor precisa honrar (`/v1/manifests:batch`, `/v1/datasets`).

---

## 10. Verificação (ponta a ponta)

1. `docker compose up -d` — sobe web, worker, postgres, redis, caddy.
2. `alembic upgrade head` — aplica o schema.
3. `qmanifests-admin create-tenant "Acme"` + `issue-key` — gera uma API key.
4. `quantilica cloud login --endpoint http://localhost:8000 --api-key <key>` e
   `quantilica cloud sync -r <dir com manifestos>` — confirma ingestão real.
5. `GET /v1/datasets` retorna os datasets sincronizados; `GET /v1/freshness`
   responde.
6. Abrir a UI HTMX no navegador — catálogo e histórico renderizam.
7. Forçar o worker de freshness e confirmar `is_stale` + disparo de alerta
   (e-mail/Telegram de teste).
8. `uv run pytest` — testes de API (com `httpx.ASGITransport`), RLS (um tenant
   não enxerga dados de outro), workers e auth.

---

## 11. Decisões e pontos em aberto

| Tema | Decisão / pendência |
|---|---|
| Stack | **FastAPI + HTMX** (usuário) |
| Hospedagem | **Self-hosted**, Docker Compose (usuário) |
| Billing | **Adiado** — beta gratuito por convite (usuário) |
| Infra FastAPI | Preencher `quantilica-web.fastapi` desde o M0 (usuário) |
| Migrations | **Alembic** — desvio consciente do SQL-cru dos apps `-db`, justificado para um SaaS |
| Fila async | **ARQ** (idiomático com async; vs. Celery dos apps Flask) |
| ORM | SQLAlchemy 2.0 async + asyncpg |
| Em aberto | Provedor de e-mail (Resend vs. Brevo); CSS (Bootstrap 5 vs. Tailwind); detalhe do algoritmo de anomalia; política exata de RLS |
