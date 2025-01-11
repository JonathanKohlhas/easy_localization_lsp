import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:easy_localization_lsp/analysis/analyzer.dart';
import 'package:easy_localization_lsp/config/config.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:uuid/v4.dart';

class LSPServer {
  late final Connection _connection;
  late final OverlayResourceProvider _resourceProvider;
  late final AnalysisContextCollection _collection;
  final ListQueue<String> _priorityFiles = ListQueue();
  late final EasyLocalizationAnalyzer _analyzer = EasyLocalizationAnalyzer(_log);
  final Map<String, EasyLocalizationAnalysisOptions> _configs = {};
  late final ClientCapabilities _clientCapabilities;

  int _overlayModificationStamp = 0;

  Future<void> start() async {
    // _connection = Connection(stdin, stdout);
    final socket = await Socket.connect('localhost', 54536);
    _connection = Connection(
      socket,
      socket,
    );

    _connection.onInitialize(_onInitialize);
    _connection.onDidOpenTextDocument(_onDidOpenTextDocument);
    _connection.onDidCloseTextDocument(_onDidCloseTextDocument);
    _connection.onDidChangeTextDocument(_onDidChangeTextDocument);
    _connection.onDeclaration(_getDeclaration);
    _connection.onDefinition(_getDeclaration);
    _connection.onHover(_onHover);
    _connection.onCompletion(_onCompletion);
    _connection.onReferences(_getReferences);
    //_connection.onRenameRequest(_onRename);
    //_connection.onPrepareRename(_onRenamePrepare);
    _connection.onRequest('textDocument/prepareRename', (params) async {
      var prepareParams = TextDocumentPositionParams.fromJson(params.value);
      return await _onRenamePrepare(prepareParams);
    });
    _connection.onRequest('textDocument/rename', (params) async {
      var renameParams = RenameParams.fromJson(params.value);
      return await _onRename(renameParams);
    });
    await _connection.listen();
  }

