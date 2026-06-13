#!/usr/bin/env bash
# Applies each service's goose migrations against the local dev Postgres.
#
# Requires goose (https://github.com/pressly/goose):
#   go install github.com/pressly/goose/v3/cmd/goose@latest
#
# Usage:
#   ./infra/dev/migrate.sh          # apply all
#   ./infra/dev/migrate.sh down     # roll back one step per service
set -euo pipefail

HOST="${VELIX_PG_HOST:-localhost}"
PORT="${VELIX_PG_PORT:-5432}"
USER="${VELIX_PG_USER:-velix}"
PASS="${VELIX_PG_PASS:-velix}"
ACTION="${1:-up}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

declare -A DBS=(
  [routing]=velix_routing
  [identity]=velix_identity
  [media]=velix_media
  [push]=velix_push
  [call]=velix_call
  [notifier]=velix_notifier
)

for svc in "${!DBS[@]}"; do
  db="${DBS[$svc]}"
  dir="$REPO_ROOT/backend/services/$svc/migrations"
  dsn="postgres://$USER:$PASS@$HOST:$PORT/$db?sslmode=disable"
  echo ">> $svc ($db) :: goose $ACTION"
  goose -dir "$dir" postgres "$dsn" "$ACTION"
done

echo "migrations $ACTION complete"
