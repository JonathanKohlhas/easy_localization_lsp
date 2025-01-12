import 'dart:async';
import 'dart:io';

import 'package:lsp_server/lsp_server.dart';

abstract class ConnectionType {
  factory ConnectionType.socket(int port) => SocketConnection(port);

  factory ConnectionType.stdio() => StdioConnection();

  FutureOr<Connection> initialize();
}

class SocketConnection implements ConnectionType {
  const SocketConnection(this.port);

  final int port;

  @override
  Future<Connection> initialize() async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    return Connection(socket, socket);
  }
}

class StdioConnection implements ConnectionType {
  const StdioConnection();

  @override
  Connection initialize() {
    return Connection(stdin, stdout);
  }
}
