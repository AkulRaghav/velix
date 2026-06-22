/// Simple key-value cache with TTL expiration.
/// Used for caching API responses and reducing redundant network calls.
class MemoryCache<T> {
  MemoryCache({this.defaultTtl = const Duration(minutes: 5)});

  final Duration defaultTtl;
  final Map<String, _CacheEntry<T>> _store = {};

  /// Get a cached value, or null if expired/missing.
  T? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _store.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Store a value with optional custom TTL.
  void set(String key, T value, {Duration? ttl}) {
    _store[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Remove a specific key.
  void invalidate(String key) => _store.remove(key);

  /// Clear all cached entries.
  void clear() => _store.clear();

  /// Number of currently cached (non-expired) entries.
  int get size {
    _store.removeWhere((_, e) => DateTime.now().isAfter(e.expiresAt));
    return _store.length;
  }
}

class _CacheEntry<T> {
  _CacheEntry({required this.value, required this.expiresAt});
  final T value;
  final DateTime expiresAt;
}
