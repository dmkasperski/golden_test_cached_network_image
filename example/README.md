# Example

`golden_test_cached_network_image` is wired up once, in `test/flutter_test_config.dart`,
and then every golden test in the project picks it up automatically.

```dart
// test/flutter_test_config.dart
import 'dart:async';

import 'package:golden_test/golden_test.dart';
import 'package:golden_test_cached_network_image/golden_test_cached_network_image.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenTestSupportedLocales = [const Locale('en')];

  setupGoldenTestCachedNetworkImage();

  return testMain();
}
```

Golden tests then use `CachedNetworkImage` with no further setup — it resolves
to the same placeholder `golden_test` serves for `Image.network`:

```dart
// test/avatar_test.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:golden_test/golden_test.dart';

void main() {
  goldenTest(
    name: 'Avatar',
    builder: (_) => Scaffold(
      body: Center(
        child: CachedNetworkImage(
          imageUrl: 'https://example.com/avatar.png',
          width: 80,
          height: 80,
        ),
      ),
    ),
  );
}
```

To substitute your own cache manager — to serve different bytes per URL, or to
assert on what was requested — pass a builder:

```dart
setupGoldenTestCachedNetworkImage(
  cacheManagerBuilder: () => MyGoldenCacheManager(),
);
```

A runnable version of this setup lives in the `example/` app of the
[`golden_test`](https://github.com/dmkasperski/golden_test) repository, whose
golden tests cover `Image.network`, `FadeInImage`, `DecorationImage` and
`CachedNetworkImage` side by side.
