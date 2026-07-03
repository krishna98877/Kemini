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
/// Keywords are ordered longest-first per service to avoid cross-service collisions.
const List<ComposioService> kComposioServices = [
  ComposioService(id: 'github', name: 'GitHub', keywords: ['pull request', 'repository', 'commit', 'issue', 'branch', 'github', 'repo'], colorValue: 0xFF6e40c9),
  ComposioService(id: 'gmail', name: 'Gmail', keywords: ['send email', 'email', 'mail', 'inbox', 'draft', 'gmail'], colorValue: 0xFFEA4335),
  ComposioService(id: 'telegram', name: 'Telegram', keywords: ['telegram message', 'telegram chat', 'telegram channel', 'telegram', 'tg'], colorValue: 0xFF0088cc),
  ComposioService(id: 'twitter', name: 'Twitter', keywords: ['post tweet', 'timeline', 'retweet', 'twitter', 'tweet', 'x.com'], colorValue: 0xFF1DA1F2),
  ComposioService(id: 'instagram', name: 'Instagram', keywords: ['instagram story', 'instagram reel', 'instagram dm', 'instagram post', 'instagram', 'ig', 'story', 'reel'], colorValue: 0xFFE4405F),
  ComposioService(id: 'facebook', name: 'Facebook', keywords: ['facebook post', 'facebook page', 'facebook group', 'facebook', 'fb'], colorValue: 0xFF1877F2),
  ComposioService(id: 'whatsapp', name: 'WhatsApp', keywords: ['whatsapp message', 'whats app', 'whatsapp', 'wa'], colorValue: 0xFF25D366),
  ComposioService(id: 'googlechrome', name: 'Chrome', keywords: ['browser', 'open url', 'chrome', 'search', 'tab', 'browse'], colorValue: 0xFF4285F4),
  ComposioService(id: 'googledrive', name: 'Google Drive', keywords: ['google drive', 'drive file', 'drive folder', 'share file', 'drive', 'upload'], colorValue: 0xFF0F9D58),
  ComposioService(id: 'discord', name: 'Discord', keywords: ['discord server', 'discord channel', 'discord dm', 'discord', 'guild'], colorValue: 0xFF5865F2),
  ComposioService(id: 'linkedin', name: 'LinkedIn', keywords: ['linkedin profile', 'linkedin connection', 'linkedin job', 'linkedin post', 'linkedin', 'connection', 'job'], colorValue: 0xFF0A66C2),
  ComposioService(id: 'reddit', name: 'Reddit', keywords: ['subreddit', 'reddit post', 'reddit', 'upvote', 'thread', 'comment'], colorValue: 0xFFFF4500),
  ComposioService(id: 'googleheets', name: 'Google Sheets', keywords: ['google sheets', 'spreadsheet', 'sheet', 'column', 'row', 'cell', 'table'], colorValue: 0xFF0F9D58),
];

