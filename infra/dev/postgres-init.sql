-- Creates one database per Velix service. Run automatically by the Postgres
-- container on first boot (docker-entrypoint-initdb.d).
CREATE DATABASE velix_routing;
CREATE DATABASE velix_identity;
CREATE DATABASE velix_media;
CREATE DATABASE velix_push;
CREATE DATABASE velix_call;
CREATE DATABASE velix_notifier;
