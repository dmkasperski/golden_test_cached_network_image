import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_test/golden_test.dart';
import 'package:golden_test_cached_network_image/golden_test_cached_network_image.dart';

const _url = 'https://example.com/avatar.png';
const _otherUrl = 'https://example.com/banner.png';

void main() {
  final defaultStubPng = goldenTestNetworkImageStubPng;

  late GoldenTestCacheManager manager;

  setUp(() {
    manager = GoldenTestCacheManager();
    goldenTestImageLoaderSetups.clear();
    goldenTestNetworkImageStubPng = defaultStubPng;
  });

  group('GoldenTestCacheManager', () {
    test('getFileStream serves the stub bytes', () async {
      final response = await manager.getFileStream(_url).first;

      expect(response, isA<FileInfo>());
      final info = response as FileInfo;
      expect(info.originalUrl, _url);
      expect(info.file.readAsBytesSync(), goldenTestNetworkImageStubPng);
    });

    test('getFileStream emits one FileInfo and no DownloadProgress', () async {
      final responses = await manager
          .getFileStream(_url, withProgress: true)
          .toList();

      expect(responses, hasLength(1));
      expect(responses.single, isA<FileInfo>());
    });

    test('serves an overridden stub image', () async {
      goldenTestNetworkImageStubPng = Uint8List.fromList([9, 8, 7]);

      final info = await manager.getFileStream(_url).first as FileInfo;
      expect(info.file.readAsBytesSync(), [9, 8, 7]);
    });

    test('the url doubles as the cache key when none is given', () async {
      await manager.getFileStream(_url).first;

      expect(await manager.getFileFromCache(_url), isNotNull);
      expect(await manager.getFileFromMemory(_url), isNotNull);
    });

    test(
      'stores under the cache key, not the url, when a key is given',
      () async {
        await manager.getFileStream(_url, key: 'avatar-1').first;

        final byKey = await manager.getFileFromCache('avatar-1');
        expect(byKey, isNotNull);
        expect(
          byKey!.originalUrl,
          _url,
          reason: 'FileInfo should still report the url it was fetched for',
        );

        expect(
          await manager.getFileFromCache(_url),
          isNull,
          reason: 'the url is not the cache key once an explicit key is used',
        );
      },
    );

    test(
      'getFileFromCache and getFileFromMemory return null for unknown keys',
      () async {
        expect(await manager.getFileFromCache('never-fetched'), isNull);
        expect(await manager.getFileFromMemory('never-fetched'), isNull);
      },
    );

    test('downloadFile honours the cache key', () async {
      final info = await manager.downloadFile(_url, key: 'avatar-1');

      expect(info.originalUrl, _url);
      expect(info.file.readAsBytesSync(), goldenTestNetworkImageStubPng);
      expect(await manager.getFileFromCache('avatar-1'), isNotNull);
    });

    test('distinct keys get distinct backing files', () async {
      final first = await manager.downloadFile(_url, key: 'a');
      final second = await manager.downloadFile(_otherUrl, key: 'b');

      expect(first.file.path, isNot(second.file.path));
      expect(second.originalUrl, _otherUrl);
    });

    test('repeated requests reuse the same backing file', () async {
      final first = await manager.downloadFile(_url);
      final second = await manager.downloadFile(_url);

      expect(first.file.path, second.file.path);
    });

    test('removeFile drops a single entry by key', () async {
      await manager.getFileStream(_url, key: 'a').first;
      await manager.getFileStream(_otherUrl, key: 'b').first;

      await manager.removeFile('a');

      expect(await manager.getFileFromCache('a'), isNull);
      expect(await manager.getFileFromCache('b'), isNotNull);
    });

    test('emptyCache drops every entry', () async {
      await manager.getFileStream(_url, key: 'a').first;
      await manager.getFileStream(_otherUrl, key: 'b').first;

      await manager.emptyCache();

      expect(await manager.getFileFromCache('a'), isNull);
      expect(await manager.getFileFromCache('b'), isNull);
    });

    test('unimplemented members fail by name', () {
      expect(
        () => manager.getSingleFile(_url),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('BaseCacheManager.getSingleFile'),
              contains('cacheManagerBuilder'),
            ),
          ),
        ),
      );
    });
  });

  group('setupGoldenTestCachedNetworkImage', () {
    test('registers a golden_test image loader setup', () {
      expect(goldenTestImageLoaderSetups, isEmpty);

      setupGoldenTestCachedNetworkImage();
      expect(goldenTestImageLoaderSetups, hasLength(1));

      // Note the field is only ever *written* before being read: reading
      // CachedNetworkImageProvider.defaultCacheManager first would lazily
      // construct DefaultCacheManager and its path_provider + SQLite init.
      goldenTestImageLoaderSetups.single();
      expect(
        CachedNetworkImageProvider.defaultCacheManager,
        isA<GoldenTestCacheManager>(),
      );
    });

    test('installs a custom manager when cacheManagerBuilder is given', () {
      setupGoldenTestCachedNetworkImage(
        cacheManagerBuilder: _RecordingCacheManager.new,
      );

      goldenTestImageLoaderSetups.single();
      expect(
        CachedNetworkImageProvider.defaultCacheManager,
        isA<_RecordingCacheManager>(),
      );
    });

    test('builds a fresh manager per test, so cache state cannot leak', () {
      var builds = 0;
      setupGoldenTestCachedNetworkImage(
        cacheManagerBuilder: () {
          builds++;
          return _RecordingCacheManager();
        },
      );

      expect(builds, 0, reason: 'nothing is built until a test starts');

      goldenTestImageLoaderSetups.single();
      final first = CachedNetworkImageProvider.defaultCacheManager;
      goldenTestImageLoaderSetups.single();

      expect(builds, 2);
      expect(
        CachedNetworkImageProvider.defaultCacheManager,
        isNot(same(first)),
      );
    });

    test('does not clobber setups registered by other packages', () {
      var otherRan = false;
      goldenTestImageLoaderSetups.add(() => otherRan = true);

      setupGoldenTestCachedNetworkImage();
      expect(goldenTestImageLoaderSetups, hasLength(2));

      for (final setup in goldenTestImageLoaderSetups) {
        setup();
      }

      expect(otherRan, isTrue);
      expect(
        CachedNetworkImageProvider.defaultCacheManager,
        isA<GoldenTestCacheManager>(),
      );
    });
  });
}

/// A stand-in for a project's own test cache manager, to prove
/// [setupGoldenTestCachedNetworkImage] installs whatever it is handed.
class _RecordingCacheManager extends GoldenTestCacheManager {}
