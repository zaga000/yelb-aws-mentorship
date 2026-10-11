# yelb — Service Reference

This document describes the components of the `yelb` application as vendored into `app/`, what each one needs at runtime, and the known issues we plan to address while building our own container images (Phase 6).

**Upstream source:** https://github.com/mreferre/yelb, commit `55ee1b8` (2025-01-23). The upstream project is effectively unmaintained, so we vendor the code rather than track it.

---

## 1. Services overview

| Service | Role | Port | Upstream base image / runtime | Depends on |
|---|---|---|---|---|
| `yelb-ui` | Angular SPA served by nginx; reverse-proxies `/api` to the appserver | 80 | Build: `node:12.22`, Angular CLI 6.0.0, Angular 4. Runtime: `nginx:1.17.10` | `yelb-appserver` |
| `yelb-appserver` | Ruby / Sinatra REST API | 4567 | `bitnami/ruby:2.7.4` | `redis-server`, `yelb-db` |
| `redis-server` | Page-view counter cache | 6379 | `redis` (we currently run `redis:4.0.2`) | — |
| `yelb-db` | PostgreSQL, stores restaurant votes | 5432 | `postgres:10.21` locally; **RDS PostgreSQL** in AWS | — |

Only `yelb-ui` and `yelb-appserver` are built and pushed to ECR. Redis uses the official image, and the database is RDS in AWS (the `yelb-db` image is only needed for local `docker compose`).

---

## 2. Configuration (environment variables)

### yelb-ui

| Variable | Default | Purpose |
|---|---|---|
| `UI_ENV` | `prod` (set in Dockerfile) | Selects which Angular build nginx serves: `prod`, `test` or `dev`. |
| `YELB_APPSERVER_ENDPOINT` | `http://yelb-appserver:4567` | Target of the nginx `location /api` reverse proxy. Injected into the nginx config by `startup.sh` at container start. |
| `SEARCH_DOMAIN` | unset | If set, `startup.sh` appends `search <value>` to `/etc/resolv.conf`, so short hostnames like `yelb-appserver` are expanded to FQDNs (e.g. `yelb-appserver.yelb.local`). Intended for ECS + Cloud Map. **Not needed on EC2.** |

### yelb-appserver

Configuration is selected by **`RACK_ENV`**, which Sinatra reads implicitly (it does not appear in the code as `ENV[...]`).

| `RACK_ENV` | Redis host | Postgres host |
|---|---|---|
| `production` (Dockerfile default) | hard-coded `redis-server` | hard-coded `yelb-db` |
| `test` | hard-coded `redis-server` | hard-coded `yelb-db` |
| `development` | `localhost` | `localhost` |
| `custom` | `REDIS_SERVER_ENDPOINT` | `YELB_DB_SERVER_ENDPOINT` |

| Variable | Used when | Purpose |
|---|---|---|
| `RACK_ENV` | always | Selects the configuration block above. |
| `REDIS_SERVER_ENDPOINT` | `RACK_ENV=custom` | Redis hostname (port is fixed at 6379). |
| `YELB_DB_SERVER_ENDPOINT` | `RACK_ENV=custom` | Postgres hostname (port is fixed at 5432). |
| `SEARCH_DOMAIN` | optional | Same behaviour as in `yelb-ui` (`startup.sh` appends a DNS search domain). |
| `YELB_DDB_RESTAURANTS`, `YELB_DDB_CACHE`, `AWS_REGION` | serverless variant only | DynamoDB backend instead of Postgres/Redis. **Not used in this project.** |

The `*_adapter.rb` files and their lowercase variables (`yelbdbhost`, `redishost`, etc.) are AWS Lambda wrappers for the serverless variant and are **not used** when running in a container.

### Database credentials

Credentials are **hard-coded** in `modules/restaurantsdbread.rb` and `modules/restaurantsdbupdate.rb`:

- user: `postgres`
- password: `postgres_password`
- database: `yelbdatabase`
- port: `5432`

See section 6 (Known issues).

---

## 3. API endpoints (`yelb-appserver`)

All endpoints are **GET**, including the ones that modify data.

| Endpoint | Action | Side effect | Depends on |
|---|---|---|---|
| `/api/pageviews` | Returns the page-view count | **Increments** the Redis counter | Redis |
| `/api/hostname` | Returns the container/host name | none | nothing |
| `/api/getstats` | Returns hostname + page-view count | none | Redis |
| `/api/getvotes` | Returns the vote count for all restaurants | none | Postgres |
| `/api/ihop` | Votes for ihop | **+1 vote** | Postgres |
| `/api/chipotle` | Votes for chipotle | **+1 vote** | Postgres |
| `/api/outback` | Votes for outback | **+1 vote** | Postgres |
| `/api/bucadibeppo` | Votes for bucadibeppo | **+1 vote** | Postgres |

Implications:

