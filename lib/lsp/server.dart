import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:easy_localization_lsp/analysis/analyzer.dart';
import 'package:easy_localization_lsp/config/config.dart';
import 'package:easy_localization_lsp/lsp/connection.dart';
import 'package:easy_localization_lsp/protocol/labels_provider.dart';
import 'package:easy_localization_lsp/protocol/utils.dart';
import 'package:easy_localization_lsp/util/utils.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:uuid/v4.dart';

class DocumentPositionRequest {
  DocumentPositionRequest(this.path, this.position, this.unit);

  final String path;
  final Position position;
  final ParsedUnitResult unit;
}

class EasyLocalizationLspServer {
  EasyLocalizationLspServer(this.options);

  final EasyLocalizationLspServerOptions options;

  late final EasyLocalizationAnalyzer _analyzer;
  late final ClientCapabilities _clientCapabilities;
  late final AnalysisContextCollection _collection;
  final Map<String, EasyLocalizationAnalysisOptions> _configs = {};
  late final Connection _connection;
  int _overlayModificationStamp = 0;
  final ListQueue<String> _priorityFiles = ListQueue();
  final _fileChangeController = StreamController<List<String>>();
  late final OverlayResourceProvider _resourceProvider;
  late final List<String> rootPaths;
  Socket? _socket;

  Future<void> start() async {
    _connection = await options.connection.initialize();

    _connection.onInitialize(_onInitialize);
    _connection.onDidOpenTextDocument(_onDidOpenTextDocument);
    _connection.onDidCloseTextDocument(_onDidCloseTextDocument);
    _connection.onDidChangeTextDocument(_onDidChangeTextDocument);
    _connection.onDeclaration(_getDeclaration);
    _connection.onDefinition(_getDeclaration);
    _connection.onHover(_onHover);
    _connection.onCompletion(_onCompletion);
    _connection.onReferences(_getReferences);
    _connection.onRequest('textDocument/prepareRename', (params) async {
      var prepareParams = TextDocumentPositionParams.fromJson(params.value);
      return await _onRenamePrepare(prepareParams);
    });
    _connection.onRequest('textDocument/rename', (params) async {
      var renameParams = RenameParams.fromJson(params.value);
      return await _onRename(renameParams);
    });

    await _connection.listen();
    if (_socket != null) {
      await _socket!.close();
    }
  }

  String get _sdkPath {
    final sdkPath = Platform.environment['DART_SDK'];
    if (sdkPath != null) {
      return sdkPath;
    }
    //search in PATH for dart executable
    final paths = Platform.environment['PATH']!.split(Platform.pathSeparator);
    for (final path in paths) {
      final dartPath = [path, 'dart'].join(Platform.pathSeparator);
      if (File(dartPath).existsSync()) {
        return [File(dartPath).parent.absolute.path, 'cache', 'dart-sdk']
            .join(Platform.pathSeparator);
      }
    }

    //use which / where command to find dart executable
    final which = Platform.isWindows ? 'where' : 'which';
    final result = Process.runSync(which, ['dart']);
    if (result.exitCode == 0) {
      return [File(result.stdout.toString().trim()).parent.absolute.path, 'cache', 'dart-sdk']
          .join(Platform.pathSeparator);
    }
    throw Exception("Could not find Dart SDK");
  }

  Future<void> _analyzeFile(String file, AnalysisContext context) async {
    return await Future.microtask(() {
      // _connection.log("Analyzing file: $file");
      try {
        final rootPath = context.contextRoot.root.path;
        final config = _configs[rootPath];
        if (config == null) return;
        if (file.endsWith('.dart')) {
          _analyzer.analyzeFile(context, file);

          _connection.sendDiagnostics(
            PublishDiagnosticsParams(
              diagnostics: _analyzer.getDiagnostics(file).map((e) => e.toLsp()).toList(),
              uri: Uri.file(file),
            ),
          );

          if (_clientCapabilities.experimental
              case {"supportsEasyLocalizationTranslationLabels": true}) {
            final List<TranslationLabel> labels = _analyzer.getTranslationLabels(file);
            _connection.sendTranslationLabels(TranslationLabelNotification(file, labels));
          }
        } else if (config.isTranslationFile(file)) {
          _analyzer.analyzeTranslationFile(context, file);
          _fileChangeController.add(_analyzer.filesWithTranslations);
        }
      } on InconsistentAnalysisException catch (e) {
        _connection.log("""
Inconsistent analysis exception: ${e.message}

Assumed to be non-fatal, probably just running analysis on a file that has just changed. 
""");
      }
    });
  }

