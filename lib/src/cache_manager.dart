import 'package:file/file.dart' as f;
import 'package:file/memory.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:golden_test/golden_test.dart';

/// A [BaseCacheManager] for golden tests that serves
/// [goldenTestNetworkImageStubPng] without any SQLite or platform-channel
/// dependencies.
///
/// `flutter_cache_manager`'s default [CacheManager] uses SQLite for
/// persistence. SQLite relies on Flutter platform channels which do not
/// function inside Flutter's fake-async test zone, causing golden tests with
/// `CachedNetworkImage` to hang indefinitely on the loading state. This stub
/// bypasses the persistence layer entirely — all "files" live in a
/// [MemoryFileSystem] so every read completes as a microtask and works within
/// the normal `pumpAndSettle` loop.
///
/// Entries are addressed by *cache key*, matching [BaseCacheManager]'s own
/// contract: `CachedNetworkImage(imageUrl: ..., cacheKey: ...)` stores and
/// reads under the explicit key while [FileInfo.originalUrl] still reports the
/// URL. When no key is given the URL doubles as the key, as in the real cache
/// manager.
///
/// [getFileStream] emits a single [FileInfo] and never a [DownloadProgress], so
/// `CachedNetworkImage`'s `progressIndicatorBuilder` never runs. That is
/// intentional: progress fractions would make goldens depend on download
/// timing. Use `placeholder` instead to golden the pre-load state.
class GoldenTestCacheManager implements BaseCacheManager {
  final _memFs = MemoryFileSystem();

  /// Cache key -> in-memory file holding [goldenTestNetworkImageStubPng].
  final _files = <String, f.File>{};

  /// Cache key -> the URL it was originally requested for.
  final _urls = <String, String>{};

  static final _validTill = DateTime.utc(2100);

  FileInfo _store(String cacheKey, String url) {
    final file = _files.putIfAbsent(cacheKey, () {
      final file = _memFs.file('/${cacheKey.hashCode}.png');
      file.writeAsBytesSync(goldenTestNetworkImageStubPng);
      return file;
    });
    _urls[cacheKey] = url;
    return FileInfo(file, FileSource.Online, _validTill, url);
  }

  FileInfo? _lookup(String cacheKey) {
    final file = _files[cacheKey];
    if (file == null) return null;
    return FileInfo(
      file,
      FileSource.Online,
      _validTill,
      _urls[cacheKey] ?? cacheKey,
    );
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    yield _store(key ?? url, url);
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async => _store(key ?? url, url);

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) async => _lookup(key);

  @override
  Future<FileInfo?> getFileFromMemory(String key) async => _lookup(key);

  @override
  Future<void> removeFile(String key) async {
    _files.remove(key);
    _urls.remove(key);
  }

  @override
  Future<void> emptyCache() async {
    _files.clear();
    _urls.clear();
  }

  @override
  Future<void> dispose() async {}

  /// Fails loudly and by name for the [BaseCacheManager] members the stub does
  /// not implement, rather than surfacing a bare [NoSuchMethodError] from
  /// inside the package.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final symbol = invocation.memberName.toString();
    final name = RegExp(r'"(.*)"').firstMatch(symbol)?.group(1) ?? symbol;
    throw UnsupportedError(
      'GoldenTestCacheManager does not implement BaseCacheManager.$name. It '
      'covers the calls CachedNetworkImage makes during golden tests; pass '
      'cacheManagerBuilder to setupGoldenTestCachedNetworkImage if you need '
      'more.',
    );
  }
}
