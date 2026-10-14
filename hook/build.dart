import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Builds Box2D and just_box_2d's C layer in two stages.
///
/// 1. `box2d_core`, a static library of Box2D's C sources (`src/box2d/src/`).
///    It is linked into stage 2 and never bundled.
/// 2. `just_box_2d`, the bundled dynamic library: the C layer in `src/b2w/`
///    (`box2d_wrapper.cpp`, `thread_pool.cpp`) with Box2D linked in.
///
/// It builds unless the app's pubspec turns it off — a web-only game, or one
/// that runs a pure-Dart engine everywhere, then compiles no C:
///
/// ```yaml
/// hooks:
///   user_defines:
///     just_box_2d:
///       build: false
/// ```
///
/// Without the library, `Box2D.unavailableReason` says why.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    if (input.userDefines['build'] == false) return;
    final targetOS = input.config.code.targetOS;

    final root = input.packageRoot;
    final box2d = root.resolve('src/box2d/');
    final layer = root.resolve('src/b2w/');
    final sources =
        Directory.fromUri(box2d.resolve('src/'))
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.c'))
            .map((f) => f.path)
            .toList()
          ..sort();
    final includes = [
      layer.toFilePath(),
      box2d.resolve('include/').toFilePath(),
    ];
    final flags = [
      '-O2',
      // Only the C layer's functions (B2W_EXPORT) leave the library; Box2D's
      // own stay inside, so they never clash with another library's copy.
      // (MSVC exports only what is marked dllexport already.)
      if (targetOS != OS.windows) '-fvisibility=hidden',
      if (targetOS == OS.android) '-Wno-unused-command-line-argument',
    ];
    // The same for the C++ runtime Android links in statically, and for
    // anything else linked from an archive (GNU-style linkers only).
    final linkFlags = [
      if (targetOS == OS.android || targetOS == OS.linux)
        '-Wl,--exclude-libs,ALL',
    ];

    // Stage 1's own output is thrown away (the static library is only linked
    // into stage 2), so Box2D's files are named as dependencies of the real
    // output: a change to one of them rebuilds the bundled library.
    await CBuilder.library(
      name: 'box2d_core',
      assetName: 'box2d_core',
      sources: sources,
      includes: includes,
      flags: flags,
      std: 'c17',
      linkModePreference: LinkModePreference.static,
    ).run(input: input, output: BuildOutputBuilder());
    output.dependencies.addAll([
      for (final file in Directory.fromUri(box2d).listSync(recursive: true))
        if (file is File) file.uri,
    ]);

    await CBuilder.library(
      name: 'just_box_2d',
      assetName: 'just_box_2d',
      sources: [
        layer.resolve('thread_pool.cpp').toFilePath(),
        layer.resolve('box2d_wrapper.cpp').toFilePath(),
      ],
      includes: includes,
      libraries: [
        'box2d_core',
        // Box2D calls libm (atan2f, …). Android and Linux need it linked
        // explicitly, or the library fails to load ("cannot locate symbol
        // atan2f").
        if (targetOS == OS.android || targetOS == OS.linux) 'm',
      ],
      flags: [...flags, ...linkFlags],
      std: 'c++17',
      language: Language.cpp,
      cppLinkStdLib: targetOS == OS.android ? 'c++_static' : null,
    ).run(input: input, output: output);
  });
}