  Future<void> _startFileAnalysis() async {
    List<String> files = List.from(_priorityFiles);
    Completer<void> sleep = Completer();

    final subscription = _fileChangeController.stream.listen((newFiles) async {
      files.addAll(newFiles.where((file) => !files.contains(file)));
      sleep.complete();
      sleep = Completer();
    });

    while (!_connection.peer.isClosed) {
      if (files.isEmpty) {
        await sleep.future;
      } else {
        final fileToAnalyze = files.where((file) => file.endsWith(".json")).firstOrNull ??
            files.where((file) => _priorityFiles.contains(file)).firstOrNull ??
            files.first;

        files.remove(fileToAnalyze);
        await _analyzeFile(fileToAnalyze, _collection.contextFor(fileToAnalyze));
      }
    }

    await subscription.cancel();
  }

  Future<Either2<int, String>?> _createProgressToken() async {
    if (_clientCapabilities.window?.workDoneProgress == false) {
      return null;
    }
    final token = Either2<int, String>.t2(UuidV4().generate());
    await _connection.sendRequest('window/workDoneProgress/create', {
      "token": token.toJson(),
    });
    return token;
  }

  Future<Either3<Location, List<Location>, List<LocationLink>>?> _getDeclaration(
      TextDocumentPositionParams param) async {
    final unit = _getParsedUnit(param.textDocument.uri.path);
    final offset = unit.lineInfo.getOffsetOfLine(param.position.line) + param.position.character;
    final List<Location> locations = _analyzer.getDeclaration(param.textDocument.uri.path, offset);

    return Either3.t2(locations);
  }

  Future<List<Location>> _getReferences(ReferenceParams params) async {
    return _analyzer.getReferences(params);
  }

  ParsedUnitResult _getParsedUnit(String path) {
    final context = _collection.contextFor(path);
    final result = context.currentSession.getParsedUnit(path);
    if (result is ParsedUnitResult) {
      return result;
    }
    throw Exception("Could not get parsed unit for $path");
  }

  Future<void> _handleFileChange(String file) async {
    _handleFilesChange([file]);
  }

  Future<void> _handleFilesChange(List<String> files) async {
    final affectedFiles = <String>{};

    // Apply all changes to the contexts
    for (final file in files) {
      for (final context in _collection.contexts) {
        context.changeFile(file);
        affectedFiles.addAll(await context.applyPendingFileChanges());
      }
    }

    // Determine which files need re-analysis
    for (final context in _collection.contexts) {
      final affectedFilesInContext = affectedFiles.where(context.contextRoot.isAnalyzed).toList();

      final translationFiles = files.where(
          (file) => _configs[context.contextRoot.root.path]?.isTranslationFile(file) == true);
      if (translationFiles.isNotEmpty) {
        affectedFilesInContext.addAll(translationFiles);
      }

      _fileChangeController.add(affectedFilesInContext);
    }
  }

  Future<List<CodeAction>> _onCodeAction(CodeActionParams params) {
    return _analyzer.getCodeActions(params);
  }

  Future<CompletionList> _onCompletion(TextDocumentPositionParams params) async {
    return _analyzer.getCompletion(DocumentPositionRequest(
      params.textDocument.uri.path,
      params.position,
      _getParsedUnit(params.textDocument.uri.path),
    ));
  }

  Future<dynamic> _onDidChangeTextDocument(DidChangeTextDocumentParams params) async {
    // _connection.log("onDidChangeTextDocument: ${params.textDocument.uri.path}");
    // var contentChanges = params.contentChanges.map((content) {
    //   return content.map(
    //     (document) => TextDocumentContentChangeEvent(
    //         text: document.text, range: document.range, rangeLength: document.rangeLength),
    //     (document) => TextDocumentContentChangeEvent(text: document.text),
    //   );
    // });
    // _connection.log("onDidChangeTextDocument: ${params.toJson()}");

    final String text = _resourceProvider.getFile(params.textDocument.uri.path).readAsStringSync();
    // _connection.log("original text: $text");
    final String newText = params.contentChanges.fold(text, (text, change) => change.apply(text));
    // _connection.log("new text: $newText");

    _resourceProvider.setOverlay(
      params.textDocument.uri.path,
      content: newText,
      modificationStamp: _overlayModificationStamp++,
    );

    await _handleFileChange(params.textDocument.uri.path);
  }

