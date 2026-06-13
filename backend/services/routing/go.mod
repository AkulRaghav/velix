module github.com/velix/backend/services/routing

go 1.26.3

require (
	github.com/jackc/pgx/v5 v5.10.0
	github.com/nats-io/nats.go v1.39.1
	github.com/oklog/ulid/v2 v2.1.0
	github.com/redis/go-redis/v9 v9.7.0
	github.com/velix/backend/pkg/velixhealth v0.0.0
	github.com/velix/backend/proto/gen/go v0.0.0
	google.golang.org/grpc v1.81.1
	google.golang.org/protobuf v1.36.11
)

require (
	github.com/cespare/xxhash/v2 v2.3.0 // indirect
	github.com/dgryski/go-rendezvous v0.0.0-20200823014737-9f7001d12a5f // indirect
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	github.com/klauspost/compress v1.17.9 // indirect
	github.com/nats-io/nkeys v0.4.9 // indirect
	github.com/nats-io/nuid v1.0.1 // indirect
	golang.org/x/crypto v0.48.0 // indirect
	golang.org/x/net v0.51.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.42.0 // indirect
	golang.org/x/text v0.34.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260226221140-a57be14db171 // indirect
)

replace github.com/velix/backend/proto/gen/go => ../../proto/gen/go

replace github.com/velix/backend/pkg/velixhealth => ../../pkg/velixhealth
