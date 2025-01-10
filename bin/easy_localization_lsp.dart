import 'package:easy_localization_lsp/easy_localization_lsp.dart'
    as easy_localization;

Future<void> main() async {
  await easy_localization.LSPServer().start();
}
