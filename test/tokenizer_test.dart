import 'package:easy_localization_lsp/json/tokenizer.dart';
import 'package:test/test.dart';

List<TokenizationResult> _tokenize(String input) {
  final tokenizer = RecoveringJsonTokenizer(input);
  return tokenizer.tokenize().toList();
}

void main() {
  group("RecoveringJsonTokenizer", () {
    group("Strings", () {
      test("Simple string", () {
        final tokens = _tokenize('"Hello"');
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.string));
        expect(tokens[0].token.value, equals("Hello"));
        expect(tokens[0].errors, isEmpty);
      });

      test("No closing quote", () {
        final tokens = _tokenize('"Hello');
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.string));
        expect(tokens[0].token.value, equals("Hello"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.unexpectedEndOfString));
      });

      test("Line break in string", () {
        final tokens = _tokenize('"Hello\nWorld"');
        expect(tokens.length, equals(4));
        expect(tokens[0].errors, isNotEmpty);
        expect(
            tokens[0].errors.first.type, equals(TokenizationErrorType.unexpectedNewlineInString));
        expect(tokens[0].token.type, equals(JsonTokenType.string));
        expect(tokens[0].token.value, equals("Hello"));
        expect(tokens[1].token.type, equals(JsonTokenType.invalid));
        expect(tokens[1].token.value, equals("World"));
        expect(tokens[1].errors, isNotEmpty);
        expect(tokens[1].errors.first.type, equals(TokenizationErrorType.invalidToken));
        expect(tokens[2].token.type, equals(JsonTokenType.string));
        expect(tokens[2].token.value, equals(""));
        expect(tokens[2].errors, isNotEmpty);
        expect(tokens[2].errors.first.type, equals(TokenizationErrorType.unexpectedEndOfString));
      });

      test("Invalid escape sequence", () {
        final tokens = _tokenize('"Hello\\xWorld"');
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.string));
        expect(tokens[0].token.value, equals("Hello\\xWorld"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.invalidEscapeSequence));
      });

      test("Invalid unicode escape sequence", () {
        final tokens = _tokenize('"Hello\\uWorld"');
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.string));
        expect(tokens[0].token.value, equals("Hello\\uWorld"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.invalidEscapeSequence));
      });
    });

    group("Numbers", () {
      List<(String testName, String input)> positiveTests = [
        ("Simple number", "123"),
        ("Negative number", "-123"),
        ("Decimal number", "123.456"),
        ("Negative decimal number", "-123.456"),
        ("Exponential number", "123e4"),
        ("Negative exponential number", "-123e4"),
        ("Exponential number with decimal", "123.456e4"),
        ("Negative exponential number with decimal", "-123.456e4"),
        ("Exponential number with negative exponent", "123e-4"),
        ("Negative exponential number with negative exponent", "-123e-4"),
        ("Exponential number with positive exponent", "123e+4"),
        ("Negative exponential number with positive exponent", "-123e+4"),
        ("Uppercase exponential number", "123E4"),
        ("Negative uppercase exponential number", "-123E4"),
        ("Uppercase exponential number with decimal", "123.456E4"),
        ("Negative uppercase exponential number with decimal", "-123.456E4"),
        ("Uppercase exponential number with negative exponent", "123E-4"),
        ("Negative uppercase exponential number with negative exponent", "-123E-4"),
        ("Uppercase exponential number with positive exponent", "123E+4"),
        ("Negative uppercase exponential number with positive exponent", "-123E+4"),
      ];

      for (var testCase in positiveTests) {
        test(testCase.$1, () {
          final tokens = _tokenize(testCase.$2);
          expect(tokens.length, equals(2));
          expect(tokens[0].token.type, equals(JsonTokenType.number));
          expect(tokens[0].token.value, equals(testCase.$2));
          expect(tokens[0].errors, isEmpty);
        });
      }

      test("Invalid number", () {
        final tokens = _tokenize("123.4E56E2");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.invalid));
        expect(tokens[0].token.value, equals("123.4E56E2"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.invalidToken));
      });
    });

    group("bools", () {
      test("True", () {
        final tokens = _tokenize("true");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.trueValue));
        expect(tokens[0].token.value, equals("true"));
        expect(tokens[0].errors, isEmpty);
      });

      test("False", () {
        final tokens = _tokenize("false");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.falseValue));
        expect(tokens[0].token.value, equals("false"));
        expect(tokens[0].errors, isEmpty);
      });

      test("Invalid bool 1", () {
        final tokens = _tokenize("fals");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.invalid));
        expect(tokens[0].token.value, equals("fals"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.invalidToken));
      });

      test("Invalid bool 2", () {
        final tokens = _tokenize("tr");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.invalid));
        expect(tokens[0].token.value, equals("tr"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.invalidToken));
      });
    });

    group("null", () {
      test("Null", () {
        final tokens = _tokenize("null");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.nullValue));
        expect(tokens[0].token.value, equals("null"));
        expect(tokens[0].errors, isEmpty);
      });

      test("Invalid null", () {
        final tokens = _tokenize("nul");
        expect(tokens.length, equals(2));
        expect(tokens[0].token.type, equals(JsonTokenType.invalid));
        expect(tokens[0].token.value, equals("nul"));
        expect(tokens[0].errors, isNotEmpty);
        expect(tokens[0].errors.first.type, equals(TokenizationErrorType.invalidToken));
      });
    });

    group("complex", () {
      test("will recover after error", () {
        final tokens = _tokenize('''
{
  "key": "value",
  "hell
  o": "world",
  "key2": 123,
}
''');

        expect(tokens.length, equals(16));
        expect(tokens.where((t) => t.errors.isNotEmpty).length, equals(4));
        void expectOneValidToken(JsonTokenType type, String value) {
          expect(
              tokens.any((t) => t.token.type == type && t.token.value == value && t.errors.isEmpty),
              isTrue);
        }

        expectOneValidToken(JsonTokenType.string, "key");
        expectOneValidToken(JsonTokenType.string, "value");
        expectOneValidToken(JsonTokenType.string, "key2");
        expectOneValidToken(JsonTokenType.number, "123");
      });
    });
  });
}
