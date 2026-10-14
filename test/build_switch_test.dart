// The build hook compiles Box2D unless the app's pubspec says
// `hooks: user_defines: just_box_2d: build: false`. (That it builds when the
// app says nothing is loader_test.dart's business: this package's pubspec
// says nothing, and the library is there.)

@TestOn('vm')
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

import '../hook/build.dart' as hook;

Future<List<EncodedAsset>> _assets(Map<String, Object?> defines) async {
  late List<EncodedAsset> assets;
  await testCodeBuildHook(
    mainMethod: hook.main,
    userDefines: PackageUserDefines(
      workspacePubspec: PackageUserDefinesSource(
        defines: defines,
        basePath: Directory.current.uri,
      ),
    ),
    check: (input, output) => assets = output.assets.encodedAssets,
  );
  return assets;
}

void main() {
  test('nothing is built when the app says build: false', () async {
    expect(await _assets({'build': false}), isEmpty);
  });
}