  Future<dynamic> _onDidCloseTextDocument(DidCloseTextDocumentParams params) async {
    _resourceProvider.removeOverlay(params.textDocument.uri.path);
    _priorityFiles.remove(params.textDocument.uri.path);

    await _handleFileChange(params.textDocument.uri.path);
  }

  Future<dynamic> _onDidOpenTextDocument(DidOpenTextDocumentParams params) async {
    _resourceProvider.setOverlay(
      params.textDocument.uri.path,
      content: params.textDocument.text,
      modificationStamp: _overlayModificationStamp++,
    );
    _priorityFiles.addFirst(params.textDocument.uri.path);
    await _handleFileChange(params.textDocument.uri.path);
  }

  Future<Hover> _onHover(TextDocumentPositionParams params) async {
    return _analyzer.getHoverInfo(params) ?? Hover(contents: Either2.t2(""));
  }

  Future<InitializeResult> _onInitialize(InitializeParams params) async {
    _clientCapabilities = params.capabilities;
    _resourceProvider = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
    rootPaths = params.workspaceFolders?.map((folder) => folder.uri.path).toList() ??
        [params.rootUri?.path ?? params.rootPath ?? Directory.current.absolute.path];
    _collection = AnalysisContextCollection(
      includedPaths: rootPaths,
      resourceProvider: _resourceProvider,
      sdkPath: _sdkPath,
    );
    _analyzer = EasyLocalizationAnalyzer(_collection, rootPaths, _connection.log);

    _connection.log("Initializing analysis");
    _startFileAnalysis();
    for (final context in _collection.contexts) {
      final options = analysisOptionsFromFile(context);
      _configs[context.contextRoot.root.path] = options ?? EasyLocalizationAnalysisOptions();
      _fileChangeController.add(context.contextRoot.analyzedFiles().toList());
    }

    return InitializeResult(
      capabilities: ServerCapabilities(
          textDocumentSync: const Either2.t1(TextDocumentSyncKind.Incremental),
          declarationProvider: Either3.t1(true),
          definitionProvider: Either2.t1(true),
          referencesProvider: Either2.t1(true),
          hoverProvider: Either2.t1(true),
          completionProvider: CompletionOptions(
            resolveProvider: false,
            triggerCharacters: ['.', '"', "'"],
          ),
          renameProvider: Either2.t1(true),
          // codeActionProvider: Either2.t1(true),
          experimental: {
            translationLabelsProvider: true,
          }),
    );
  }

  Future<WorkspaceEdit?> _onRename(RenameParams params) async {
    final resp = await _analyzer.rename(params);
    if (resp != null) {
      _handleFilesChange(resp.affectedFiles);
    }
    return resp?.edit;
  }

  Future<Either2<Range, PrepareRenameResult>?> _onRenamePrepare(
      TextDocumentPositionParams params) async {
    return _analyzer.prepareRename(params);
  }
}

class EasyLocalizationLspServerOptions {
  EasyLocalizationLspServerOptions({
    ConnectionType? connection,
  }) : connection = connection ?? ConnectionType.stdio();

  final ConnectionType connection;
}

// class TextDocumentContentChangeEvent {
//   /// The range of the document that changed.
//   final Range? range;

//   /// The optional length of the range that got replaced.
//   ///
//   /// @deprecated use range instead.
//   final int? rangeLength;

//   /// The new text for the provided range.
//   final String text;

//   TextDocumentContentChangeEvent({required this.text, this.range, this.rangeLength});

//   String apply(String content) {
//     if (range == null) return text;
//     final lineInfo = LineInfo.fromContent(content);
//     final (:offset, :length) = rangeToSelection(lineInfo, range!);
//     return content.replaceRange(offset, length, text);
//   }
// }
extension TextDocumentContentChangeEventApply on TextDocumentContentChangeEvent {
  String apply(String content) {
    return map((replaceRange) {
      final lineInfo = LineInfo.fromContent(content);
      final (:offset, :length) = rangeToSelection(lineInfo, replaceRange.range);
      return content.replaceRange(offset, offset + length, replaceRange.text);
    }, (replaceContent) => replaceContent.text);
  }
}
