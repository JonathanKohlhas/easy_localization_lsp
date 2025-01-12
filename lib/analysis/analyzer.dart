import 'dart:convert';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:easy_localization_lsp/analysis/analysis_error.dart';
import 'package:easy_localization_lsp/analysis/translation_call.dart';
import 'package:easy_localization_lsp/analysis/translation_file.dart';
import 'package:easy_localization_lsp/analysis/translation_visitor.dart';
import 'package:easy_localization_lsp/easy_localization_lsp.dart';
import 'package:easy_localization_lsp/json/parser.dart';
import 'package:easy_localization_lsp/protocol/labels_provider.dart';
import 'package:easy_localization_lsp/util/location.dart';
import 'package:lsp_server/lsp_server.dart' as lsp;

class EasyLocalizationAnalyzer {
  final void Function(String) log;

  final List<String> rootPaths;

  Map<String, List<ResolvedTranslationCall>> translationCallsByFile = {};

  Map<String, TranslationFile> translationFiles = {};
  final AnalysisContextCollection _collection;
  EasyLocalizationAnalyzer(this._collection, this.rootPaths, this.log);

  void analyzeFile(AnalysisContext context, String path) {
    // log("Analyzing file: $path");
    final errors = <AnalysisError>[];
    if (context.currentSession.getParsedUnit(path) case ParsedUnitResult(unit: final unit)) {
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
      final resolvedCalls = calls.map((call) => call.resolve(translationFiles.values.toList())).toList();

      translationCallsByFile[path] = resolvedCalls;
    }
  }

  List<AnalysisError> getDiagnostics(String path) {
    return translationCallsByFile[path]
            ?.where((call) => !call.isValid)
            .map((call) => AnalysisError(
                  AnalysisErrorSeverity.error,
                  call.location,
                  "Translation not found: ${call.translationKey}",
                  code: AnalysisErrorCode.noSuchTranslation,
                ))
            .toList() ??
        [];
  }

  void analyzeTranslationFile(AnalysisContext context, String path) {
    final content = context.currentSession.resourceProvider.getFile(path).readAsStringSync();
    final entries = JsonParser(content, sourceName: path).parse();
    if (entries is! JsonLocationMap) {
      throw ("Entries in translation file incorrect");
    }
    translationFiles[path] = TranslationFile(path, entries);
  }

  FlatKey? findTranslationKeyByRange(TranslationFile translationFile, lsp.RenameParams params) {
    final key = translationFile
        .getFlatKeys()
        .where((k) => k.entry.key.location.toLsp().range.contains(params.position))
        .firstOrNull;
    return key;
  }

  TranslationFile getClosestTranslationFile(String path) {
    final rootPath = rootPaths.reduce((value, element) {
      final commonPrefixLengthValue = value.commonPrefixLength(path);
      final commonPrefixLengthElement = element.commonPrefixLength(path);
      return commonPrefixLengthValue > commonPrefixLengthElement ? value : element;
    });
    return translationFiles[rootPath]!;
  }

  Future<List<lsp.CodeAction>> getCodeActions(lsp.CodeActionParams params) async {
    ///TODO:
    /// Possible code actions:
    /// - Add missing translation (Quick Fix)
    /// - Rename key to similar existing key (Quick Fix)
    /// - Convert string to translation key (Refactor)
    final actions = <lsp.CodeAction?>[];

    if (params.context.diagnostics.isNotEmpty) {
      actions.addAll(_tryAddMissingTranslation(params));
    }
    return actions.whereType<lsp.CodeAction>().toList();
  }

