import 'package:args/args.dart';
import 'package:easy_localization_lsp/easy_localization_lsp.dart' as easy_localization;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser();
  parser.addOption('socket');
  parser.addFlag('stdio');
  final args = parser.parse(arguments);
  final port = args['socket'] != null ? int.parse(args['socket']) : null;
  final stdio = args['stdio'] == true;

  if (stdio && port != null) {
    throw Exception('Cannot specify both --socket and --stdio');
  }

  final easy_localization.ConnectionType connection;
  if (stdio) {
    connection = easy_localization.ConnectionType.stdio();
  } else if (port != null) {
    connection = easy_localization.ConnectionType.socket(port);
  } else {
    connection = easy_localization.ConnectionType.stdio();
  }

  await easy_localization.EasyLocalizationLspServer(easy_localization.EasyLocalizationLspServerOptions(
    connection: connection,
  )).start();
}
