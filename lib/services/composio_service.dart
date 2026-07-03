import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/env_config.dart';

/// Supported automation services with their display info and NLP keywords.
class ComposioService {
  final String id;
  final String name;
  final List<String> keywords;
  final int colorValue;

  const ComposioService({
    required this.id,
    required this.name,
    required this.keywords,
    required this.colorValue,
  });
}

/// All 13 supported automation services.
const List<ComposioService> kComposioServices = [
  ComposioService(id: 'github', name: 'GitHub', keywords: ['github', 'repo', 'commit', 'pull request', 'issue'], colorValue: 0xFF6e40c9),
  ComposioService(id: 'gmail', name: 'Gmail', keywords: ['gmail', 'email', 'mail', 'send email'], colorValue: 0xFFEA4335),
  ComposioService(id: 'telegram', name: 'Telegram', keywords: ['telegram', 'tg', 'message'], colorValue: 0xFF0088cc),
  ComposioService(id: 'twitter', name: 'Twitter', keywords: ['twitter', 'tweet', 'x.com'], colorValue: 0xFF1DA1F2),
  ComposioService(id: 'instagram', name: 'Instagram', keywords: ['instagram', 'ig', 'story', 'reel'], colorValue: 0xFFE4405F),
  ComposioService(id: 'facebook', name: 'Facebook', keywords: ['facebook', 'fb', 'post', 'page'], colorValue: 0xFF1877F2),
  ComposioService(id: 'whatsapp', name: 'WhatsApp', keywords: ['whatsapp', 'wa'], colorValue: 0xFF25D366),
  ComposioService(id: 'googlechrome', name: 'Chrome', keywords: ['chrome', 'browser', 'open url'], colorValue: 0xFF4285F4),
  ComposioService(id: 'googledrive', name: 'Google Drive', keywords: ['drive', 'upload', 'file', 'folder'], colorValue: 0xFF0F9D58),
  ComposioService(id: 'discord', name: 'Discord', keywords: ['discord', 'server', 'channel'], colorValue: 0xFF5865F2),
  ComposioService(id: 'linkedin', name: 'LinkedIn', keywords: ['linkedin', 'profile', 'connection', 'job'], colorValue: 0xFF0A66C2),
  ComposioService(id: 'reddit', name: 'Reddit', keywords: ['reddit', 'subreddit', 'post', 'upvote'], colorValue: 0xFFFF4500),
  ComposioService(id: 'googleheets', name: 'Google Sheets', keywords: ['sheet', 'spreadsheet', 'cell'], colorValue: 0xFF0F9D58),
];

/// Service that manages Composio MCP integration:
/// - Opens Composio login via native Chrome Custom Tab
/// - Listens for deep-link auth code callback
/// - Exchanges auth code for Bearer token via backend
/// - Manages 13 service connections (connect/disconnect/status)
/// - Sends automation instructions via natural language
class ComposioServiceManager {
  static const MethodChannel _channel = MethodChannel('stremini.composio');
  static const EventChannel _eventChannel = EventChannel('stremini.composio/events');

  static const String _tokenKey = 'composio_token';
  static const String _connectedKey = 'composio_connected';

  StreamSubscription? _eventSub;
  String? _cachedToken;
  bool _isConnected = false;

  /// Connection status per service: serviceId → bool
  final Map<String, bool> _serviceStatus = {};

  String? get token => _cachedToken;
  bool get isConnected => _isConnected;
  Map<String, bool> get serviceStatus => Map.unmodifiable(_serviceStatus);

  /// Initialize — restore saved connection state and listen for deep-link events.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isConnected = prefs.getBool(_connectedKey) ?? false;

    if (Platform.isAndroid) {
      try {
        _cachedToken = await _channel.invokeMethod<String?>('getComposioToken');
        if (_cachedToken != null) _isConnected = true;
      } catch (_) {}
    } else {
      _cachedToken = prefs.getString(_tokenKey);
    }

