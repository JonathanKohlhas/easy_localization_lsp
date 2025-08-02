import 'package:analyzer/dart/ast/token.dart';
import 'package:easy_localization_lsp/json/tokenizer.dart';
import 'package:easy_localization_lsp/util/location.dart';

sealed class JsonLocationValue {
  Location get location;
  T accept<T>(JsonLocationValueVisitor<T> visitor);
  bool contains(JsonLocationValue value);
  dynamic toJson() {
    return accept(JsonValueBuilder());
  }
}

class JsonLocationMapEntry {
  final JsonLocationString key;
  final JsonLocationValue value;

  JsonLocationMapEntry(this.key, this.value);
}

class JsonLocationMap extends JsonLocationValue {
  final Map<String, JsonLocationMapEntry> value;
  @override
  final Location location;

  JsonLocationMap(this.value, this.location);

  @override
  String toString() => 'JsonLocationMap{map: $value, location: $location}';

  @override
  T accept<T>(JsonLocationValueVisitor<T> visitor) {
    return visitor.visitMap(this);
  }

  @override
  bool contains(JsonLocationValue value) {
    if (value == this) {
      return true;
    }
    return this.value.values.any((entry) => entry.value.contains(value));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JsonLocationMap &&
        other.value == value &&
        other.location == location;
  }

  @override
  int get hashCode => value.hashCode ^ location.hashCode;
}

class JsonLocationList extends JsonLocationValue {
  final List<JsonLocationValue> value;
  @override
  final Location location;

  JsonLocationList(this.value, this.location);

  @override
  String toString() => 'JsonLocationList{list: $value, location: $location}';

  @override
  T accept<T>(JsonLocationValueVisitor<T> visitor) {
    return visitor.visitList(this);
  }

  @override
  bool contains(JsonLocationValue value) {
    if (value == this) {
      return true;
    }
    return this.value.any((element) => element.contains(value));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JsonLocationList &&
        other.value == value &&
        other.location == location;
  }

  @override
  int get hashCode => value.hashCode ^ location.hashCode;
}

class JsonLocationString extends JsonLocationValue {
  final String value;
  @override
  final Location location;

  JsonLocationString(this.value, this.location);

  @override
  String toString() => 'JsonLocationString{value: $value, location: $location}';

  @override
  T accept<T>(JsonLocationValueVisitor<T> visitor) {
    return visitor.visitString(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JsonLocationString &&
        other.value == value &&
        other.location == location;
  }

  @override
  int get hashCode => value.hashCode ^ location.hashCode;

  @override
  bool contains(JsonLocationValue value) {
    return value == this;
  }
}

class JsonLocationNumber extends JsonLocationValue {
  final num value;
  @override
  final Location location;

  JsonLocationNumber(this.value, this.location);

  @override
  String toString() => 'JsonLocationNumber{value: $value, location: $location}';

  @override
  T accept<T>(JsonLocationValueVisitor<T> visitor) {
    return visitor.visitNumber(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JsonLocationNumber &&
        other.value == value &&
        other.location == location;
  }

  @override
  int get hashCode => value.hashCode ^ location.hashCode;

  @override
  bool contains(JsonLocationValue value) {
    return value == this;
  }
}

class JsonLocationBool extends JsonLocationValue {
  final bool value;
  @override
  final Location location;

  JsonLocationBool(this.value, this.location);

  @override
  String toString() => 'JsonLocationBool{location: $location}';

  @override
  T accept<T>(JsonLocationValueVisitor<T> visitor) {
    return visitor.visitBool(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JsonLocationBool &&
        other.value == value &&
        other.location == location;
  }

  @override
  int get hashCode => value.hashCode ^ location.hashCode;

  @override
  bool contains(JsonLocationValue value) {
    return value == this;
  }
}

class JsonLocationNull extends JsonLocationValue {
  @override
  final Location location;

  JsonLocationNull(this.location);

  @override
  String toString() => 'JsonLocationNull{location: $location}';

  @override
  T accept<T>(JsonLocationValueVisitor<T> visitor) {
    return visitor.visitNull(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is JsonLocationNull && other.location == location;
  }

  @override
  int get hashCode => location.hashCode;

  @override
  bool contains(JsonLocationValue value) {
    return value == this;
  }
}

abstract class JsonLocationValueVisitor<T> {
  T visitMap(JsonLocationMap value);
  T visitList(JsonLocationList value);
  T visitString(JsonLocationString value);
  T visitNumber(JsonLocationNumber value);
  T visitBool(JsonLocationBool value);
  T visitNull(JsonLocationNull value);
}

class JsonParser {
  final JsonTokenizer tokenizer;

  JsonParser(String source, {String sourceName = "source"})
      : tokenizer = JsonTokenizer(source, sourceName: sourceName);

  JsonLocationValue parse() {
    final token = tokenizer.peek();

    switch (token.type) {
      case JsonTokenType.leftCurlyBracket:
        return _parseMap();
      case JsonTokenType.leftSquareBracket:
        return _parseList();
      case JsonTokenType.string:
        return _parseString();
      case JsonTokenType.number:
        return _parseNumber();
      case JsonTokenType.trueValue:
        return _parseBool(true);
      case JsonTokenType.falseValue:
        return _parseBool(false);
      case JsonTokenType.nullValue:
        return _parseNull();
      default:
        throw Exception('Unexpected token: $token');
    }
  }

