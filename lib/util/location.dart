import 'package:lsp_server/lsp_server.dart' as lsp;

extension ComparePosition on lsp.Position {
  bool operator <=(lsp.Position other) {
    return line < other.line ||
        (line == other.line && character <= other.character);
  }

  bool operator >=(lsp.Position other) {
    return line > other.line ||
        (line == other.line && character >= other.character);
  }

  bool operator <(lsp.Position other) {
    return line < other.line ||
        (line == other.line && character < other.character);
  }

  bool operator >(lsp.Position other) {
    return line > other.line ||
        (line == other.line && character > other.character);
  }
}

extension CompareRange on lsp.Range {
  bool contains(lsp.Position position) {
    return start <= position && end >= position;
  }

  bool overlaps(lsp.Range other) {
    return start <= other.end && end >= other.start;
  }
}

extension CopyWithLocation on lsp.Location {
  lsp.Location copyWith({
    lsp.Position? start,
    lsp.Position? end,
  }) {
    return lsp.Location(
      uri: uri,
      range: lsp.Range(
        start: start ?? range.start,
        end: end ?? range.end,
      ),
    );
  }
}

extension CopyWithRange on lsp.Range {
  lsp.Range copyWith({
    lsp.Position? start,
    lsp.Position? end,
  }) {
    return lsp.Range(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

class Location {
  final String file;
  final int offset;
  final int length;
  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;

  Location(
    this.file,
    this.offset,
    this.length,
    this.startLine,
    this.startColumn, {
    int? endLine,
    int? endColumn,
  })  : endLine = endLine ?? startLine,
        endColumn = endColumn ?? startColumn + length;

  Location operator -(Location to) {
    final from = this;
    return Location(
      from.file,
      from.offset,
      (to.offset + to.length) - from.offset,
      from.startLine,
      from.startColumn,
      endLine: to.startLine,
      endColumn: to.startColumn,
    );
  }

  bool overlapsRange(int offset, int length) {
    return offset <= this.offset + this.length &&
        offset + length >= this.offset;
  }

  lsp.Location toLsp() {
    return lsp.Location(
      uri: Uri.file(file),
      range: lsp.Range(
        start: lsp.Position(line: startLine - 1, character: startColumn - 1),
        end: lsp.Position(line: endLine - 1, character: endColumn - 1),
      ),
    );
  }
}
