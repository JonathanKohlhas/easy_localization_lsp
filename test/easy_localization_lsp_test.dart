import 'dart:convert';

import 'package:test/test.dart';

void main() {
  group('tr regex', () {
    final pattern = RegExp(r'"[^"]*"\s*\.(tr|plural)\s*\([^\)]*\)', multiLine: true);
    test('should match "somestring".tr()', () {
      final text = '"somestring".tr()';
      final matches = pattern.allMatches(text);
      expect(matches, isNotEmpty);
    });

    test('should match multiple occurences of "somestring".tr()', () {
      final text = '"somestring".tr()\n"somestring".tr()';
      final matches = pattern.allMatches(text);
      expect(matches, hasLength(2));
    });

    test('should match "somestring".plural()', () {
      final text = '"somestring".plural()';
      final matches = pattern.allMatches(text);
      expect(matches, isNotEmpty);
    });
  });

  dynamic niceJsonDecode(String json) {
    return jsonDecode(json);
  }

  final encoder = JsonEncoder.withIndent('  ');

  String niceJsonEncode(dynamic object) {
    return encoder.convert(object);
  }

  group('json manipulation', () {
    test('order of elements is preserved', () {
      final json = '''{
  "key1": "value1",
  "key2": "value2"
}''';
      final parsed = niceJsonDecode(json);
      final out = niceJsonEncode(parsed);
      expect(out, equals(json));
    });

    test('order of elements is preserved when adding elements', () {
      final json = '''{
  "key1": "value1",
  "key3": "value3"
}''';
      final parsed = niceJsonDecode(json);
      parsed['key2'] = 'value2';
      final out = niceJsonEncode(parsed);
      expect(out, equals('''{
  "key1": "value1",
  "key3": "value3",
  "key2": "value2"
}'''));
    });
  });
}
