import 'dart:collection';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:easy_localization_lsp/util/line_info.dart';
import 'package:lsp_server/lsp_server.dart';

class LSPServer {
  late final Connection _connection;
  late final OverlayResourceProvider _resourceProvider;
  late final AnalysisContextCollection _collection;
  final ListQueue<String> _priorityFiles = ListQueue();

  Future<void> start() async {
    _connection = Connection(stdin, stdout);

    _connection.onInitialize(_onInitialize);
    _connection.onDidOpenTextDocument(_onDidOpenTextDocument);
    _connection.onDidCloseTextDocument(_onDidCloseTextDocument);
    _connection.onDidChangeTextDocument(_onDidChangeTextDocument);
    await _connection.listen();
  }

  Future<InitializeResult> _onInitialize(InitializeParams params) async {
    _resourceProvider =
        OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);

    _collection = AnalysisContextCollection(
      includedPaths:
          //[Directory.current.absolute.path],
          params.workspaceFolders?.map((folder) => folder.uri.path).toList() ??
              [
                params.rootUri?.path ??
                    params.rootPath ??
                    Directory.current.absolute.path
              ],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    for (final context in _collection.contexts) {
      _analyzeFiles(context.contextRoot.analyzedFiles().toList(), context);
    }

    return InitializeResult(
      capabilities: ServerCapabilities(
        // In this example we are using the Full sync mode. This means the
        // entire document is sent in each change notification.
        textDocumentSync: const Either2.t1(TextDocumentSyncKind.Full),
        hoverProvider: Either2.t1(true),
      ),
    );
  }

  Future<void> _analyzeFiles(
      List<String> files, AnalysisContext context) async {
    List<String> priorityFiles =
        files.where((file) => _priorityFiles.contains(file)).toList();
    List<String> otherFiles =
        files.where((file) => !_priorityFiles.contains(file)).toList();

    for (final file in priorityFiles) {
      await _analyzeFile(file, context);
    }

    for (final file in otherFiles) {
      await _analyzeFile(file, context);
    }
  }

  Future<void> _analyzeFile(String file, AnalysisContext context) async {
    var diagnostics = _validateTextDocument(
      _resourceProvider.getFile(file).readAsStringSync(),
      file,
    );

    _connection.sendDiagnostics(
      PublishDiagnosticsParams(
        diagnostics: diagnostics,
        uri: Uri.file(file),
      ),
    );
  }

  Future<dynamic> _onDidOpenTextDocument(
      DidOpenTextDocumentParams params) async {
    _resourceProvider.setOverlay(
      params.textDocument.uri.path,
      content: params.textDocument.text,
      modificationStamp: 0,
    );
    _priorityFiles.addFirst(params.textDocument.uri.path);
/*    // Our custom validation logic
    var diagnostics = _validateTextDocument(
      params.textDocument.text,
      params.textDocument.uri.toString(),
    );*/

    final affectedFiles = await _collection
        .contextFor(params.textDocument.uri.path)
        .applyPendingFileChanges();

    await _analyzeFiles(
        affectedFiles, _collection.contextFor(params.textDocument.uri.path));

    // Send back an event notifying the client of issues we want them to render.
    // To clear issues the server is responsible for sending an empty list.
    /* _connection.sendDiagnostics(
      PublishDiagnosticsParams(
        diagnostics: diagnostics,
        uri: params.textDocument.uri,
      ),
    );*/
  }

  Future<dynamic> _onDidCloseTextDocument(
      DidCloseTextDocumentParams params) async {
    _resourceProvider.removeOverlay(params.textDocument.uri.path);
    _priorityFiles.remove(params.textDocument.uri.path);
  }

  Future<dynamic> _onDidChangeTextDocument(
      DidChangeTextDocumentParams params) async {
    // We extract the document changes.
    var contentChanges = params.contentChanges
        .map((e) => TextDocumentContentChangeEvent2.fromJson(
            e.toJson() as Map<String, dynamic>))
        .toList();

    _resourceProvider.setOverlay(
      params.textDocument.uri.path,
      content: contentChanges.last.text,
      modificationStamp: 0,
    );

    final affectedFiles = await _collection
        .contextFor(params.textDocument.uri.path)
        .applyPendingFileChanges();

    await _analyzeFiles(
        affectedFiles, _collection.contextFor(params.textDocument.uri.path));

    /*// Our custom validation logic
    var diagnostics = _validateTextDocument(
      contentChanges.last.text,
      params.textDocument.uri.toString(),
    );

    // Send back an event notifying the client of issues we want them to render.
    // To clear issues the server is responsible for sending an empty list.
    _connection.sendDiagnostics(
      PublishDiagnosticsParams(
        diagnostics: diagnostics,
        uri: params.textDocument.uri,
      ),
    );*/
  }

  List<Diagnostic> _validateTextDocument(String text, String sourcePath) {
    // detect occurences of "somestring".tr(...) and "somestring".plural(...) with possible line breaks
    // "thing".tr()
    RegExp pattern =
        //RegExp(r'tr', multiLine: true);
        RegExp(r'"[^"]*"\s*\.(tr|plural)\s*\([^\)]*\)', multiLine: true);

    LineInfo lineInfo = LineInfo(text);

    final matches = pattern.allMatches(text);

    final diagnostics = _convertPatternToDiagnostic(matches, lineInfo).toList();
    return diagnostics;
  }

  Iterable<Diagnostic> _convertPatternToDiagnostic(
      Iterable<RegExpMatch> matches, LineInfo info) {
    return matches.map((match) => Diagnostic(
          message:
              '${match.input.substring(match.start, match.end)} is a translation call.',
          range: Range(
              start: info.getLineColumn(match.start),
              end: info.getLineColumn(match.end)),
        ));
  }
}
