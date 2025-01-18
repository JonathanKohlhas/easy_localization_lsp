import 'package:easy_localization_lsp/lsp/server.dart';
import 'package:lsp_server/lsp_server.dart';
import 'package:test/test.dart';

void main() {
  group("Incremental Text Changes", () {
    test("Should insert correctly in single line", () {
      final message = '''Hello
This
Is
A
Test
''';
      final TextDocumentContentChangeEvent change = Either2.t1(TextDocumentContentChangeEvent1(
          range: Range(
            start: Position(line: 1, character: 0),
            end: Position(line: 1, character: 0),
          ),
          text: 'World\n'));
      final result = change.apply(message);
      expect(result, equals('''Hello
World
This
Is
A
Test
'''));
    });

    test("Should replace correctly within a single line", () {
      final message = '''Hello
This
Isn't
Right
''';
      final TextDocumentContentChangeEvent change = Either2.t1(TextDocumentContentChangeEvent1(
          range: Range(
            start: Position(line: 2, character: 0),
            end: Position(line: 2, character: 5),
          ),
          text: 'Is'));
      final result = change.apply(message);
      expect(result, equals('''Hello
This
Is
Right
'''));
    });

    test("Should delete correctly within a single line", () {
      final message = '''Hello
This
Isn't
Right
''';
      final TextDocumentContentChangeEvent change = Either2.t1(TextDocumentContentChangeEvent1(
          range: Range(
            start: Position(line: 2, character: 2),
            end: Position(line: 2, character: 5),
          ),
          text: ''));
      final result = change.apply(message);
      expect(result, equals('''Hello
This
Is
Right
'''));
    });

    test("Should replace correctly in multiple lines", () {
      final message = '''Hello
This
Isn't
Bla bla Right
''';
      final TextDocumentContentChangeEvent change = Either2.t1(TextDocumentContentChangeEvent1(
          range: Range(
            start: Position(line: 2, character: 0),
            end: Position(line: 3, character: 8),
          ),
          text: 'Is\n'));
      final result = change.apply(message);
      expect(result, equals('''Hello
This
Is
Right
'''));
    });

    ///
  });
}
