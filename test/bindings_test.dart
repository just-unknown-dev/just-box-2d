// The bindings match the C layer: every function the header exports is bound
// and defined. A header change without regenerating the bindings
// (`dart run ffigen --config ffigen.yaml`) fails here.

@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

Set<String> _names(String path, RegExp pattern) => {
  for (final m in pattern.allMatches(File(path).readAsStringSync()))
    m.group(1)!,
};

void main() {
  test('the header, the C++ and the bindings name the same functions', () {
    final header = _names(
      'src/b2w/box2d_wrapper.h',
      RegExp(r'B2W_EXPORT\s+[\w\s*]+?\b(b2w_\w+)\s*\('),
    );
    final cpp = _names(
      'src/b2w/box2d_wrapper.cpp',
      RegExp(r'extern "C"\s+[\w\s*]+?\b(b2w_\w+)\s*\('),
    );
    final bindings = _names(
      'lib/src/native/bindings.g.dart',
      RegExp(r'external\s+[\w<>.\s]+?\b(b2w_\w+)\s*\('),
    );
    expect(header.length, greaterThan(70));
    expect(bindings, header);
    expect(cpp, header);
  });
}
