import 'package:lsp_server/lsp_server.dart';

extension ProgressConnection on Connection {
  void sendProgressBegin(Either2<int, String>? token, WorkDoneProgressBegin begin) {
    if (token == null) return;
    sendNotification('\$/progress', ProgressParams(token: token, value: begin).toJson());
  }

  void sendProgressDone(Either2<int, String>? token, WorkDoneProgressEnd end) {
    if (token == null) return;
    sendNotification('\$/progress', ProgressParams(token: token, value: end).toJson());
  }

  void sendProgressReport(Either2<int, String>? token, WorkDoneProgressReport report) {
    if (token == null) return;
    sendNotification('\$/progress', ProgressParams(token: token, value: report).toJson());
  }
}
