import 'package:easy_localization_lsp/util/location.dart';

class JsonToken {
  final JsonTokenType type;
  final String value;
  final Location location;

  JsonToken(this.type, this.value, this.location);

  @override
  String toString() {
    return 'JsonToken{type: $type, value: $value, location: $location}';
  }
}

enum JsonTokenType {
  leftCurlyBracket,
  rightCurlyBracket,
  leftSquareBracket,
  rightSquareBracket,
  comma,
  colon,
  string,
  number,
  trueValue,
  falseValue,
  nullValue,
  endOfFile,
  invalid,
}

class JsonTokenizer {
  String source;
  String sourceName;
  int index = 0;

  int line = 1;
  int column = 1;

  JsonTokenizer(this.source, {this.sourceName = 'source'});

  bool get isDone => index >= source.length;

  void advance() {
    if (isDone) {
      throw Exception('Unexpected end of input');
    }

    if (source[index] == '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }

    index++;
  }

  void skipWhitespace() {
    while (!isDone && source[index].trim().isEmpty) {
      advance();
    }
  }

  JsonToken next() {
    skipWhitespace();

    if (isDone) {
      throw Exception('Unexpected end of input');
    }

    final char = source[index];

    switch (char) {
      case '{':
        final token = JsonToken(JsonTokenType.leftCurlyBracket, '{',
            Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case '}':
        final token = JsonToken(JsonTokenType.rightCurlyBracket, '}',
            Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case '[':
        final token = JsonToken(JsonTokenType.leftSquareBracket, '[',
            Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case ']':
        final token = JsonToken(JsonTokenType.rightSquareBracket, ']',
            Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case ',':
        final token = JsonToken(JsonTokenType.comma, ',',
            Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case ':':
        final token = JsonToken(JsonTokenType.colon, ':',
            Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case '"':
        return _readString();
      case 't':
        return _readTrue();
      case 'f':
        return _readFalse();
      case 'n':
        return _readNull();
      default:
        return _readNumber();
    }
  }

  JsonToken _readString() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    final buffer = StringBuffer();

    while (!isDone) {
      final char = source[index];

      if (char == '"') {
        final token = JsonToken(
            JsonTokenType.string,
            buffer.toString(),
            Location(sourceName, startIndex, index - startIndex, startLine,
                startColumn,
                endLine: line, endColumn: column));
        advance();
        return token;
      }

      if (char == '\\') {
        advance();

        if (isDone) {
          throw Exception('Unexpected end of input');
        }

        final escapedChar = source[index];

        switch (escapedChar) {
          case '"':
            buffer.write('"');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case '/':
            buffer.write('/');
            break;
          case 'b':
            buffer.write('\b');
            break;
          case 'f':
            buffer.write('\f');
            break;
          case 'n':
            buffer.write('\n');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case 't':
            buffer.write('\t');
            break;
          case 'u':
            final hex = source.substring(index + 1, index + 5);

            if (hex.length != 4 || !hex.contains(RegExp(r'^[0-9a-fA-F]+$'))) {
              throw Exception('Invalid unicode escape sequence');
            }

            buffer.write(String.fromCharCode(int.parse(hex, radix: 16)));
            index += 4;
            break;
          default:
            throw Exception('Invalid escape sequence');
        }
      } else {
        buffer.write(char);
      }

      advance();
    }

    throw Exception('Unexpected end of input');
  }

  JsonToken _readTrue() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    if (source.substring(index, index + 3) != 'rue') {
      throw Exception('Invalid token');
    }

    index += 3;

    return JsonToken(
        JsonTokenType.trueValue,
        'true',
        Location(sourceName, startIndex, 4, startLine, startColumn,
            endLine: line, endColumn: column));
  }

  JsonToken _readFalse() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    if (source.substring(index, index + 4) != 'alse') {
      throw Exception('Invalid token');
    }

    index += 4;

    return JsonToken(
        JsonTokenType.falseValue,
        'false',
        Location(sourceName, startIndex, 5, startLine, startColumn,
            endLine: line, endColumn: column));
  }

  JsonToken _readNull() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    if (source.substring(index, index + 3) != 'ull') {
      throw Exception('Invalid token');
    }

    index += 3;

    return JsonToken(
        JsonTokenType.nullValue,
        'null',
        Location(sourceName, startIndex, 4, startLine, startColumn,
            endLine: line, endColumn: column));
  }

  JsonToken _readNumber() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    final buffer = StringBuffer();

    while (!isDone) {
      final char = source[index];

      if (char == '.' || char == 'e' || char == 'E') {
        buffer.write(char);
      } else if (char == '-' ||
          char == '+' ||
          char == '0' ||
          char == '1' ||
          char == '2' ||
          char == '3' ||
          char == '4' ||
          char == '5' ||
          char == '6' ||
          char == '7' ||
          char == '8' ||
          char == '9') {
        buffer.write(char);
      } else {
        break;
      }

      advance();
    }

    return JsonToken(
        JsonTokenType.number,
        buffer.toString(),
        Location(
            sourceName, startIndex, index - startIndex, startLine, startColumn,
            endLine: line, endColumn: column));
  }

  JsonToken peek() {
    final currentIndex = index;
    final currentLine = line;
    final currentColumn = column;

    final token = next();

    index = currentIndex;
    line = currentLine;
    column = currentColumn;

    return token;
  }
}

enum TokenizationErrorType {
  unexpectedEndOfString,
  unexpectedNewlineInString,
  invalidEscapeSequence,
  invalidToken,
  unexpectedEndOfInput;

  String get message {
    switch (this) {
      case TokenizationErrorType.unexpectedEndOfString:
        return 'Unexpected end of string, encountered end of input';
      case TokenizationErrorType.unexpectedNewlineInString:
        return 'Unexpected newline in string';
      case TokenizationErrorType.invalidEscapeSequence:
        return 'Invalid escape sequence';
      case TokenizationErrorType.invalidToken:
        return 'Invalid token';
      case TokenizationErrorType.unexpectedEndOfInput:
        return 'Unexpected end of input';
    }
  }
}

class TokenizationError {
  final Location location;
  final String message;
  final TokenizationErrorType type;

  TokenizationError(
    this.type, {
    String? message,
    required this.location,
  }) : message = message ?? type.message;

  @override
  String toString() {
    return '${location.file}:${location.startLine}:${location.startColumn}: $message';
  }
}

class TokenizationResult {
  final JsonToken token;
  final List<TokenizationError> errors;

  TokenizationResult(this.token, {this.errors = const []});
}

TokenizationResult _ok(JsonToken token) {
  return TokenizationResult(token);
}

TokenizationResult _err(JsonToken token,
    {required TokenizationErrorType type, String? message}) {
  return TokenizationResult(token, errors: [
    TokenizationError(
      type,
      message: message,
      location: token.location,
    )
  ]);
}

/// Tokenizes JSON returning a stream of tokens and errors.
/// The RecoveringJsonTokenizer can continue tokenizing using a best-effort strategy after encountering an error.
/// This is useful for syntax highlighting and code completion.
class RecoveringJsonTokenizer {
  final String source;
  final String sourceName;
  int index = 0;
  int line = 1;
  int column = 1;

  RecoveringJsonTokenizer(this.source, {this.sourceName = 'source'});

  bool get isDone => index >= source.length;

  void advance() {
    if (isDone) {
      throw Exception('Unexpected end of input');
    }

    if (source[index] == '\n') {
      line++;
      column = 1;
    } else {
      column++;
    }

    index++;
  }

  void skipWhitespace() {
    while (!isDone && source[index].trim().isEmpty) {
      advance();
    }
  }

  Iterable<TokenizationResult> tokenize() sync* {
    while (!isDone) {
      final token = next();
      yield token;
      if (token.token.type == JsonTokenType.endOfFile) {
        return;
      }
    }
    yield _ok(
      JsonToken(
        JsonTokenType.endOfFile,
        '',
        Location(sourceName, index, 0, line, column),
      ),
    );
  }

  TokenizationResult next() {
    skipWhitespace();

    if (isDone) {
      return _ok(
        JsonToken(
          JsonTokenType.endOfFile,
          '',
          Location(sourceName, index, 0, line, column),
        ),
      );
    }

    final char = source[index];

    JsonToken? result;

    switch (char) {
      case '{':
        result = JsonToken(JsonTokenType.leftCurlyBracket, '{',
            Location(sourceName, index, 1, line, column));
      case '}':
        result = JsonToken(JsonTokenType.rightCurlyBracket, '}',
            Location(sourceName, index, 1, line, column));
      case '[':
        result = JsonToken(JsonTokenType.leftSquareBracket, '[',
            Location(sourceName, index, 1, line, column));
      case ']':
        result = JsonToken(JsonTokenType.rightSquareBracket, ']',
            Location(sourceName, index, 1, line, column));
      case ',':
        result = JsonToken(JsonTokenType.comma, ',',
            Location(sourceName, index, 1, line, column));
      case ':':
        result = JsonToken(JsonTokenType.colon, ':',
            Location(sourceName, index, 1, line, column));
      case '"':
        return _readString();
      case 't':
        return _readTrue();
      case 'f':
        return _readFalse();
      case 'n':
        return _readNull();
      case _ when RegExp(r'[0-9-]').hasMatch(char):
        return _readNumber();
      default:
        return _readInvalid();
    }

    try {
      advance();
    } catch (e) {
      //end of input is fine here so we can ignore it
    }

    return _ok(result);
  }

  TokenizationResult peek() {
    final currentIndex = index;
    final currentLine = line;
    final currentColumn = column;
    final result = next();
    index = currentIndex;
    line = currentLine;
    column = currentColumn;
    return result;
  }

  TokenizationResult _readString() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;
    final errors = <TokenizationError>[];

    advance();

    final buffer = StringBuffer();

    while (!isDone) {
      final char = source[index];

      if (char == '"') {
        final token = JsonToken(
          JsonTokenType.string,
          buffer.toString(),
          Location(sourceName, startIndex, index - startIndex, startLine,
              startColumn,
              endLine: line, endColumn: column),
        );
        advance();
        return TokenizationResult(token, errors: errors);
      }

      if (char == '\\') {
        advance();

        if (isDone) {
          return TokenizationResult(
            JsonToken(
              JsonTokenType.string,
              buffer.toString(),
              Location(sourceName, startIndex, index - startIndex, startLine,
                  startColumn),
            ),
            errors: [
              ...errors,
              TokenizationError(
                TokenizationErrorType.unexpectedEndOfString,
                location: Location(sourceName, startIndex, index - startIndex,
                    startLine, startColumn),
              ),
            ],
          );
        }

        final escapedChar = source[index];

        switch (escapedChar) {
          case '"':
            buffer.write('"');
          case '\\':
            buffer.write('\\');
          case '/':
            buffer.write('/');
          case 'b':
            buffer.write('\b');
          case 'f':
            buffer.write('\f');
          case 'n':
            buffer.write('\n');
          case 'r':
            buffer.write('\r');
          case 't':
            buffer.write('\t');
          case 'u':
            if (source.length < index + 5) {
              errors.add(TokenizationError(
                TokenizationErrorType.invalidEscapeSequence,
                message:
                    'Invalid unicode escape sequence (expected 4 hex digits)',
                location:
                    Location(sourceName, index - 1, 6, startLine, startColumn),
              ));
              buffer.write('\\u');
            }
            final hex = source.substring(index + 1, index + 5);
            if (hex.length != 4 || !hex.contains(RegExp(r'^[0-9a-fA-F]+$'))) {
              errors.add(TokenizationError(
                TokenizationErrorType.invalidEscapeSequence,
                location:
                    Location(sourceName, index - 1, 6, startLine, startColumn),
              ));
              buffer.write('\\u');
            } else {
              buffer.write(String.fromCharCode(int.parse(hex, radix: 16)));
              index += 4;
            }
          default:
            // errors.add(TokenizerError('Invalid escape sequence',
            //     Location(sourceName, index - 1, 2, startLine, startColumn)));
            errors.add(TokenizationError(
              TokenizationErrorType.invalidEscapeSequence,
              location:
                  Location(sourceName, index - 1, 2, startLine, startColumn),
            ));
            buffer.write('\\');
            buffer.write(escapedChar);
        }
      } else if (char == '\n') {
        return TokenizationResult(
          JsonToken(
            JsonTokenType.string,
            buffer.toString(),
            Location(sourceName, startIndex, index - startIndex, startLine,
                startColumn),
          ),
          errors: [
            ...errors,
            TokenizationError(
              TokenizationErrorType.unexpectedNewlineInString,
              location: Location(sourceName, index, 1, line, column),
            ),
          ],
        );
      } else {
        buffer.write(char);
      }

      advance();
    }
    return TokenizationResult(
      JsonToken(
        JsonTokenType.string,
        buffer.toString(),
        Location(
            sourceName, startIndex, index - startIndex, startLine, startColumn),
      ),
      errors: [
        ...errors,
        TokenizationError(
          TokenizationErrorType.unexpectedEndOfString,
          location: Location(sourceName, index, 0, line, column),
        ),
      ],
    );
  }

  /// read until whitespace, a token boundary, a newline or end of input and turn it into an invalid token
  /// this is useful for syntax highlighting and code completion
  /// as it allows to continue tokenizing after an error/tokenizing broken strings
  TokenizationResult _readInvalid(
      {int? startLine,
      int? startColumn,
      int? startIndex,
      String? initialBuffer}) {
    startLine ??= line;
    startColumn ??= column;
    startIndex ??= index;

    final buffer = StringBuffer(initialBuffer ?? '');

    bool isBoundary(String char) {
      return char == '{' ||
          char == '}' ||
          char == '[' ||
          char == ']' ||
          char == ',' ||
          char == ':' ||
          char == '"' ||
          char == '.' ||
          char == ' ' ||
          char == '\n' ||
          char == '\t' ||
          char == '\r';
    }

    while (!isDone && !isBoundary(source[index])) {
      buffer.write(source[index]);
      advance();
    }

    return _err(
      JsonToken(
        JsonTokenType.invalid,
        buffer.toString(),
        Location(
            sourceName, startIndex, index - startIndex, startLine, startColumn),
      ),
      type: TokenizationErrorType.invalidToken,
    );
  }

  TokenizationResult _readTrue() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    if (source.length < index + 3 ||
        source.substring(index, index + 3) != 'rue') {
      return _readInvalid(
        startLine: startLine,
        startColumn: startColumn,
        startIndex: startIndex,
        initialBuffer: 't',
      );
    }

    index += 3;

    return _ok(
      JsonToken(
        JsonTokenType.trueValue,
        'true',
        Location(sourceName, startIndex, 4, startLine, startColumn,
            endLine: line, endColumn: column),
      ),
    );
  }