  String findSdkPath() {
    final sdkPath = Platform.environment['DART_SDK'];
    if (sdkPath != null) {
      return sdkPath;
    }
    //search in PATH for dart executable
    final paths = Platform.environment['PATH']!.split(Platform.pathSeparator);
    for (final path in paths) {
      final dartPath = [path, 'dart'].join(Platform.pathSeparator);
      if (File(dartPath).existsSync()) {
        return [File(dartPath).parent.absolute.path, 'cache', 'dart-sdk'].join(Platform.pathSeparator);
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

  Future<InitializeResult> _onInitialize(InitializeParams params) async {
    _clientCapabilities = params.capabilities;
    _resourceProvider = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
    _collection = AnalysisContextCollection(
      includedPaths:
          //[Directory.current.absolute.path],
          params.workspaceFolders?.map((folder) => folder.uri.path).toList() ??
              [params.rootUri?.path ?? params.rootPath ?? Directory.current.absolute.path],
      resourceProvider: _resourceProvider,
      sdkPath: findSdkPath(),
    );

    Future.delayed(Duration.zero, () async {
      for (final context in _collection.contexts) {
        final options = analysisOptionsFromFile(context);
        _configs[context.contextRoot.root.path] = options ?? EasyLocalizationAnalysisOptions();
        await _analyzeFiles(context.contextRoot.analyzedFiles().toList(), context);
      }
    });
    return InitializeResult(
      capabilities: ServerCapabilities(
        textDocumentSync: const Either2.t1(TextDocumentSyncKind.Full),
        declarationProvider: Either3.t1(true),
        definitionProvider: Either2.t1(true),
        referencesProvider: Either2.t1(true),
        hoverProvider: Either2.t1(true),
        completionProvider: CompletionOptions(
          resolveProvider: false,
          triggerCharacters: ['.', '"'],
        ),
        renameProvider: Either2.t1(true),
      ),
    );
  }

  void _showMessage(String message) {
    _connection.sendNotification(
      'window/showMessage',
      ShowMessageParams(
        message: message,
        type: MessageType.Warning,
      ).toJson(),
    );
  }

  void _log(String message) {
    _connection.sendNotification(
      'window/logMessage',
      LogMessageParams(
        message: message,
        type: MessageType.Info,
      ).toJson(),
    );
  }

  void _startProgress(Either2<int, String> token, WorkDoneProgressBegin begin) {
    _connection.sendNotification('\$/progress', ProgressParams(token: token, value: begin).toJson());
  }

  void _reportProgress(Either2<int, String> token, WorkDoneProgressReport report) {
    _connection.sendNotification('\$/progress', ProgressParams(token: token, value: report).toJson());
  }

  void _endProgress(Either2<int, String> token, WorkDoneProgressEnd end) {
    _connection.sendNotification('\$/progress', ProgressParams(token: token, value: end).toJson());
  }

  Future<Either2<int, String>> _createProgressToken() async {
    if (_clientCapabilities.window?.workDoneProgress == false) {
      throw Exception("Client does not support progress reporting");
    }
    final token = Either2<int, String>.t2(UuidV4().generate());
    await _connection.sendRequest('window/workDoneProgress/create', {
      "token": token.toJson(),
    });
    return token;
  }

  Future<void> _analyzeFiles(List<String> files, AnalysisContext context) async {
    final token = await _createProgressToken();
    _startProgress(
        token,
        WorkDoneProgressBegin(
          title: 'Analyzing files',
          cancellable: false,
          percentage: 0,
          message: "Easy Localization Analyzing files",
        ));

    List<String> jsonFiles = files.where((file) => file.endsWith('.json')).toList();
    List<String> priorityFiles =
        files.where((file) => _priorityFiles.contains(file) && !jsonFiles.contains(file)).toList();
    List<String> otherFiles =
        files.where((file) => !_priorityFiles.contains(file) && !jsonFiles.contains(file)).toList();

    for (final (i, file) in jsonFiles.indexed) {
      await _analyzeFile(file, context);
      _reportProgress(
          token,
          WorkDoneProgressReport(
            cancellable: false,
            percentage: ((i / files.length) * 100).round(),
            message: "Easy Localization Analyzing files",
          ));
    }

    for (final (i, file) in priorityFiles.indexed) {
      await _analyzeFile(file, context);
      _reportProgress(
          token,
          WorkDoneProgressReport(
            cancellable: false,
            percentage: ((i + jsonFiles.length) / files.length * 100).round(),
            message: "Easy Localization Analyzing files",
          ));
    }

    for (final (i, file) in otherFiles.indexed) {
      await _analyzeFile(file, context);
      _reportProgress(
          token,
          WorkDoneProgressReport(
            cancellable: false,
            percentage: ((i + jsonFiles.length + priorityFiles.length) / files.length * 100).round(),
            message: "Easy Localization Analyzing files",
          ));
    }

    _endProgress(token, WorkDoneProgressEnd(message: 'Analysis complete'));
  }

  Future<void> _analyzeFile(String file, AnalysisContext context) async {
    try {
      final rootPath = context.contextRoot.root.path;
      final config = _configs[rootPath];
      if (config == null) return;
      if (file.endsWith('.dart')) {
        final errors = _analyzer.analyzeFile(context, file);

        _connection.sendDiagnostics(
          PublishDiagnosticsParams(
            diagnostics: errors.map((e) => e.toLsp()).toList(),
            uri: Uri.file(file),
          ),
        );

        _connection.sendDiagnostics(
          PublishDiagnosticsParams(
            diagnostics: errors.map((e) => e.toLsp()).toList(),
            uri: Uri.file(file),
          ),
        );
      } else if (config.isTranslationFile(file)) {
        _analyzer.analyzeTranslationFile(context, file);
        final dartFiles = context.contextRoot.analyzedFiles().where((f) {
          return f.endsWith('.dart');
        }).toList();
        _analyzeFiles(dartFiles, context);
      }
    } on InconsistentAnalysisException catch (e) {
      _log("""
Inconsistent analysis exception: ${e.message}

Assumed to be non-fatal, probably just running analysis on a file that has just changed. 
""");
    }
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

  Future<dynamic> _onDidCloseTextDocument(DidCloseTextDocumentParams params) async {
    _resourceProvider.removeOverlay(params.textDocument.uri.path);
    _priorityFiles.remove(params.textDocument.uri.path);

    await _handleFileChange(params.textDocument.uri.path);
  }

  Future<dynamic> _onDidChangeTextDocument(DidChangeTextDocumentParams params) async {
    //_showMessage("Document changed ${params.textDocument.uri.path}");
    /*  var contentChanges = params.contentChanges
        .map((e) => TextDocumentContentChangeEvent2.fromJson(
            e.toJson() as Map<String, dynamic>))
        .toList();*/

    var contentChanges = params.contentChanges.map((content) {
      return content.map(
        (document) => TextDocumentContentChangeEvent2(text: document.text),
        (document) => document,
      );
    });

    _resourceProvider.setOverlay(
      params.textDocument.uri.path,
      content: contentChanges.first.text,
      modificationStamp: _overlayModificationStamp++,
    );

    await _handleFileChange(params.textDocument.uri.path);
  }

  Future<void> _handleFileChange(String file) async {
    _handleFilesChange([file]);
  }

  Future<void> _handleFilesChange(List<String> files) async {
    final affectedFiles = <String>{};
    for (final file in files) {
      for (final context in _collection.contexts) {
        context.changeFile(file);
        affectedFiles.addAll(await context.applyPendingFileChanges());
      }
    }
    for (final context in _collection.contexts) {
      final affectedFilesInContext = affectedFiles.where(context.contextRoot.isAnalyzed).toList(growable: false);
      if (affectedFilesInContext.isEmpty) {
        final translationFiles =
            files.where((file) => _configs[context.contextRoot.root.path]?.isTranslationFile(file) == true);
        if (translationFiles.isNotEmpty) {
          await _analyzeFiles(translationFiles.toList(), context);
        }
      } else {
        await _analyzeFiles(affectedFilesInContext, context);
      }
    }
  }

  Future<ResolvedUnitResult> getResolvedUnit(String path) async {
    final context = _collection.contextFor(path);
    final result = await context.currentSession.getResolvedUnit(path);
    if (result is ResolvedUnitResult) {
      return result;
    }
    throw Exception("Could not get resolved unit for $path");
  }

  Future<Either3<Location, List<Location>, List<LocationLink>>?> _getDeclaration(
      TextDocumentPositionParams param) async {
    final unit = await getResolvedUnit(param.textDocument.uri.path);
    final offset = unit.lineInfo.getOffsetOfLine(param.position.line) + param.position.character;
    final List<Location> locations = _analyzer.getDeclaration(param.textDocument.uri.path, offset);

    return Either3.t2(locations);
  }

  Future<Hover> _onHover(TextDocumentPositionParams params) async {
    return _analyzer.getHoverInfo(params) ?? Hover(contents: Either2.t2(""));
  }

  Future<CompletionList> _onCompletion(TextDocumentPositionParams params) async {
    return _analyzer.getCompletion(DocumentPositionRequest(
      params.textDocument.uri.path,
      params.position,
      await getResolvedUnit(params.textDocument.uri.path),
    ));
  }

  Future<WorkspaceEdit?> _onRename(RenameParams params) async {
    final resp = await _analyzer.rename(params);
    if (resp != null) {
      _handleFilesChange(resp.affectedFiles);
    }
    return resp?.edit;
  }

  Future<Either2<Range, PrepareRenameResult>?> _onRenamePrepare(TextDocumentPositionParams params) async {
    return _analyzer.prepareRename(params);
  }

  Future<List<Location>> _getReferences(ReferenceParams params) async {
    return _analyzer.getReferences(params);
  }
}

class DocumentPositionRequest {
  final String path;
  final Position position;
  final ResolvedUnitResult unit;

  DocumentPositionRequest(this.path, this.position, this.unit);
}
