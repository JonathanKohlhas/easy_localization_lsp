import 'package:lsp_server/lsp_server.dart';

extension LogConnection on Connection {
  void log(String message) {
    sendNotification(
      'window/logMessage',
      LogMessageParams(
        message: message,
        type: MessageType.Info,
      ).toJson(),
    );
  }

  void showMessage(String message) {
    sendNotification(
      'window/showMessage',
      ShowMessageParams(
        message: message,
        type: MessageType.Info,
      ).toJson(),
    );
  }
}