  TokenizationResult _readFalse() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    if (source.length < index + 4 ||
        source.substring(index, index + 4) != 'alse') {
      return _readInvalid(
        startLine: startLine,
        startColumn: startColumn,
        startIndex: startIndex,
        initialBuffer: 'f',
      );
    }

    index += 4;

    return _ok(
      JsonToken(
        JsonTokenType.falseValue,
        'false',
        Location(sourceName, startIndex, 5, startLine, startColumn,
            endLine: line, endColumn: column),
      ),
    );
  }

  TokenizationResult _readNull() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    advance();

    if (source.length < index + 3 ||
        source.substring(index, index + 3) != 'ull') {
      return _readInvalid(
        startLine: startLine,
        startColumn: startColumn,
        startIndex: startIndex,
        initialBuffer: 'n',
      );
    }

    index += 3;

    return _ok(
      JsonToken(
        JsonTokenType.nullValue,
        'null',
        Location(sourceName, startIndex, 4, startLine, startColumn,
            endLine: line, endColumn: column),
      ),
    );
  }

  TokenizationResult _readNumber() {
    final startLine = line;
    final startColumn = column;
    final startIndex = index;

    final buffer = StringBuffer();

    while (!isDone) {
      final char = source[index];

      if (char == '.' || char == 'e' || char == 'E') {
        buffer.write(char);
      } else if (char == '-' ||
          char == '+' ||
          char == '0' ||
          char == '1' ||
          char == '2' ||
          char == '3' ||
          char == '4' ||
          char == '5' ||
          char == '6' ||
          char == '7' ||
          char == '8' ||
          char == '9') {
        buffer.write(char);
      } else {
        break;
      }

      advance();
    }

    final number = double.tryParse(buffer.toString());
    if (number == null) {
      return _readInvalid(
        startLine: startLine,
        startColumn: startColumn,
        startIndex: startIndex,
        initialBuffer: buffer.toString(),
      );
    }

    return _ok(
      JsonToken(
        JsonTokenType.number,
        buffer.toString(),
        Location(
            sourceName, startIndex, index - startIndex, startLine, startColumn,
            endLine: line, endColumn: column),
      ),
    );
  }
}
