import 'package:lsp_server/lsp_server.dart';

class LineInfo {
  late final List<int> lineBreaks;

  LineInfo(String text) {
    lineBreaks = [];
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        lineBreaks.add(i);
      }
    }
  }

  Position getLineColumn(int offset) {
    int line = 0;
    int column = 0;
    for (int i = 0; i < lineBreaks.length; i++) {
      if (lineBreaks[i] > offset) {
        line = i;
        column = offset - lineBreaks[i - 1] - 1;
        break;
      }
    }
    return Position(line: line, character: column);
  }

  int getOffset(Position position) {
    return lineBreaks[position.line] + position.character;
  }
}