/// Service that manages Composio integration directly via REST API.
///
/// Authentication: User provides their Composio API key from composio.dev/settings.
/// The key is stored encrypted via the native MethodChannel bridge.
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

  /// Set the Composio API key directly (from Settings).
  Future<void> setApiKey(String apiKey) async {
    _cachedApiKey = apiKey;
    _isConnected = apiKey.isNotEmpty;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_connectedKey, apiKey.isNotEmpty);

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('saveComposioToken', {'token': apiKey});
      } catch (_) {}
    }
  }

  /// Open Composio dashboard so user can get their API key.
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
  /// Uses longest-keyword-match to avoid collisions.
  ComposioService? detectService(String message) {
    final lower = message.toLowerCase();
    ComposioService? bestMatch;
    int bestKeywordLength = 0;

    for (final svc in kComposioServices) {
      for (final kw in svc.keywords) {
        if (lower.contains(kw) && kw.length > bestKeywordLength) {
          bestMatch = svc;
          bestKeywordLength = kw.length;
        }
      }
    }
    return bestMatch;
  }

  /// Exchange the auth code (received via deep-link) for an API key.
  Future<void> _exchangeCodeForToken(String authCode) async {
    try {
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

  /// Send an automation instruction via Composio API.
  ///
  /// This is a high-level method: it detects the service, finds a connected
  /// account, and executes the action. The action parsing is done server-side
  /// by Composio, or falls back to keyword-based mapping.
  Future<String> sendAutomationInstruction(String instruction) async {
    if (_cachedApiKey == null || _cachedApiKey!.isEmpty) {
      return 'Composio is not connected. Go to Settings → Connect Automations first.';
    }
    try {
      // Step 1: Detect the service
      final service = detectService(instruction);
      if (service == null) {
        return 'Could not detect which service to use. Try mentioning the service name (e.g., "send a Gmail email").';
      }

      // Step 2: Get connected account for this service
      final connectedAccounts = await _getConnectedAccounts();
      final accounts = connectedAccounts[service.id] ?? [];
      if (accounts.isEmpty) {
        return '${service.name} is not connected. Go to Settings → Automations, connect ${service.name}, then try again.';
      }
      final accountId = accounts.first;

      // Step 3: Build the action request
      final actionRequest = _buildActionRequest(instruction, service);

      final response = await http.post(
        Uri.parse('$_composioApiBase/actions/execute'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _cachedApiKey!,
        },
        body: jsonEncode({
          'actionId': actionRequest['actionId'],
          'inputParams': actionRequest['params'],
          'connectedAccountId': accountId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] ?? data['data'] ?? data;
        if (result is Map) {
          return (result['message'] ?? result['response'] ?? result['output'] ??
                  jsonEncode(result).toString().substring(0, 500))
              .toString();
        }
        return result.toString();
      }
      if (response.statusCode == 401) {
        await disconnect();
        return 'Composio session expired. Please reconnect in Settings.';
      }
      if (response.statusCode == 403) {
        return 'Permission denied. Reconnect the service and try again.';
      }
      return 'Automation failed (error ${response.statusCode}). Please try again.';
    } catch (e) {
      return 'Network error. Please check your connection and try again.';
    }
  }

  /// Get connected accounts from Composio API.
  Future<Map<String, List<String>>> _getConnectedAccounts() async {
    if (_cachedApiKey == null || _cachedApiKey!.isEmpty) return {};
    try {
      final response = await http.get(
        Uri.parse('$_composioApiBase/connectedAccounts'),
        headers: {'x-api-key': _cachedApiKey!},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accounts = data['connectedAccounts'] ?? data['data'] ?? [];
        final result = <String, List<String>>{};
        for (final acct in accounts) {
          final provider = acct['providerName'] ?? acct['provider'] ?? '';
          final id = acct['id'] ?? acct['connectedAccountId'] ?? '';
          if (provider.toString().isNotEmpty && id.toString().isNotEmpty) {
            result.putIfAbsent(provider.toString(), () => []).add(id.toString());
          }
        }
        return result;
      }
    } catch (_) {}
    return {};
  }

  /// Build actionId + params from instruction using keyword mapping.
  Map<String, dynamic> _buildActionRequest(String instruction, ComposioService service) {
    final lower = instruction.toLowerCase();

    switch (service.id) {
      case 'gmail':
        if (lower.contains('send') && (lower.contains('email') || lower.contains('mail'))) {
          final toRegex = RegExp(r'(?:to|for)\s+([\w.+-]+@[\w.-]+)', caseSensitive: false);
          final toMatch = toRegex.firstMatch(instruction);
          final subjectRegex = RegExp(r'(?:subject|about|re)\s+[:"]?([^".]+)', caseSensitive: false);
          final subjectMatch = subjectRegex.firstMatch(instruction);
          return {
            'actionId': 'GMAIL_SEND_EMAIL',
            'params': {
              'to': toMatch?.group(1) ?? '',
              'subject': subjectMatch?.group(1)?.trim() ?? 'No subject',
              'body': instruction,
            }
          };
        }
        return {'actionId': 'GMAIL_READ_EMAILS', 'params': {'maxResults': 10}};

      case 'github':
        if (lower.contains('issue') && lower.contains('create')) {
          return {'actionId': 'GITHUB_CREATE_AN_ISSUE', 'params': {'title': instruction}};
        }
        if (lower.contains('repo') && lower.contains('create')) {
          return {'actionId': 'GITHUB_CREATE_A_REPOSITORY', 'params': {'name': 'new-repo'}};
        }
        return {'actionId': 'GITHUB_LIST_REPOSITORIES_FOR_AUTHENTICATED_USER', 'params': {}};

      case 'twitter':
        return {'actionId': 'TWITTER_CREATE_A_TWEET', 'params': {'text': instruction}};

      case 'discord':
        return {'actionId': 'DISCORD_SEND_A_MESSAGE_TO_A_CHANNEL', 'params': {'content': instruction}};

      case 'linkedin':
        return {'actionId': 'LINKEDIN_CREATE_A_POST', 'params': {'text': instruction}};

      case 'reddit':
        return {'actionId': 'REDDIT_CREATE_A_POST', 'params': {'title': instruction, 'text': instruction}};

      case 'googledrive':
        return {'actionId': 'GOOGLE_DRIVE_UPLOAD_FILE', 'params': {'content': instruction}};

      case 'googleheets':
        return {'actionId': 'GOOGLE_SHEETS_READ_SHEET', 'params': {'range': 'A1:Z100'}};

      default:
        // For services without specific action mapping, return a generic request
        return {'actionId': '${service.id.toUpperCase()}_EXECUTE', 'params': {'instruction': instruction}};
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