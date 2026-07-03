import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  ComposioService(id: 'github', name: 'GitHub', keywords: ['github', 'repo', 'commit', 'pull request', 'issue', 'branch', 'code'], colorValue: 0xFF6e40c9),
  ComposioService(id: 'gmail', name: 'Gmail', keywords: ['gmail', 'email', 'mail', 'send email', 'inbox', 'draft'], colorValue: 0xFFEA4335),
  ComposioService(id: 'telegram', name: 'Telegram', keywords: ['telegram', 'tg', 'message', 'send message'], colorValue: 0xFF0088cc),
  ComposioService(id: 'twitter', name: 'Twitter', keywords: ['twitter', 'tweet', 'x.com', 'post tweet'], colorValue: 0xFF1DA1F2),
  ComposioService(id: 'instagram', name: 'Instagram', keywords: ['instagram', 'ig', 'story', 'reel', 'post', 'dm'], colorValue: 0xFFE4405F),
  ComposioService(id: 'facebook', name: 'Facebook', keywords: ['facebook', 'fb', 'post', 'page', 'group'], colorValue: 0xFF1877F2),
  ComposioService(id: 'whatsapp', name: 'WhatsApp', keywords: ['whatsapp', 'wa', 'whats app'], colorValue: 0xFF25D366),
  ComposioService(id: 'googlechrome', name: 'Chrome', keywords: ['chrome', 'browser', 'open url', 'browse', 'search'], colorValue: 0xFF4285F4),
  ComposioService(id: 'googledrive', name: 'Google Drive', keywords: ['drive', 'google drive', 'upload', 'file', 'folder', 'share file'], colorValue: 0xFF0F9D58),
  ComposioService(id: 'discord', name: 'Discord', keywords: ['discord', 'server', 'channel', 'dm discord'], colorValue: 0xFF5865F2),
  ComposioService(id: 'linkedin', name: 'LinkedIn', keywords: ['linkedin', 'profile', 'connection', 'job'], colorValue: 0xFF0A66C2),
  ComposioService(id: 'reddit', name: 'Reddit', keywords: ['reddit', 'subreddit', 'post', 'upvote', 'thread'], colorValue: 0xFFFF4500),
  ComposioService(id: 'googleheets', name: 'Google Sheets', keywords: ['sheet', 'spreadsheet', 'google sheets', 'cell', 'row', 'column'], colorValue: 0xFF0F9D58),
];

/// Service that manages Composio integration directly via REST API.
///
/// Calls Composio's backend.composio.dev endpoints directly from Dart
/// (no more routing through the broken Cloudflare Worker backend).
/// Uses the Composio API key stored in encrypted prefs on the native side.
class ComposioServiceManager {
  static const MethodChannel _channel = MethodChannel('stremini.composio');
  static const EventChannel _eventChannel = EventChannel('stremini.composio/events');

  static const String _connectedKey = 'composio_connected';
  static const String _composioApiBase = 'https://backend.composio.dev/api/v1';

  StreamSubscription? _eventSub;
  String? _cachedApiKey;
  bool _isConnected = false;

  /// Connection status per service: serviceId → bool
  final Map<String, bool> _serviceStatus = {};

  String? get token => _cachedApiKey;
  bool get isConnected => _isConnected;
  Map<String, bool> get serviceStatus => Map.unmodifiable(_serviceStatus);

  /// Initialize — restore saved connection state and listen for deep-link events.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isConnected = prefs.getBool(_connectedKey) ?? false;

    if (Platform.isAndroid) {
      try {
        _cachedApiKey = await _channel.invokeMethod<String?>('getComposioToken');
        if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) _isConnected = true;
      } catch (_) {}
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

  /// Refresh all service connection statuses from Composio API directly.
  Future<void> refreshServiceStatuses() async {
    if (_cachedApiKey == null || _cachedApiKey!.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$_composioApiBase/connectedAccounts'),
        headers: {'x-api-key': _cachedApiKey!},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _serviceStatus.clear();
        final accounts = data['connectedAccounts'] ?? data['data'] ?? [];
        for (final acct in accounts) {
          final provider = acct['providerName'] ?? acct['provider'] ?? '';
          if (provider.toString().isNotEmpty) {
            _serviceStatus[provider.toString()] = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Composio: error refreshing statuses — $e');
    }
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

  /// Exchange the auth code (received via deep-link) for an API key.
  /// Now calls Composio directly instead of the broken backend.
  Future<void> _exchangeCodeForToken(String authCode) async {
    try {
      // Composio uses the auth code flow — exchange via their endpoint
      final response = await http.post(
        Uri.parse('$_composioApiBase/auth/exchangeCode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': authCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final apiKey = data['apiKey'] ?? data['token'] ?? data['key'];
        if (apiKey != null && apiKey.toString().isNotEmpty) {
          await _saveToken(apiKey.toString());
          debugPrint('Composio: API key exchanged and saved');
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
    _cachedApiKey = token;
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
    _cachedApiKey = null;
    _isConnected = false;
    _serviceStatus.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, false);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('saveComposioToken', {'token': ''});
      } catch (_) {}
    }
  }

  /// Send an automation instruction via Composio API directly.
  /// No more routing through the broken Cloudflare Worker backend.
  Future<String> sendAutomationInstruction(String instruction) async {
    if (_cachedApiKey == null || _cachedApiKey!.isEmpty) {
      return 'Composio is not connected. Go to Settings → Connect Automations first.';
    }
    try {
      final response = await http.post(
        Uri.parse('$_composioApiBase/actions/execute'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _cachedApiKey!,
        },
        body: jsonEncode({
          'message': instruction.length > 4000 ? instruction.substring(0, 4000) : instruction,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['result'] ?? data['response'] ?? data['message'] ?? data['output'] ?? 'Done.').toString();
      }
      if (response.statusCode == 401) {
        await disconnect();
        return 'Composio session expired. Please reconnect in Settings.';
      }
      if (response.statusCode == 403) {
        return 'Permission denied. Reconnect the service and try again.';
      }
      if (response.statusCode == 422) {
        return 'Invalid request. Please be more specific about what you want to do.';
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