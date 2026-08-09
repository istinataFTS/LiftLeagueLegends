// test/core/themes/lift_fonts_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('pubspec declares both font families with weights 400/500/700', () {
    final YamlMap pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    final YamlList fonts = pubspec['flutter']['fonts'] as YamlList;

    final Map<String, List<int>> weightsByFamily = <String, List<int>>{
      for (final dynamic entry in fonts)
        entry['family'] as String: <int>[
          for (final dynamic f in entry['fonts'] as YamlList)
            f['weight'] as int,
        ],
    };

    expect(weightsByFamily['SpaceGrotesk'], <int>[400, 500, 700]);
    expect(weightsByFamily['JetBrainsMono'], <int>[400, 500, 700]);
  });

  test('every declared font asset exists on disk', () {
    final YamlMap pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
    for (final dynamic family in pubspec['flutter']['fonts'] as YamlList) {
      for (final dynamic font in family['fonts'] as YamlList) {
        expect(
          File(font['asset'] as String).existsSync(),
          isTrue,
          reason: 'missing ${font['asset']}',
        );
      }
    }
  });
}
