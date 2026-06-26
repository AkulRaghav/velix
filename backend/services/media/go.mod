module github.com/velix/backend/services/media

go 1.25.0

require (
	github.com/oklog/ulid/v2 v2.1.0
	github.com/velix/backend/pkg/velixctx v0.0.0
	github.com/velix/backend/pkg/velixerr v0.0.0
	github.com/velix/backend/pkg/velixnats v0.0.0
	github.com/velix/backend/pkg/velixnatsjs v0.0.0
	github.com/velix/backend/pkg/velixobs v0.0.0
	github.com/velix/backend/pkg/velixobsslog v0.0.0
	github.com/velix/backend/pkg/velixsql v0.0.0
	github.com/velix/backend/pkg/velixsqlpgx v0.0.0
	github.com/velix/backend/proto/gen/go v0.0.0
	google.golang.org/grpc v1.81.1
	google.golang.org/protobuf v1.36.11
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/pgx/v5 v5.10.0
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	github.com/klauspost/compress v1.17.9 // indirect
	github.com/nats-io/nats.go v1.39.1 // indirect
	github.com/nats-io/nkeys v0.4.9 // indirect
	github.com/nats-io/nuid v1.0.1 // indirect
	github.com/velix/backend/pkg/velixauth v0.0.0 // indirect
	github.com/velix/backend/pkg/velixgrpcauth v0.0.0
	github.com/velix/backend/pkg/velixhealth v0.0.0
	github.com/velix/backend/pkg/velixtoken v0.0.0
	golang.org/x/crypto v0.48.0 // indirect
	golang.org/x/net v0.51.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.42.0 // indirect
	golang.org/x/text v0.34.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260226221140-a57be14db171 // indirect
)

replace (
	github.com/velix/backend/pkg/velixctx => ../../pkg/velixctx
	github.com/velix/backend/pkg/velixerr => ../../pkg/velixerr
	github.com/velix/backend/pkg/velixnats => ../../pkg/velixnats
	github.com/velix/backend/pkg/velixnatsjs => ../../pkg/velixnatsjs
	github.com/velix/backend/pkg/velixobs => ../../pkg/velixobs
	github.com/velix/backend/pkg/velixobsslog => ../../pkg/velixobsslog
	github.com/velix/backend/pkg/velixsql => ../../pkg/velixsql
	github.com/velix/backend/pkg/velixsqlpgx => ../../pkg/velixsqlpgx
	github.com/velix/backend/proto/gen/go => ../../proto/gen/go
)

replace github.com/velix/backend/pkg/velixhealth => ../../pkg/velixhealth

replace github.com/velix/backend/pkg/velixgrpcauth => ../../pkg/velixgrpcauth

replace github.com/velix/backend/pkg/velixtoken => ../../pkg/velixtoken

replace github.com/velix/backend/pkg/velixauth => ../../pkg/velixauth
