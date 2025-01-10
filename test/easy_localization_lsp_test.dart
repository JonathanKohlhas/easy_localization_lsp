import 'package:easy_localization_lsp/easy_localization_lsp.dart';
import 'package:test/test.dart';

void main() {
  group('tr regex', () {
    final pattern =
        RegExp(r'"[^"]*"\s*\.(tr|plural)\s*\([^\)]*\)', multiLine: true);
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
}
