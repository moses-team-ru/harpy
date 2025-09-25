// ignore_for_file: avoid_returning_this

import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;

/// Harpy HTTP Response wrapper
///
/// Provides convenient methods for creating HTTP responses with proper
/// headers and content types.
class Response {
  final Map<String, String> _headers = {};
  int _statusCode = 200;

  /// Set response status code
  Response status(int statusCode) {
    _statusCode = statusCode;
    return this;
  }

  /// Add a header to the response
  Response header(String name, String value) {
    _headers[name] = value;
    return this;
  }

  /// Set multiple headers
  Response headers(Map<String, String> headers) {
    _headers.addAll(headers);
    return this;
  }

  /// Send JSON response
  shelf.Response json(Object? data, {int? statusCode}) {
    final code = statusCode ?? _statusCode;
    final body = data != null ? jsonEncode(data) : '{}';

    return shelf.Response(
      code,
      body: body,
      headers: {
        ..._headers,
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
    );
  }

  /// Send plain text response
  shelf.Response text(String text, {int? statusCode}) {
    final code = statusCode ?? _statusCode;

    return shelf.Response(
      code,
      body: text,
      headers: {
        ..._headers,
        HttpHeaders.contentTypeHeader: 'text/plain; charset=utf-8',
      },
    );
  }

  /// Send HTML response
  shelf.Response html(String html, {int? statusCode}) {
    final code = statusCode ?? _statusCode;

    return shelf.Response(
      code,
      body: html,
      headers: {
        ..._headers,
        HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
      },
    );
  }

  /// Send empty response with status code
  shelf.Response empty({int? statusCode}) {
    final code = statusCode ?? _statusCode;

    return shelf.Response(code, headers: _headers);
  }

  /// Send redirect response
  shelf.Response redirect(String location, {int statusCode = 302}) =>
      shelf.Response(
        statusCode,
        headers: {..._headers, HttpHeaders.locationHeader: location},
      );

  /// Send file response
  shelf.Response file(File file, {int? statusCode, String? contentType}) {
    final code = statusCode ?? _statusCode;
    final mimeType = contentType ?? _inferContentType(file.path);

    return shelf.Response(
      code,
      body: file.readAsStringSync(),
      headers: {..._headers, HttpHeaders.contentTypeHeader: mimeType},
    );
  }

  /// Common status code helpers
  /// OK status [200]
  shelf.Response ok(Object? data) => json(data, statusCode: 200);

  /// Created status [201]
  shelf.Response created(Object? data) => json(data, statusCode: 201);

  /// No Content status [204]
  shelf.Response noContent() => empty(statusCode: 204);

  /// Bad Request status [400]
  shelf.Response badRequest(Object? error) => json(error, statusCode: 400);

  /// Unauthorized status [401]
  shelf.Response unauthorized(Object? error) => json(error, statusCode: 401);

  /// Forbidden status [403]
  shelf.Response forbidden(Object? error) => json(error, statusCode: 403);

  /// Not Found status [404]
  shelf.Response notFound(Object? error) => json(error, statusCode: 404);

  /// Method Not Allowed status [405]
  shelf.Response methodNotAllowed(Object? error) =>
      json(error, statusCode: 405);

  /// Internal Server Error status [500]
  shelf.Response internalServerError(Object? error) =>
      json(error, statusCode: 500);

  /// Infer content type from file extension
  String _inferContentType(String filePath) {
    final extension = filePath.split('.').lastOrNull?.toLowerCase();

    switch (extension) {
      case 'html':
      case 'htm':
        return 'text/html';
      case 'css':
        return 'text/css';
      case 'js':
        return 'application/javascript';
      case 'json':
        return 'application/json';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
