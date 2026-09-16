# golden_test_cached_network_image

`CachedNetworkImage` support for [`golden_test`](https://pub.dev/packages/golden_test).

## The problem

`CachedNetworkImage` doesn't paint through `NetworkImage`. It fetches through `flutter_cache_manager`, whose persistence layer needs SQLite and `path_provider`, and neither works inside Flutter's fake-async test zone.

The result isn't a failure you can read. A `CachedNetworkImage` in a golden test **hangs** — the run stalls until it times out as `did not complete`, with nothing in the output naming the widget, the URL, or the cache.

## The fix

This package swaps in a cache manager that keeps every file in memory, so reads complete as a microtask and settle inside the normal `pumpAndSettle` loop. It serves the same placeholder [`golden_test`](https://pub.dev/packages/golden_test) uses for `Image.network`, so every image in a golden renders identically regardless of which widget loaded it.

It ships separately from `golden_test` because the fix requires depending on `cached_network_image` and `flutter_cache_manager`. Keeping it here means projects that don't use `CachedNetworkImage` never resolve either.

## Setup

```yaml
dev_dependencies:
  golden_test: ^2.0.0
  golden_test_cached_network_image: ^1.0.0
```

```dart
// test/flutter_test_config.dart
import 'dart:async';

import 'package:golden_test_cached_network_image/golden_test_cached_network_image.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // ... your other golden_test configuration ...
  setupGoldenTestCachedNetworkImage();
  return testMain();
}
```

That's it. Every `CachedNetworkImage` in a golden test now resolves to the same placeholder `golden_test` serves for `Image.network`, so both render identically.

## Custom cache manager

Pass a builder to substitute your own manager — to serve different bytes per URL, to assert on what was requested, or to wrap a project-specific subclass:

```dart
setupGoldenTestCachedNetworkImage(
  cacheManagerBuilder: () => MyGoldenCacheManager(),
);
```

It's a builder rather than an instance because it runs once per test, so each test gets a fresh manager and cache state can't leak between them. Whatever it returns must avoid SQLite and `path_provider` — that's the whole reason the default exists.

## What the default manager does

`GoldenTestCacheManager` keeps every "file" in an in-memory filesystem, so reads complete as a microtask and settle inside the normal `pumpAndSettle` loop.

- Entries are addressed by **cache key**, so `CachedNetworkImage(cacheKey: ...)` works and `FileInfo.originalUrl` still reports the URL. Without an explicit key the URL doubles as the key, as in the real cache manager.
- `getFileStream` emits a single `FileInfo` and never a `DownloadProgress`, so `progressIndicatorBuilder` never runs — progress fractions would make goldens depend on download timing. Use `placeholder` to golden the pre-load state.
- The bytes come from `goldenTestNetworkImageStubPng`, so overriding that in `golden_test` changes this package's output too.

## Caveat

`setupGoldenTestCachedNetworkImage` sets `CachedNetworkImageProvider.defaultCacheManager`, so it reaches widgets that use the default. A `CachedNetworkImage` built with an explicit `cacheManager:` keeps the one you gave it, and behaves as it would without this package — including hanging the test if that manager is the real one. Pass your test manager to those widgets too.

## License

BSD 3-Clause.
