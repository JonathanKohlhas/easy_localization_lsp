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
        final token = JsonToken(JsonTokenType.leftCurlyBracket, '{', Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case '}':
        final token = JsonToken(JsonTokenType.rightCurlyBracket, '}', Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case '[':
        final token = JsonToken(JsonTokenType.leftSquareBracket, '[', Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case ']':
        final token = JsonToken(JsonTokenType.rightSquareBracket, ']', Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case ',':
        final token = JsonToken(JsonTokenType.comma, ',', Location(sourceName, index, 1, line, column));
        advance();
        return token;
      case ':':
        final token = JsonToken(JsonTokenType.colon, ':', Location(sourceName, index, 1, line, column));
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
            Location(sourceName, startIndex, index - startIndex, startLine, startColumn,
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

    return JsonToken(JsonTokenType.trueValue, 'true',
        Location(sourceName, startIndex, 4, startLine, startColumn, endLine: line, endColumn: column));
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

    return JsonToken(JsonTokenType.falseValue, 'false',
        Location(sourceName, startIndex, 5, startLine, startColumn, endLine: line, endColumn: column));
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

    return JsonToken(JsonTokenType.nullValue, 'null',
        Location(sourceName, startIndex, 4, startLine, startColumn, endLine: line, endColumn: column));
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

    return JsonToken(JsonTokenType.number, buffer.toString(),
        Location(sourceName, startIndex, index - startIndex, startLine, startColumn, endLine: line, endColumn: column));
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
