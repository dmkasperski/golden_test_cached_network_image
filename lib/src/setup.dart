import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:golden_test/golden_test.dart';
import 'package:golden_test_cached_network_image/src/cache_manager.dart';

/// Registers [GoldenTestCacheManager] so [CachedNetworkImage] works in golden
/// tests.
///
/// Call this once in `flutter_test_config.dart`:
/// ```dart
/// import 'package:golden_test_cached_network_image/golden_test_cached_network_image.dart';
///
/// Future<void> testExecutable(FutureOr<void> Function() testMain) async {
///   ...
///   setupGoldenTestCachedNetworkImage();
///   return testMain();
/// }
/// ```
///
/// Pass [cacheManagerBuilder] to substitute your own manager — to serve
/// different bytes per URL, to assert on what was requested, or to wrap a
/// project-specific subclass:
/// ```dart
/// setupGoldenTestCachedNetworkImage(
///   cacheManagerBuilder: () => MyGoldenCacheManager(),
/// );
/// ```
///
/// It is a builder rather than an instance because it is invoked once per test:
/// returning a fresh manager each time keeps cache state from leaking between
/// tests. Whatever it returns must avoid SQLite and `path_provider` — that is
/// the whole reason the default exists.
///
/// This sets [CachedNetworkImageProvider.defaultCacheManager], so it applies to
/// widgets that use the default. A `CachedNetworkImage` constructed with an
/// explicit `cacheManager:` keeps the one it was given and behaves as it would
/// without this package — hanging the test if that manager is the real one.
/// Pass your test manager to those widgets yourself.
void setupGoldenTestCachedNetworkImage({
  BaseCacheManager Function()? cacheManagerBuilder,
}) {
  final buildCacheManager = cacheManagerBuilder ?? GoldenTestCacheManager.new;
  goldenTestImageLoaderSetups.add(() {
    CachedNetworkImageProvider.defaultCacheManager = buildCacheManager();
  });
}
