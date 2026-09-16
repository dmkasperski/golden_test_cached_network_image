/// `CachedNetworkImage` support for `golden_test`.
///
/// `golden_test` stubs `NetworkImage` on its own, which covers `Image.network`,
/// `FadeInImage`, and `DecorationImage`. `CachedNetworkImage` does not go
/// through `NetworkImage` — it fetches through `flutter_cache_manager`, whose
/// persistence layer needs SQLite and `path_provider`, neither of which work
/// inside Flutter's fake-async test zone.
///
/// This package lives separately so that `golden_test` itself stays free of
/// `cached_network_image` and `flutter_cache_manager`: projects that don't use
/// `CachedNetworkImage` never resolve them.
library;

export 'src/cache_manager.dart';
export 'src/setup.dart';
