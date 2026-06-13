# Redis high memory

## Symptoms
Alert `RedisHighMemory`. > 85% of max.

## Mitigations
1. Inspect top keys: `redis-cli --bigkeys`.
2. If presence/typing TTLs misconfigured (TTL not set), patch the writer.
3. Bump memory once if growth is genuine; investigate if doubling.

## Banned
- Disabling eviction. Velix Redis has a maxmemory-policy of `volatile-lru`;
  do not change to `noeviction`.