    _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map && event['event'] == 'auth_code') {
        final code = event['code'] as String?;
        if (code != null) {
          _exchangeCodeForToken(code);
        }
      }
    });
  }

  void dispose() {
    _eventSub?.cancel();
  }

  /// Open Composio login page in Chrome Custom Tab (native).
  Future<void> openConnectPage() async {
    if (!Platform.isAndroid) {
      debugPrint('Composio: only supported on Android');
      return;
    }
    try {
      await _channel.invokeMethod('openComposioConnect');
    } catch (e) {
      debugPrint('Composio: error opening connect page — $e');
      rethrow;
    }
  }

  /// Connect a specific service via Composio managed auth.
  Future<void> connectService(String serviceId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('connectComposioService', {'serviceId': serviceId});
    } catch (e) {
      debugPrint('Composio: error connecting $serviceId — $e');
    }
  }

  /// Disconnect a specific service.
  Future<void> disconnectService(String serviceId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('disconnectComposioService', {'serviceId': serviceId});
      _serviceStatus[serviceId] = false;
    } catch (e) {
      debugPrint('Composio: error disconnecting $serviceId — $e');
    }
  }

  /// Refresh all service connection statuses from Composio API.
  Future<void> refreshServiceStatuses() async {
    if (!isConnected) return;
    try {
      final result = await _channel.invokeMethod<Map>('getConnectedServices');
      if (result != null) {
        _serviceStatus.clear();
        result.forEach((key, value) {
          _serviceStatus[key.toString()] = value == true;
        });
      }
    } catch (_) {}
  }

  /// Detect which service a user message is likely about.
  ComposioService? detectService(String message) {
    final lower = message.toLowerCase();
    for (final svc in kComposioServices) {
      if (svc.keywords.any((kw) => lower.contains(kw))) {
        return svc;
      }
    }
    return null;
  }

  /// Exchange the auth code (received via deep-link) for a Bearer token.
  Future<void> _exchangeCodeForToken(String authCode) async {
    try {
      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/composio/exchange'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authCode': authCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          await _saveToken(token);
          debugPrint('Composio: token exchanged and saved');
        }
      } else {
        debugPrint('Composio: exchange failed — ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Composio: exchange error — $e');
    }
  }

  /// Save token on native side (encrypted) and cache connection state.
  Future<void> _saveToken(String token) async {
    _cachedToken = token;
    _isConnected = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, true);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('saveComposioToken', {'token': token});
      } catch (_) {}
    }
  }

  /// Disconnect Composio — clear all stored tokens.
  Future<void> disconnect() async {
    _cachedToken = null;
    _isConnected = false;
    _serviceStatus.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.setBool(_connectedKey, false);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('saveComposioToken', {'token': ''});
      } catch (_) {}
    }
  }

  /// Send an automation instruction via Composio.
  /// Returns the AI response string, or an error message.
  Future<String> sendAutomationInstruction(String instruction) async {
    if (_cachedToken == null) {
      return 'Composio is not connected. Go to Settings → Connect Automations first.';
    }
    try {
      final response = await http.post(
        Uri.parse('${EnvConfig.baseUrl}/composio/automate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_cachedToken',
        },
        body: jsonEncode({
          'instruction': instruction,
          'mcpUrl': 'https://connect.composio.dev/mcp',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['response'] ?? data['message'] ?? data['result'] ?? 'Done.').toString();
      }
      if (response.statusCode == 401) {
        await disconnect();
        return 'Composio session expired. Please reconnect in Settings.';
      }
      return 'Automation failed. Please try again.';
    } catch (e) {
      return 'Network error. Please check your connection and try again.';
    }
  }

  /// Get the MCP URL (hardcoded, for reference).
  Future<String> getMcpUrl() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod('getComposioMcpUrl') as String? ??
            'https://connect.composio.dev/mcp';
      } catch (_) {}
    }
    return 'https://connect.composio.dev/mcp';
  }
}