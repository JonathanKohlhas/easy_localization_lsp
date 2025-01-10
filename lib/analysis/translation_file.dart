import 'package:easy_localization_lsp/analysis/translation_call.dart';
import 'package:easy_localization_lsp/json/parser.dart';

enum PluralCase { zero, one, two, few, many, other }

class FlatKey {
  final String fullKey;
  final JsonLocationMapEntry entry;

  FlatKey(this.fullKey, this.entry);
}

class TranslationFile {
  final String path;
  late final Map<String, dynamic> entries;
  final JsonLocationMap locations;

  TranslationFile(this.path, this.locations) {
    entries = locations.accept<dynamic>(JsonValueBuilder());
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
          if (call.isPlural &&
              PluralCase.values
                  .any((pluralCase) => entry.containsKey(pluralCase.name))) {
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
}
