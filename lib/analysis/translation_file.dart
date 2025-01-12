import 'package:easy_localization_lsp/analysis/translation_call.dart';
import 'package:easy_localization_lsp/analysis/translation_result.dart';
import 'package:easy_localization_lsp/json/parser.dart';

class FlatKey {
  final String fullKey;
  final JsonLocationMapEntry entry;

  FlatKey(this.fullKey, this.entry);
}

enum PluralCase { zero, one, two, few, many, other }

class TranslationFile {
  final String path;
  late final Map<String, dynamic> entries;
  final JsonLocationMap locations;

  TranslationFile(this.path, this.locations) {
    entries = locations.accept<dynamic>(JsonValueBuilder());
  }

  List<String> get keys {
    final List<String> keys = [];
    void getKeys(Map<String, dynamic> entries, String key) {
      entries.forEach((k, v) {
        final newKey = key.isEmpty ? k : "$key.$k";

        keys.add(newKey);
        if (v is Map<String, dynamic>) {
          getKeys(v, newKey);
        }
      });
    }

    getKeys(entries, "");
    return keys;
  }

  bool contains(TranslationCall call) {
    final keys = call.translationKey?.split(".");
    if (keys == null) {
      return false;
    }
    bool containsHelper(Map<String, dynamic> entries, List<String> keys) {
      final head = keys.removeLast();
      final entry = entries[head];
      if (keys.isEmpty) {
        if (entry is String) {
          if (call.isPlural || call.hasGender) {
            return false;
          }
          return true;
        } else if (entry is Map<String, dynamic>) {
          if (call.isPlural && PluralCase.values.any((pluralCase) => entry.containsKey(pluralCase.name))) {
            return true;
          }
          if (call.hasGender) {
            return true;
          }
        }
        return false;
      }

      if (entry is Map<String, dynamic>) {
        return containsHelper(entry, keys);
      }

      return false;
    }

    return containsHelper(entries, keys.reversed.toList());
  }

  List<FlatKey> getFlatKeys() {
    final List<FlatKey> keys = [];
    void getKeys(JsonLocationMap map, String key) {
      map.value.forEach((k, v) {
        final newKey = key.isEmpty ? k : "$key.$k";
        keys.add(FlatKey(newKey, v));
        if (v case JsonLocationMapEntry(value: JsonLocationMap value)) {
          getKeys(value, newKey);
        }
      });
    }

    getKeys(locations, "");
    return keys;
  }

  JsonLocationValue? getLocation(TranslationCall call) {
    final keys = call.translationKey?.split(".");
    if (keys == null) {
      throw Exception("Non string keys currently not supported");
    }

    JsonLocationValue? getHelper(JsonLocationValue value, List<String> keys) {
      if (keys.isEmpty) {
        return value;
      }
      final head = keys.removeLast();
      switch (value) {
        case JsonLocationMap map:
          return getHelper(map.value[head]!.value, keys);
        case _:
          return null;
      }
    }

    return getHelper(locations, keys.reversed.toList());
  }

  TranslationResult translate(String key, {bool isPlural = false, bool isGendered = false}) {
    final keys = key.split(".");
    if (keys.isEmpty) {
      return TranslationFailure(TranslationFailureReason.noSuchTranslationKeyTooShort);
    }
    TranslationResult translate(JsonLocationMap map, List<String> keys) {
      final head = keys.removeAt(0);
      final entry = map.value[head]?.value;
      if (keys.isEmpty) {
        switch (entry) {
          case JsonLocationString():
            if (isPlural) {
              return TranslationFailure(TranslationFailureReason.callIsPluralButNoPluralTranslation);
            } else if (isGendered) {
              return TranslationFailure(TranslationFailureReason.callHasGenderButNoGenderTranslation);
            }
            return TranslationSuccess(entry);
          case JsonLocationMap():
            if (isPlural && PluralCase.values.any((pluralCase) => entry.value.containsKey(pluralCase.name))) {
              return TranslationSuccess(entry);
            } else if (isGendered) {
              return TranslationSuccess(entry);
            }
          default:
            // TODO could check in more detail, for example if the translation is a map that looks like a plural map
            // with all keys being plural cases, the error could say something like translationIsPluralButCallIsNot
            return TranslationFailure(TranslationFailureReason.noSuchTranslationKeyTooShort);
        }
      }

      if (entry is JsonLocationMap) {
        return translate(entry, keys);
      }

      return TranslationFailure(TranslationFailureReason.noSuchTranslationKeyTooLong);
    }

    return translate(locations, keys);
  }

  TranslationResult translateCall(TranslationCall call) {
    if (call.translationKey == null) {
      return TranslationFailure(TranslationFailureReason.noSuchTranslationKeyTooShort);
    }
    return translate(call.translationKey!, isPlural: call.isPlural, isGendered: call.hasGender);
  }
}
