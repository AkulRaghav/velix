# Velix Local Dev Stack

Brings up the stateful dependencies the six gRPC services need, for local
development and integration testing.

## Start

```sh
docker compose -f infra/dev/docker-compose.yml up -d
```

This starts:

| Service  | Port | Purpose |
|----------|------|---------|
| Postgres | 5432 | One database per service (`velix_routing`, `velix_identity`, …) |
| NATS     | 4222 | JetStream event bus (monitoring on 8222) |
| Redis    | 6379 | Typing / presence TTL |

Dev credentials are `velix` / `velix`. Production secrets come from Vault.

## Apply migrations

Requires [goose](https://github.com/pressly/goose):

```sh
go install github.com/pressly/goose/v3/cmd/goose@latest
./infra/dev/migrate.sh          # apply all service migrations
./infra/dev/migrate.sh down     # roll back one step per service
```

## Run a service against the stack

```sh
cd backend/services/routing
VELIX_DSN="postgres://velix:velix@localhost:5432/velix_routing?sslmode=disable" \
VELIX_NATS_URL="nats://localhost:4222" \
VELIX_REDIS_ADDR="localhost:6379" \
GOWORK=off go run ./cmd/routing-server
```

## Run integration tests

Integration tests are gated behind the `integration` build tag and a
`VELIX_TEST_DSN` pointing at a migrated database. They are skipped in the
normal `go test` run and exercised by the `integration` CI job.

```sh
cd backend/services/routing
VELIX_TEST_DSN="postgres://velix:velix@localhost:5432/velix_routing?sslmode=disable" \
GOWORK=off go test -tags=integration ./...
```

## Tear down

```sh
docker compose -f infra/dev/docker-compose.yml down        # keep data
docker compose -f infra/dev/docker-compose.yml down -v     # wipe data
```

## Native (no-Docker) local stack — Windows

If Docker isn't available, the same stack runs from native installs:

```powershell
winget install -e --id PostgreSQL.PostgreSQL.16
winget install -e --id NATSAuthors.NATSServer
go install github.com/pressly/goose/v3/cmd/goose@latest
```

Postgres registers a Windows service on :5432 (superuser `postgres`). Create
the velix role + per-service databases, then migrate:

```powershell
# create role + databases (run each CREATE DATABASE as its own statement)
psql -U postgres -h localhost -c "CREATE ROLE velix LOGIN PASSWORD 'velix';"
foreach ($db in 'velix_routing','velix_identity','velix_media','velix_push','velix_call','velix_notifier') {
  psql -U postgres -h localhost -c "CREATE DATABASE $db OWNER velix;"
}

# migrate (use the key/value DSN form to avoid URL parsing issues)
$env:GOOSE_DRIVER = 'postgres'
foreach ($svc in 'routing','identity','media','push','call','notifier') {
  $env:GOOSE_DBSTRING = "host=localhost port=5432 user=velix password=velix dbname=velix_$svc sslmode=disable"
  goose -dir "backend/services/$svc/migrations" up
}

# start NATS with JetStream
nats-server -js -p 4222 -m 8222
```

Then run the integration tests (verified passing against Postgres 16):

```powershell
foreach ($svc in 'routing','identity','media','push','call','notifier') {
  $env:VELIX_TEST_DSN = "postgres://velix:velix@localhost:5432/velix_$svc`?sslmode=disable"
  Push-Location "backend/services/$svc"; $env:GOWORK='off'; go test -tags=integration ./...; Pop-Location
}
```
