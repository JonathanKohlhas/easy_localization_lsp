import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:easy_localization_lsp/analysis/analysis_error.dart';
import 'package:easy_localization_lsp/analysis/translation_call.dart';
import 'package:easy_localization_lsp/analysis/translation_file.dart';
import 'package:easy_localization_lsp/analysis/translation_visitor.dart';
import 'package:easy_localization_lsp/easy_localization_lsp.dart';
import 'package:easy_localization_lsp/json/parser.dart';
import 'package:easy_localization_lsp/util/location.dart';
import 'package:lsp_server/lsp_server.dart' as lsp;

class EasyLocalizationAnalyzer {
  Map<String, TranslationFile> translationFiles = {};
  Map<String, List<ResolvedTranslationCall>> translationCallsByFile = {};

  final void Function(String) log;

  EasyLocalizationAnalyzer(this.log);

  List<String> get filesWithUnresolvedTranslations =>
      translationCallsByFile.entries
          .where((entry) => entry.value.any((call) => !call.isValid))
          .map((entry) => entry.key)
          .toList();

  List<AnalysisError> analyzeFile(AnalysisContext context, String path) {
    final errors = <AnalysisError>[];
    if (context.currentSession.getParsedUnit(path)
        case ParsedUnitResult(unit: final unit)) {
      final visitor = TranslationVisitor();
      unit.accept(visitor);
      final invocations = visitor.list;
      final calls = invocations.map((call) {
        final start = unit.lineInfo.getLocation(call.offset);
        final end = unit.lineInfo.getLocation(call.end);

        return TranslationCall(
            call,
            Location(
              path,
              call.offset,
              call.length,
              start.lineNumber,
              start.columnNumber,
              endLine: end.lineNumber,
              endColumn: end.columnNumber,
            ));
      });
      final resolvedCalls = calls
          .map((call) => call.resolve(translationFiles.values.toList()))
          .toList();

      translationCallsByFile[path] = resolvedCalls;

      for (final call in resolvedCalls) {
        final exists = call.isValid;
        if (!exists) {
          errors.add(AnalysisError(
            AnalysisErrorSeverity.error,
            call.location,
            "Translation not found: ${call.translationKey}",
          ));
        }
      }
    }
    return errors;
  }

  void analyzeTranslationFile(AnalysisContext context, String path) {
    final content = context.currentSession.resourceProvider
        .getFile(path)
        .readAsStringSync();
    final entries = JsonParser(content, sourceName: path).parse();
    if (entries is! JsonLocationMap) {
      throw ("Entries in translation file incorrect");
    }
    translationFiles[path] = TranslationFile(path, entries);
  }

  List<lsp.Location> getDeclaration(String path, int offset) {
    var calls = translationCallsByFile[path];
    if (calls == null) {
      return [];
    }

    final overlappingCalls = calls.where((call) =>
        offset >= call.invocation.offset && offset <= call.invocation.end);

    final locations = <Location>[];

    for (final overlappingCall in overlappingCalls) {
      for (final translation in overlappingCall.translations) {
        locations.add(translation.location);
      }
    }

    return locations.map((l) => l.toLsp()).toList();
  }

  lsp.Hover? getHoverInfo(lsp.TextDocumentPositionParams params) {
    var calls = translationCallsByFile[params.textDocument.uri.path];
    if (calls == null) {
      return null;
    }
    final overlappingCall = calls
        .where((call) => call.location.toLsp().range.contains(params.position))
        .firstOrNull;
    if (overlappingCall == null) {
      return null;
    }

    var text = "";
    for (final translation in overlappingCall.translations) {
      final String value;
      if (translation is JsonLocationString) {
        value = translation.value;
      } else {
        continue;
      }

      text += "Translation: $value\n";
    }

    return lsp.Hover(
        contents: lsp.Either2.t2(text),
        range: overlappingCall.location.toLsp().range);
  }

  lsp.CompletionList getCompletion(DocumentPositionRequest r) {
    final lines = r.unit.content.split("\n");
    final line = lines[r.position.line];
    //check if the position is insied some quotes (single or double) and find the string if it is in some
    final quotes = RegExp(r'''['"]''');
    final quoteBefore =
        line.substring(0, r.position.character).lastIndexOf(quotes);
    final quoteAfter = line.indexOf(quotes, r.position.character);
    //log("Quote before: $quoteBefore, Quote after: $quoteAfter");
    //We are ignoring the possibility of having a string that contains both single and double quotes
    //as any translation keys would probably not contain those
    //TODO: Robust string selection

    if (quoteBefore != -1 && quoteAfter != -1) {
      final start = quoteBefore + 1;
      final end = quoteAfter;
      final key = line.substring(start, end);
      log("Key: $key");
      final completions = translationFiles.values
          .expand((file) => file.keys)
          .map((k) {
            log(k);
            return k;
          })
          .where((translationKey) => translationKey.startsWith(key))
          .map((key) => lsp.CompletionItem(
                label: key,
                kind: lsp.CompletionItemKind.Text,
              ))
          .toList();
      return lsp.CompletionList(isIncomplete: false, items: completions);
    }
    return lsp.CompletionList(isIncomplete: false, items: []);
  }

  Future<List<lsp.Location>> getReferences(lsp.ReferenceParams params) async {
    if (params.textDocument.uri.path.endsWith(".json")) {
      final translationFile = translationFiles[params.textDocument.uri.path];
      if (translationFile == null) return [];
      //final key = translationFile.locations.value.
      final key = translationFile
          .getFlatKeys()
          .where((k) =>
              k.entry.key.location.toLsp().range.contains(params.position))
          .firstOrNull;
      if (key == null) return [];

      //find all translation calls that reference this key
      final calls = translationCallsByFile.values
          .expand((values) => values)
          .where((call) => call.translationKey == key.fullKey)
          .toList();

      return calls.map((call) => call.location.toLsp()).toList();
    }
    return [];
  }
/*
  @override
  void computeNavigation(
      NavigationRequest request, NavigationCollector collector) {
    if (request is EasyLocalizationDartNavigationRequest) {
      goToDeclaration(request, collector);
    }
  }

  void goToDeclaration(EasyLocalizationDartNavigationRequest request,
      NavigationCollector collector) {
    var calls = translationCallsByFile[request.path];
    if (calls == null) {
      return;
    }

    final overlappingCalls = calls.where((call) =>
        call.invocation.offset <= request.offset + request.length &&
        request.offset <= call.invocation.end);

    for (final overlappingCall in overlappingCalls) {
      for (final translation in overlappingCall.translations) {
        collector.addRegion(
          overlappingCall.invocation.offset,
          overlappingCall.invocation.length,
          ElementKind.UNKNOWN,
          translation.location,
        );
      }
    }
  }*/

  // @override
  // Future<void> computeSuggestions(covariant CompletionRequest request, CompletionCollector collector) async {
  //   if (request is EasyLocalizationDartCompletionRequest) {
  //     for (final file in translationFiles.values) {
  //       for (final key in file.keys) {
  //         collector.addSuggestion(CompletionSuggestion(
  //           CompletionSuggestionKind.IDENTIFIER,
  //           100,
  //           key,
  //           request.offset,
  //           key.length,
  //           false,
  //           false,
  //         ));
  //       }
  //     }
  //   }
  // }
}