  JsonLocationMap _parseMap() {
    final start = _consume(JsonTokenType.leftCurlyBracket).location;
    final map = <String, JsonLocationMapEntry>{};

    while (true) {
      if (tokenizer.peek().type == JsonTokenType.rightCurlyBracket) {
        break;
      }

      final key = _parseString();
      _consume(JsonTokenType.colon);
      final value = parse();

      map[key.value] = JsonLocationMapEntry(key, value);

      if (tokenizer.peek().type == JsonTokenType.comma) {
        tokenizer.next();
      } else {
        break;
      }
    }

    final end = _consume(JsonTokenType.rightCurlyBracket).location;

    return JsonLocationMap(
      map,
      start - end,
    );
  }

  JsonToken _consume(JsonTokenType type) {
    final token = tokenizer.next();

    if (token.type != type) {
      throw Exception('Expected $type, got $token');
    }

    return token;
  }

  JsonLocationList _parseList() {
    final start = _consume(JsonTokenType.leftSquareBracket).location;
    final list = <JsonLocationValue>[];

    while (true) {
      if (tokenizer.peek().type == JsonTokenType.rightSquareBracket) {
        break;
      }

      final value = parse();

      list.add(value);

      if (tokenizer.peek().type == JsonTokenType.comma) {
        tokenizer.next();
      } else {
        break;
      }
    }

    final end = _consume(JsonTokenType.rightSquareBracket).location;

    return JsonLocationList(
      list,
      start - end,
    );
  }

  JsonLocationString _parseString() {
    final token = _consume(JsonTokenType.string);
    return JsonLocationString(token.value, token.location);
  }

  JsonLocationNumber _parseNumber() {
    final token = _consume(JsonTokenType.number);
    return JsonLocationNumber(num.parse(token.value), token.location);
  }

  JsonLocationBool _parseBool(bool value) {
    final token =
        _consume(value ? JsonTokenType.trueValue : JsonTokenType.falseValue);
    return JsonLocationBool(value, token.location);
  }

  JsonLocationNull _parseNull() {
    final token = _consume(JsonTokenType.nullValue);
    return JsonLocationNull(token.location);
  }
}

enum ParsingErrorType {
  tokenizationError,
  unexpectedToken;
}

class ParsingError {
  final Location location;
  final String message;
  final ParsingErrorType type;
  final dynamic additionalData;

  ParsingError(
    this.type, {
    String? message,
    required this.location,
    this.additionalData,
  }) : message = message ?? ParsingError._defaultMessage(type, additionalData);

  static _defaultMessage(ParsingErrorType type, dynamic additionalData) {
    return switch (type) {
      ParsingErrorType.tokenizationError =>
        'Tokenization Error: $additionalData',
      ParsingErrorType.unexpectedToken => 'Unexpected token: $additionalData',
    };
  }
}

class RecoveringJsonParser {
  final RecoveringJsonTokenizer tokenizer;

  RecoveringJsonParser(String source, {String sourceName = "source"})
      : tokenizer = RecoveringJsonTokenizer(source, sourceName: sourceName);

  (JsonLocationValue, List<ParsingError>) parse() {
    final result = tokenizer.peek();

    switch (result) {
      case TokenizationResult(
          token: JsonToken(type: JsonTokenType.leftCurlyBracket)
        ):
        return _parseMap();
      case TokenizationResult(
          token: JsonToken(type: JsonTokenType.leftSquareBracket)
        ):
        return _parseList();
      case TokenizationResult(token: JsonToken(type: JsonTokenType.string)):
        return _parseString();
      case TokenizationResult(token: JsonToken(type: JsonTokenType.number)):
        return _parseNumber();
      case TokenizationResult(token: JsonToken(type: JsonTokenType.trueValue)):
        return _parseBool(true);
      case TokenizationResult(token: JsonToken(type: JsonTokenType.falseValue)):
        return _parseBool(false);
      case TokenizationResult(token: JsonToken(type: JsonTokenType.nullValue)):
        return _parseNull();
      default:
        tokenizer.next();
        final (returned, errors) = parse();
        errors.add(ParsingError(ParsingErrorType.unexpectedToken,
            location: result.token.location, additionalData: result.token));
      // throw Exception('Unexpected token: $token');
    }
  }
}

class JsonValueBuilder implements JsonLocationValueVisitor<dynamic> {
  @override
  visitBool(JsonLocationBool value) {
    return value.value;
  }

  @override
  visitList(JsonLocationList value) {
    List<dynamic> values = [];
    for (final lvalue in value.value) {
      values.add(lvalue.accept(this));
    }
    return values;
  }

  @override
  visitMap(JsonLocationMap value) {
    Map<String, dynamic> values = {};
    for (final lvalue in value.value.entries) {
      values[lvalue.key] = lvalue.value.value.accept(this);
    }
    return values;
  }

  @override
  visitNull(JsonLocationNull value) {
    return null;
  }

  @override
  visitNumber(JsonLocationNumber value) {
    return value.value;
  }

  @override
  visitString(JsonLocationString value) {
    return value.value;
  }
}