- **Load testing:** votes must be sent as `GET` requests, not `POST`.
- **Health checks:** never point a health check at a vote endpoint or `/api/pageviews` — every probe would change data.
- `/api/hostname` is handy for seeing which instance/task served a request (useful to confirm load balancing during Locust runs).

---

## 4. How the components find each other

| Platform | UI → appserver | appserver → Redis | appserver → Postgres |
|---|---|---|---|
| **EC2 (Phase 2, upstream images)** | `--link yelb-appserver:yelb-appserver` writes an `/etc/hosts` entry | `--link redis-server:redis-server` | `--add-host=yelb-db:$RDS_IP` maps the hard-coded name `yelb-db` to the RDS IP |
| **Local `docker compose`** | Compose service-name DNS (`yelb-appserver`) | service name `redis-server` | service name `yelb-db` |
| **ECS (Phase 7, planned)** | Cloud Map (`yelb-appserver.yelb.local`) via `SEARCH_DOMAIN` or `YELB_APPSERVER_ENDPOINT` | Cloud Map (`redis-server.yelb.local`) | RDS endpoint via `YELB_DB_SERVER_ENDPOINT` (`RACK_ENV=custom`) |

Notes:

- On EC2 the containers start in order simply because user data runs `docker run` sequentially. There is no readiness check between them.
- `SEARCH_DOMAIN=yelb-appserver` in the current EC2 user data has no useful effect (it would expand names to `*.yelb-appserver`); name resolution works because `/etc/hosts` is checked before DNS. It can be removed.
- `--link` is a legacy Docker feature; user-defined networks (as in Compose) are the modern equivalent.

---

## 5. Database schema

Table `restaurants` in database `yelbdatabase`:

| Column | Type | Notes |
|---|---|---|
| `name` | `varchar(30)` (upstream: `char(30)`) | Primary key |
| `count` | `integer` | Vote count |

Seed rows: `outback`, `bucadibeppo`, `chipotle`, `ihop`, each with `count = 0`.

| | Upstream (`yelb-db/init-yelb-db.sh`) | Our EC2 user data |
|---|---|---|
| When it runs | Once, on first start with an empty data directory (`docker-entrypoint-initdb.d`) | On **every** EC2 instance boot |
| Idempotent? | Not needed | Yes — `CREATE TABLE IF NOT EXISTS` and `ON CONFLICT (name) DO NOTHING`, so re-runs neither fail nor reset votes |

`char(30)` pads values with spaces; `varchar(30)` does not. Either works for this app.

---

## 6. Known issues and planned changes

| # | Issue | Why it matters | Planned fix (phase) |
|---|---|---|---|
| 1 | DB credentials hard-coded in Ruby code | Password lives in git and in every image; cannot rotate without a rebuild; Dev and Prod share one password | Read `YELB_DB_USER` / `YELB_DB_PASSWORD` (and DB name) from env. Source them from SSM Parameter Store on EC2 and from task-definition `secrets` on ECS (6.2) |
| 2 | DB password passed in plain text through user data | Visible in the Launch Template and instance metadata | Fetch from SSM Parameter Store (SecureString) at boot |
| 3 | Appserver hosts hard-coded under `RACK_ENV=production` | Forces `/etc/hosts` tricks on EC2 | Use `RACK_ENV=custom` with explicit endpoints (6.2) |
| 4 | No OpenTelemetry instrumentation | ADOT collector runs but receives no spans from the appserver | Add OTel SDK + Sinatra/pg/redis instrumentation (6.2) |
| 5 | Very old runtimes: Ruby 2.7 (EOL), Node 12 (EOL), Angular 4, nginx 1.17, Postgres 10 | Security exposure; old base images may no longer be pullable (the Bitnami public catalogue was restructured in 2025 — verify `bitnami/ruby:2.7.4` still pulls) | Choose maintained base images where possible; pin the old Node only for the UI build stage (6.2, 6.3) |
| 6 | Appserver Dockerfile includes Lambda adapter / RIE / RIC | Unused weight and attack surface for our container use | Remove in our Dockerfile (6.2) |
| 7 | UI build clones `vmware/clarity-seed` from GitHub at build time; `git checkout -b <sha>` creates a branch **named** after the SHA instead of checking out that commit | Build is not reproducible and depends on an external repo's current HEAD | Use `git checkout <sha>` (or vendor the seed) (6.3) |
| 8 | All write operations are GET | Unsafe for caching/probing | Accept as-is; document and avoid in health checks / tests |
| 9 | Schema initialisation runs from app-instance user data | There is no user data for app containers on ECS | Decide on an approach before Phase 7 (see open questions) |

---

## 7. Open questions

- **Appserver health check (Phase 7):** which endpoint should the ECS service / target group use, and why? Consider the trade-off between "the process is up" and "the process can reach its dependencies".
- **Schema initialisation on ECS:** who creates the table and seed rows when there is no EC2 user data? (Options to evaluate: a one-off ECS task, an init container, Terraform, or app-side migration on startup.)
- **ECR layout:** repositories in each account (Dev and Prod), or one registry with cross-account pull?