  lsp.CompletionList getCompletion(DocumentPositionRequest r) {
    final lines = r.unit.content.split("\n");
    final line = lines[r.position.line];
    //check if the position is insied some quotes (single or double) and find the string if it is in some
    final quotes = RegExp(r'''['"]''');
    final quoteBefore = line.substring(0, r.position.character).lastIndexOf(quotes);
    final quoteAfter = line.indexOf(quotes, r.position.character);
    //log("Quote before: $quoteBefore, Quote after: $quoteAfter");
    //We are ignoring the possibility of having a string that contains both single and double quotes
    //as any translation keys would probably not contain those
    //TODO: Robust string selection

    if (quoteBefore != -1 && quoteAfter != -1) {
      final start = quoteBefore + 1;
      final end = quoteAfter;
      final key = line.substring(start, end);
      final completions = translationFiles.values
          .expand((file) => file.keys)
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

  List<lsp.Location> getDeclaration(String path, int offset) {
    var calls = translationCallsByFile[path];
    if (calls == null) {
      return [];
    }

    final overlappingCalls = calls.where((call) => offset >= call.invocation.offset && offset <= call.invocation.end);

    final locations = <Location>[];

    for (final overlappingCall in overlappingCalls) {
      for (final translation in overlappingCall.translations) {
        locations.add(translation.location);
      }
    }

    return locations.map((l) => l.toLsp()).toList();
  }

  List<String> getFilesWithUnresolvedTranslations() => translationCallsByFile.entries
      .where((entry) => entry.value.any((call) => !call.isValid))
      .map((entry) => entry.key)
      .toList();

  lsp.Hover? getHoverInfo(lsp.TextDocumentPositionParams params) {
    var calls = translationCallsByFile[params.textDocument.uri.path];
    if (calls == null) {
      return null;
    }
    final overlappingCall = calls.where((call) => call.location.toLsp().range.contains(params.position)).firstOrNull;
    if (overlappingCall == null) {
      return null;
    }

    var text = [];
    for (final translation in overlappingCall.translations) {
      final String value;
      if (translation is JsonLocationString) {
        value = translation.value;
      } else {
        continue;
      }
      //get the closest root path
      final rootPath = rootPaths.reduce((value, element) {
        final commonPrefixLengthValue = value.commonPrefixLength(translation.location.file);
        final commonPrefixLengthElement = element.commonPrefixLength(translation.location.file);
        return commonPrefixLengthValue > commonPrefixLengthElement ? value : element;
      });
      //remove the root path from the file path
      final relativePath = translation.location.file.replaceFirst(rootPath, "");
      text.add("Translation: $value (File: $relativePath)");
    }

    final content = lsp.MarkupContent(
      kind: lsp.MarkupKind.Markdown,
      value: text.join("\n\n"),
    );
    return lsp.Hover(contents: lsp.Either2.t1(content), range: overlappingCall.location.toLsp().range);
  }

  Future<List<lsp.Location>> getReferences(lsp.ReferenceParams params) async {
    if (params.textDocument.uri.path.endsWith(".json")) {
      final translationFile = translationFiles[params.textDocument.uri.path];
      if (translationFile == null) return [];
      //final key = translationFile.locations.value.
      final key = translationFile
          .getFlatKeys()
          .where((k) => k.entry.key.location.toLsp().range.contains(params.position))
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

  SimpleStringLiteral? getSelectedStringLiteral(CompilationUnit unit, int offset, int length) {
    final visitor = SelectedStringVisitor(offset, length);
    unit.accept(visitor);
    final selectedString = visitor.selectedString;
    return selectedString;
  }

  (lsp.Range, SimpleStringLiteral)? getSelectedStringLiteralByRange(String path, lsp.Range selection) {
    final unit = _collection.contextFor(path).currentSession.getParsedUnit(path);
    if (unit is! ParsedUnitResult) {
      return null;
    }
    final lineInfo = unit.lineInfo;
    final (:offset, :length) = rangeToSelection(lineInfo, selection);

    final selectedString = getSelectedStringLiteral(unit.unit, offset, length);
    if (selectedString == null) {
      return null;
    }

    final range = selectionToRange(lineInfo, selectedString.offset, selectedString.length);
    return (range, selectedString);
  }

  List<TranslationLabel> getTranslationLabels(String file) {
    final translationCalls = translationCallsByFile[file];
    if (translationCalls == null) {
      return [];
    }
    final labels = translationCalls
        .where((call) => call.isValid)
        .map((call) {
          final closestTranslation = call.closestTranslation(file);
          if (closestTranslation == null) {
            return null;
          }
          final label = jsonEncode(closestTranslation.accept(JsonValueBuilder()));
          return TranslationLabel(label, call.location.toLsp().range);
        })
        .whereType<TranslationLabel>()
        .toList();

    return labels;
  }

  Future<lsp.Either2<lsp.Range, lsp.PrepareRenameResult>?> prepareRename(lsp.TextDocumentPositionParams params) async {
    if (params.textDocument.uri.path.endsWith(".json")) {
      final translationFile = translationFiles[params.textDocument.uri.path];
      if (translationFile == null) return null;
      final key = translationFile
          .getFlatKeys()
          .where((k) => k.entry.key.location.toLsp().range.contains(params.position))
          .firstOrNull;
      if (key == null) return null;
      final range = key.entry.key.location.toLsp().range;
      final onlyText = lsp.Range(
          start: lsp.Position(line: range.start.line, character: range.start.character + 1),
          end: lsp.Position(line: range.end.line, character: range.end.character - 1));
      return lsp.Either2.t1(onlyText);
    }

    return null;
  }

  ({int offset, int length}) rangeToSelection(LineInfo lineInfo, lsp.Range range) {
    final offset = lineInfo.getOffsetOfLine(range.start.line) + range.start.character;
    final offsetEnd = lineInfo.getOffsetOfLine(range.end.line) + range.end.character;
    final length = offsetEnd - offset;
    return (offset: offset, length: length);
  }

  Future<RenameResponse?> rename(lsp.RenameParams params) async {
    if (params.textDocument.uri.path.endsWith(".json")) {
      final affectedFiles = <String>{params.textDocument.uri.path};

      final translationFile = translationFiles[params.textDocument.uri.path];
      if (translationFile == null) return null;

      FlatKey? key = findTranslationKeyByRange(translationFile, params);
      if (key == null) return null;

      final range = key.entry.key.location.toLsp().range;
      final onlyText = lsp.Range(
          start: lsp.Position(line: range.start.line, character: range.start.character + 1),
          end: lsp.Position(line: range.end.line, character: range.end.character));
      final keyParts = key.fullKey.split(".");
      final newFullKey = [...keyParts.sublist(0, keyParts.length - 1), params.newName].join(".");

      final keyRename = <Uri, List<lsp.TextEdit>>{
        params.textDocument.uri: [lsp.TextEdit(range: onlyText, newText: params.newName)]
      };

      final allEdits = translationCallsByFile.values
          .expand((values) => values)
          .where(
            // TODO(JonathanKohlhas): This is not a clean way to find all the calls that reference the key
            // see doc/rename.md for more
            (call) => call.translationKey == key.fullKey,
          )
          .map((call) {
        final callRange = call.location.toLsp().range;
        final stringLength = call.invocation.target!.length;
        final textRange = lsp.Range(
            start: lsp.Position(line: callRange.start.line, character: callRange.start.character + 1),
            end: lsp.Position(line: callRange.start.line, character: callRange.start.character + stringLength - 1));
        affectedFiles.add(call.location.file);
        return (key: Uri.parse(call.location.file), value: lsp.TextEdit(range: textRange, newText: newFullKey));
      }).fold(keyRename, (acc, edit) {
        if (acc.containsKey(edit.key)) {
          acc[edit.key]!.add(edit.value);
        } else {
          acc[edit.key] = [edit.value];
        }
        return acc;
      });

      return RenameResponse(lsp.WorkspaceEdit(changes: allEdits), affectedFiles.toList());
    }

    return null;
  }

  lsp.Range selectionToRange(LineInfo lineInfo, int offset, int length) {
    final start = lineInfo.getLocation(offset);
    final end = lineInfo.getLocation(offset + length);
    return lsp.Range(
      start: lsp.Position(line: start.lineNumber, character: start.columnNumber),
      end: lsp.Position(line: end.lineNumber, character: end.columnNumber),
    );
  }

  Future<ResolvedUnitResult> _getResolvedUnit(String path) async {
    final context = _collection.contextFor(path);
    final result = await context.currentSession.getResolvedUnit(path);
    if (result is ResolvedUnitResult) {
      return result;
    }
    throw Exception("Could not get resolved unit for $path");
  }

  List<lsp.CodeAction> _tryAddMissingTranslation(lsp.CodeActionParams params) {
    return params.context.diagnostics
        .where((diagnostic) => diagnostic.code == AnalysisErrorCode.noSuchTranslation.name)
        .map((diagnostic) {
          final (range, selectedString) =
              getSelectedStringLiteralByRange(params.textDocument.uri.path, diagnostic.range) ?? (null, null);
          if (range == null ||
              selectedString == null ||
              selectedString.stringValue == null ||
              selectedString.stringValue!.isEmpty) {
            return null;
          }
          final title = "Add missing translation";
          return lsp.CodeAction(
            title: title,
            kind: lsp.CodeActionKind.QuickFix,
            command:
                // TODO(JonathanKohlhas): Define a way to handle the command api
                // maybe a way to register commands to the analyzer
                // could also do this for the features in general
                lsp.Command(
              command: "addTranslation",
              title: title,
              arguments: [
                params.textDocument.uri.toString(),
                range.toJson(),
                selectedString.stringValue,
              ],
            ),
          );
        })
        .whereType<lsp.CodeAction>()
        .toList();

    // if (missingTranslation == null) {
    //   return null;
    // }
    // final title = "Add missing translation";
    // final edit = lsp.WorkspaceEdit(changes: {
    //   Uri.parse(params.textDocument.uri): [lsp.TextEdit(range: range, newText: "\"${selectedString.stringValue}\"")]
    // });
    // return lsp.CodeAction(
    //   title: title,
    //   kind: lsp.CodeActionKind.QuickFix,
    //   diagnostics: [missingTranslation],
    //   edit: edit,
    // );
  }
}

class RenameResponse {
  final List<String> affectedFiles;
  final lsp.WorkspaceEdit edit;
  RenameResponse(this.edit, this.affectedFiles);
}

class SelectedStringVisitor extends GeneralizingAstVisitor<void> {
  final int length;

  final int offset;
  SimpleStringLiteral? selectedString;
  SelectedStringVisitor(this.offset, this.length);

  bool rangeOverlaps(int start, int end) {
    return (start <= offset && end >= offset) || (start <= offset + length && end >= offset + length);
  }

  @override
  void visitStringLiteral(StringLiteral node) {
    final start = node.offset;
    final end = node.end;
    if (node is SimpleStringLiteral && rangeOverlaps(start, end)) {
      selectedString = node;
    }
    super.visitStringLiteral(node);
  }
}
