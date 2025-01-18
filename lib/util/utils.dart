import 'package:analyzer/source/line_info.dart';
import 'package:lsp_server/lsp_server.dart' as lsp;

// Future<void> suspendToScheduler() async {
//   // await Future.microtask(Duration(microseconds: 1), () {});
//   // scheduleMicrotask(callback)
// }

({int offset, int length}) rangeToSelection(LineInfo lineInfo, lsp.Range range) {
  final offset = lineInfo.getOffsetOfLine(range.start.line) + range.start.character;
  final offsetEnd = lineInfo.getOffsetOfLine(range.end.line) + range.end.character;
  final length = offsetEnd - offset;
  return (offset: offset, length: length);
}
