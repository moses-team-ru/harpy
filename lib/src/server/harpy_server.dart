import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// HTTP Server wrapper for Harpy framework
///
/// Provides a high-level interface for starting and managing HTTP servers
/// with support for both HTTP and HTTPS.
class HarpyServer {
  /// Creates a new [HarpyServer] instance.
  /// [host] - The hostname to bind the server to (default: 'localhost').
  /// [port] - The port number to listen on (default: 8080).
  /// [securityContext] - Optional security context for HTTPS.
  /// [shared] - Whether the server is shared (default: false).
  HarpyServer({
    this.host = 'localhost',
    this.port = 8080,
    this.securityContext,
    this.shared = false,
  });
  HttpServer? _server;

  /// Server host
  final String host;

  /// Server port
  final int port;

  /// Security context for HTTPS
  final SecurityContext? securityContext;

  /// Whether the server is shared
  final bool shared;

  /// Start the HTTP server
  Future<void> listen(shelf.Handler handler) async {
    if (securityContext != null) {
      _server = await shelf_io.serve(
        handler,
        host,
        port,
        securityContext: securityContext,
        shared: shared,
      );
    } else {
      _server = await shelf_io.serve(
        handler,
        host,
        port,
        shared: shared,
      );
    }

    final protocol = securityContext != null ? 'https' : 'http';
    print('🚀 Harpy server listening on $protocol://$host:$port');
  }

  /// Stop the server
  Future<void> close({bool force = false}) async {
    if (_server != null) {
      await _server!.close(force: force);
      _server = null;
      print('🛑 Harpy server stopped');
    }
  }

  /// Get server information
  Map<String, dynamic> get info {
    return {
      'host': host,
      'port': port,
      'secure': securityContext != null,
      'running': _server != null,
      'shared': shared,
    };
  }

  /// Check if server is running
  bool get isRunning => _server != null;

  /// Get the underlying HttpServer
  HttpServer? get httpServer => _server;
}
