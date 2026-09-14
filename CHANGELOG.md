## 1.0.0

Initial release.

- `GoldenTestCacheManager` — an in-memory `BaseCacheManager` that serves the
  `golden_test` placeholder image, with no SQLite and no platform channels, so
  `CachedNetworkImage` resolves inside Flutter's fake-async test zone instead of
  hanging. Entries are addressed by cache key, so `CachedNetworkImage(cacheKey:)`
  works and `FileInfo.originalUrl` still reports the URL.
- `setupGoldenTestCachedNetworkImage()` — one call in `flutter_test_config.dart`
  installs the manager for every golden test.
- `cacheManagerBuilder` — optional hook to supply your own `BaseCacheManager`,
  built fresh per test so cache state can't leak between them.
