import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:alpha_x_gym/core/config/api_config.dart';

/// Formatted error representation containing user-facing guidance and dev diagnostics.
class NetworkErrorDetails {
  final String userMessage;
  final String technicalDetails;
  final bool isConnectionError;
  final bool isAuthError;
  final int? statusCode;

  const NetworkErrorDetails({
    required this.userMessage,
    required this.technicalDetails,
    this.isConnectionError = false,
    this.isAuthError = false,
    this.statusCode,
  });

  @override
  String toString() {
    if (kDebugMode && technicalDetails.isNotEmpty) {
      return '$userMessage\n[Debug: $technicalDetails]';
    }
    return userMessage;
  }
}

/// Centralized connection & API error interpreter for Alpha X Gym.
class NetworkExceptions {
  /// Interprets any caught network or HTTP exception into a [NetworkErrorDetails].
  static NetworkErrorDetails handle(dynamic error, {String? requestUrl}) {
    final url = requestUrl ?? ApiConfig.baseUrl;

    // 1. Timeout Exceptions
    if (error is TimeoutException) {
      return NetworkErrorDetails(
        userMessage: 'Connection timed out connecting to the Alpha X server.\n'
            'The server took too long to respond.',
        technicalDetails: 'TimeoutException: Request to $url timed out after ${error.duration?.inSeconds ?? 12}s. '
            'Ensure the backend is running on your Windows PC and not blocked by firewall.',
        isConnectionError: true,
      );
    }

    // 2. Socket / Low-level Connection Exceptions
    if (error is SocketException) {
      final osMsg = error.osError?.message.toLowerCase() ?? '';
      final errorMsg = error.message.toLowerCase();

      if (osMsg.contains('refused') || errorMsg.contains('refused')) {
        return NetworkErrorDetails(
          userMessage: 'Connection refused by Alpha X server.\n'
              'The server is not responding at $url.',
          technicalDetails: 'SocketException: Connection refused ($url). '
              '1) Verify backend is started (`npm run dev`). '
              '2) Verify server is listening on 0.0.0.0:5000 (not just localhost). '
              '3) Check Windows Firewall allows inbound TCP port 5000.',
          isConnectionError: true,
        );
      }

      if (osMsg.contains('unreachable') ||
          osMsg.contains('no route') ||
          errorMsg.contains('unreachable') ||
          errorMsg.contains('failed host lookup')) {
        return NetworkErrorDetails(
          userMessage: 'Unable to reach Alpha X server on Wi-Fi network.\n'
              'Please check your connection or server settings.',
          technicalDetails: 'SocketException: Network unreachable or host lookup failed for $url. '
              'Verify that your mobile device and Windows PC are connected to the SAME Wi-Fi network '
              'and that your Windows LAN IP has not changed.',
          isConnectionError: true,
        );
      }

      return NetworkErrorDetails(
        userMessage: 'Network error connecting to Alpha X server.\n'
            'Please verify your connection and server settings.',
        technicalDetails: 'SocketException: ${error.message} (OS Error: ${error.osError?.message ?? "none"}) on $url',
        isConnectionError: true,
      );
    }

    // 3. Handshake / SSL / TLS Exceptions
    if (error is HandshakeException || error.toString().contains('HandshakeException')) {
      return NetworkErrorDetails(
        userMessage: 'SSL/TLS security negotiation failed.\n'
            'If using local testing, ensure HTTP (not HTTPS) is used with your local IP.',
        technicalDetails: 'HandshakeException: $error while connecting to $url',
        isConnectionError: true,
      );
    }

    // 4. Format / Non-JSON Exceptions (e.g. 502 Bad Gateway HTML)
    if (error is FormatException) {
      return NetworkErrorDetails(
        userMessage: 'Server returned an invalid or unexpected response format.',
        technicalDetails: 'FormatException: Expected JSON response from $url, but received invalid format: ${error.message}',
        isConnectionError: false,
      );
    }

    // 5. Existing application exceptions
    final stringVal = error.toString().replaceAll('Exception: ', '').trim();

    // Check for common HTTP status messages
    if (stringVal.contains('401') || stringVal.toLowerCase().contains('unauthorized')) {
      return NetworkErrorDetails(
        userMessage: 'Authentication failed. Please verify your credentials.',
        technicalDetails: stringVal,
        isAuthError: true,
        statusCode: 401,
      );
    }

    if (stringVal.contains('403') || stringVal.toLowerCase().contains('forbidden')) {
      return NetworkErrorDetails(
        userMessage: 'Access denied. You do not have permission for this resource.',
        technicalDetails: stringVal,
        isAuthError: true,
        statusCode: 403,
      );
    }

    if (stringVal.contains('404') || stringVal.toLowerCase().contains('not found')) {
      return NetworkErrorDetails(
        userMessage: 'Server endpoint was not found ($url).\n'
            'Please verify the server route configuration.',
        technicalDetails: 'HTTP 404: $stringVal',
        isConnectionError: true,
        statusCode: 404,
      );
    }

    // Default fallback
    final isConn = stringVal.toLowerCase().contains('connection') ||
        stringVal.toLowerCase().contains('socket') ||
        stringVal.toLowerCase().contains('reach');

    return NetworkErrorDetails(
      userMessage: stringVal.isNotEmpty ? stringVal : 'Unable to connect to Alpha X Gym server.',
      technicalDetails: 'Unhandled error: $error on $url',
      isConnectionError: isConn,
    );
  }
}
