import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/search_response_model.dart';

/// Representation of a persisted conversation (local + cloud-synced via Worker D1)
class ChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final String? lastMessage;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.lastMessage,
  });

  /// Deserialize from local SharedPreferences JSON or Worker API response
  factory ChatConversation.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return ChatConversation(
      id: id,
      title: data['title'] as String? ?? 'New Conversation',
      createdAt: parseTime(data['createdAt'] ?? data['created_at']),
      updatedAt: parseTime(data['updatedAt'] ?? data['updated_at']),
      isPinned: data['isPinned'] as bool? ?? false,
      lastMessage: (data['lastMessage'] ?? data['last_message']) as String?,
    );
  }

  /// Deserialize from Worker API JSON response
  factory ChatConversation.fromWorkerJson(Map<String, dynamic> data) {
    return ChatConversation.fromMap(
      data['id'] as String? ?? '',
      data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned,
      if (lastMessage != null) 'lastMessage': lastMessage,
    };
  }
}

/// Representation of a persisted message (local + cloud-synced via Worker D1)
class PersistedChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final NexoraSearchResponse? searchResponse;
  final bool isError;
  final String? retryQuery;

  const PersistedChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.searchResponse,
    this.isError = false,
    this.retryQuery,
  });

  factory PersistedChatMessage.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    NexoraSearchResponse? parsedSearch;
    if (data['searchResponse'] is Map<String, dynamic>) {
      try {
        parsedSearch = NexoraSearchResponse.fromJson(data['searchResponse'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[ChatRepository] Error parsing searchResponse: $e');
      }
    }

    return PersistedChatMessage(
      id: id,
      text: data['text'] as String? ?? data['content'] as String? ?? '',
      isUser: data['isUser'] as bool? ?? (data['role'] == 'user'),
      timestamp: parseTime(data['timestamp'] ?? data['created_at']),
      searchResponse: parsedSearch,
      isError: data['isError'] as bool? ?? false,
      retryQuery: data['retryQuery'] as String?,
    );
  }

  /// Deserialize from Worker API JSON response
  factory PersistedChatMessage.fromWorkerJson(Map<String, dynamic> data) {
    return PersistedChatMessage.fromMap(
      data['id'] as String? ?? '',
      data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      if (retryQuery != null) 'retryQuery': retryQuery,
      if (searchResponse != null)
        'searchResponse': {
          'success': searchResponse!.success,
          'query': searchResponse!.query,
          'results': searchResponse!.results.map((r) => r.toJson()).toList(),
          'sources': searchResponse!.sources.map((s) => s.toJson()).toList(),
          if (searchResponse!.message != null) 'message': searchResponse!.message,
          if (searchResponse!.error != null) 'error': searchResponse!.error,
        },
    };
  }
}

// ---------------------------------------------------------------------------
// Chat Repository — Cloud-Synced via Cloudflare Worker D1 API
// ---------------------------------------------------------------------------

/// Dual-layer Chat Repository (Local SharedPreferences + Cloud Worker D1)
/// Ensures chat history is persistent across app restarts, offline usage,
/// and synced across all devices via the authenticated Worker API.
class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();

  /// Default singleton factory ensures UI components share the same instance and streams
  factory ChatRepository({http.Client? client, String? baseUrl}) {
    if (client != null || baseUrl != null) {
      return ChatRepository._internal(client: client, baseUrl: baseUrl);
    }
    return _instance;
  }

  ChatRepository._internal({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConstants.workerBaseUrl;

  final Uuid _uuid = const Uuid();
  final http.Client _client;
  final String _baseUrl;

  static const String _conversationsKeyPrefix = 'nexora_conversations_';
  static const String _messagesKeyPrefix = 'nexora_messages_';

  // In-memory cache for instant synchronous access
  final Map<String, List<ChatConversation>> _memoryCache = {};

  // StreamController to broadcast real-time conversation updates to the UI
  final _conversationsStreamController = StreamController<List<ChatConversation>>.broadcast();

  /// Synchronously get cached conversations for instant rendering without waiting for SharedPreferences
  List<ChatConversation> getCachedConversations(String uid) {
    return _memoryCache[uid] ?? [];
  }

  // ---------------------------------------------------------------------------
  // Firebase Auth Token Helper
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _getAuthHeaders({bool forceRefresh = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Nexora-Flutter-App/1.0',
    };
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken(forceRefresh);
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('[ChatRepository] Note obtaining Firebase auth token: $e');
    }
    return headers;
  }

  // ---------------------------------------------------------------------------
  // Local Storage Helpers (Guaranteed Offline & Instant Persistence)
  // ---------------------------------------------------------------------------

  Future<List<ChatConversation>> _getLocalConversations(String uid) async {
    if (uid.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_conversationsKeyPrefix$uid';
      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final list = jsonDecode(jsonStr) as List<dynamic>;
      final conversations = list
          .whereType<Map<String, dynamic>>()
          .map((m) => ChatConversation.fromMap(m['id'] as String? ?? '', m))
          .toList();

      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _memoryCache[uid] = conversations;
      return conversations;
    } catch (e) {
      debugPrint('[ChatRepository] Error reading local conversations: $e');
      return [];
    }
  }

  Future<void> _saveLocalConversations(String uid, List<ChatConversation> list) async {
    if (uid.isEmpty) return;
    try {
      _memoryCache[uid] = list;
      final prefs = await SharedPreferences.getInstance();
      final key = '$_conversationsKeyPrefix$uid';
      final jsonStr = jsonEncode(list.map((c) => c.toMap()).toList());
      await prefs.setString(key, jsonStr);
      if (!_conversationsStreamController.isClosed) {
        _conversationsStreamController.add(list);
      }
    } catch (e) {
      debugPrint('[ChatRepository] Error saving local conversations: $e');
    }
  }

  Future<List<PersistedChatMessage>> _getLocalMessages(String uid, String conversationId) async {
    if (uid.isEmpty || conversationId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagesKeyPrefix${uid}_$conversationId';
      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final list = jsonDecode(jsonStr) as List<dynamic>;
      final messages = list
          .whereType<Map<String, dynamic>>()
          .map((m) => PersistedChatMessage.fromMap(m['id'] as String? ?? '', m))
          .toList();

      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      debugPrint('[ChatRepository] Error reading local messages: $e');
      return [];
    }
  }

  Future<void> _saveLocalMessages(String uid, String conversationId, List<PersistedChatMessage> list) async {
    if (uid.isEmpty || conversationId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_messagesKeyPrefix${uid}_$conversationId';
      final jsonStr = jsonEncode(list.map((m) => m.toMap()).toList());
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('[ChatRepository] Error saving local messages: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Worker API Helpers (with Automatic Token Force-Refresh on 401)
  // ---------------------------------------------------------------------------

  /// Fetch conversations from the Worker D1 API.
  Future<List<ChatConversation>> _fetchRemoteConversations() async {
    try {
      var headers = await _getAuthHeaders();
      var response = await _client.get(
        Uri.parse('$_baseUrl/chat/conversations?limit=50'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      // Auto-retry with force-refreshed token if expired
      if (response.statusCode == 401) {
        headers = await _getAuthHeaders(forceRefresh: true);
        response = await _client.get(
          Uri.parse('$_baseUrl/chat/conversations?limit=50'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (json['success'] == true && json['conversations'] is List) {
          final list = (json['conversations'] as List)
              .whereType<Map<String, dynamic>>()
              .map((c) => ChatConversation.fromWorkerJson(c))
              .toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        }
      }
      debugPrint('[ChatRepository] Worker list conversations HTTP ${response.statusCode}');
    } on SocketException catch (e) {
      debugPrint('[ChatRepository] Network error fetching conversations: $e');
    } on TimeoutException catch (e) {
      debugPrint('[ChatRepository] Timeout fetching conversations: $e');
    } catch (e) {
      debugPrint('[ChatRepository] Worker conversations fetch error: $e');
    }
    return [];
  }

  /// Fetch messages for a conversation from the Worker D1 API.
  Future<List<PersistedChatMessage>> _fetchRemoteMessages(String conversationId) async {
    try {
      var headers = await _getAuthHeaders();
      final encodedId = Uri.encodeComponent(conversationId);
      var response = await _client.get(
        Uri.parse('$_baseUrl/chat/conversations/$encodedId?limit=200'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        headers = await _getAuthHeaders(forceRefresh: true);
        response = await _client.get(
          Uri.parse('$_baseUrl/chat/conversations/$encodedId?limit=200'),
          headers: headers,
        ).timeout(const Duration(seconds: 15));
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (json['success'] == true && json['messages'] is List) {
          final list = (json['messages'] as List)
              .whereType<Map<String, dynamic>>()
              .map((m) => PersistedChatMessage.fromWorkerJson(m))
              .toList();
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return list;
        }
      }
      debugPrint('[ChatRepository] Worker fetch messages HTTP ${response.statusCode}');
    } on SocketException catch (e) {
      debugPrint('[ChatRepository] Network error fetching messages: $e');
    } on TimeoutException catch (e) {
      debugPrint('[ChatRepository] Timeout fetching messages: $e');
    } catch (e) {
      debugPrint('[ChatRepository] Worker messages fetch error: $e');
    }
    return [];
  }

  /// Create or upsert a conversation on the Worker D1 API.
  Future<ChatConversation?> _createRemoteConversation({
    required String convId,
    required String title,
  }) async {
    try {
      var headers = await _getAuthHeaders();
      var response = await _client.post(
        Uri.parse('$_baseUrl/chat/conversations'),
        headers: headers,
        body: jsonEncode({'id': convId, 'title': title}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        headers = await _getAuthHeaders(forceRefresh: true);
        response = await _client.post(
          Uri.parse('$_baseUrl/chat/conversations'),
          headers: headers,
          body: jsonEncode({'id': convId, 'title': title}),
        ).timeout(const Duration(seconds: 10));
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if (json['success'] == true && json['conversation'] is Map<String, dynamic>) {
          return ChatConversation.fromWorkerJson(json['conversation'] as Map<String, dynamic>);
        }
      }
      debugPrint('[ChatRepository] Worker create conversation HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[ChatRepository] Worker create conversation error: $e');
    }
    return null;
  }

  /// Save a message to the Worker D1 API (idempotent).
  Future<void> _saveRemoteMessage({
    required String msgId,
    required String conversationId,
    required String role,
    required String content,
    String? createdAt,
  }) async {
    try {
      var headers = await _getAuthHeaders();
      final body = <String, dynamic>{
        'id': msgId,
        'conversation_id': conversationId,
        'role': role,
        'content': content,
      };
      if (createdAt != null) body['created_at'] = createdAt;

      var response = await _client.post(
        Uri.parse('$_baseUrl/chat/messages'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        headers = await _getAuthHeaders(forceRefresh: true);
        response = await _client.post(
          Uri.parse('$_baseUrl/chat/messages'),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint('[ChatRepository] Worker save message error (non-fatal): $e');
    }
  }

  /// Rename a conversation on the Worker D1 API.
  Future<bool> _renameRemoteConversation(String conversationId, String newTitle) async {
    try {
      var headers = await _getAuthHeaders();
      final encodedId = Uri.encodeComponent(conversationId);
      var response = await _client.patch(
        Uri.parse('$_baseUrl/chat/conversations/$encodedId'),
        headers: headers,
        body: jsonEncode({'title': newTitle}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        headers = await _getAuthHeaders(forceRefresh: true);
        response = await _client.patch(
          Uri.parse('$_baseUrl/chat/conversations/$encodedId'),
          headers: headers,
          body: jsonEncode({'title': newTitle}),
        ).timeout(const Duration(seconds: 10));
      }

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ChatRepository] Worker rename conversation error: $e');
      return false;
    }
  }

  /// Delete a conversation on the Worker D1 API.
  Future<bool> _deleteRemoteConversation(String conversationId) async {
    try {
      var headers = await _getAuthHeaders();
      final encodedId = Uri.encodeComponent(conversationId);
      var response = await _client.delete(
        Uri.parse('$_baseUrl/chat/conversations/$encodedId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        headers = await _getAuthHeaders(forceRefresh: true);
        response = await _client.delete(
          Uri.parse('$_baseUrl/chat/conversations/$encodedId'),
          headers: headers,
        ).timeout(const Duration(seconds: 10));
      }

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ChatRepository] Worker delete conversation error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Public Conversation APIs
  // ---------------------------------------------------------------------------

  /// Stream conversations for an authenticated UID
  Stream<List<ChatConversation>> streamConversations(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    // Trigger immediate local load & remote sync
    _syncConversations(uid);

    return _conversationsStreamController.stream;
  }

  /// Explicitly trigger a refresh from the Worker D1 API (e.g. for pull-to-refresh)
  Future<void> refreshConversations(String uid) async {
    await _syncConversations(uid);
  }

  /// Initial sync: load local first, then merge with Worker D1 API
  Future<void> _syncConversations(String uid) async {
    final local = await _getLocalConversations(uid);
    if (local.isNotEmpty && !_conversationsStreamController.isClosed) {
      _conversationsStreamController.add(local);
    }

    try {
      final remote = await _fetchRemoteConversations();

      if (remote.isNotEmpty) {
        // Merge remote and local — remote is authoritative, local provides isPinned
        final localPinMap = <String, bool>{};
        for (final c in local) {
          localPinMap[c.id] = c.isPinned;
        }

        final map = <String, ChatConversation>{};
        for (final c in local) {
          map[c.id] = c;
        }
        for (final c in remote) {
          // Preserve local-only isPinned state since Worker API doesn't store it
          final preservedPin = localPinMap[c.id] ?? false;
          map[c.id] = ChatConversation(
            id: c.id,
            title: c.title,
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
            isPinned: preservedPin,
            lastMessage: c.lastMessage,
          );
        }

        final merged = map.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        await _saveLocalConversations(uid, merged);
      } else if (local.isNotEmpty) {
        if (!_conversationsStreamController.isClosed) {
          _conversationsStreamController.add(local);
        }
      } else {
        if (!_conversationsStreamController.isClosed) {
          _conversationsStreamController.add([]);
        }
      }
    } catch (e) {
      debugPrint('[ChatRepository] Worker sync note (offline/fallback): $e');
      if (local.isNotEmpty) {
        if (!_conversationsStreamController.isClosed) {
          _conversationsStreamController.add(local);
        }
      } else {
        if (!_conversationsStreamController.isClosed) {
          _conversationsStreamController.add([]);
        }
      }
    }
  }

  /// Get list of conversations
  Future<List<ChatConversation>> getConversations(String uid) async {
    if (uid.isEmpty) return [];
    final local = await _getLocalConversations(uid);
    if (local.isNotEmpty) return local;

    try {
      final remote = await _fetchRemoteConversations();
      if (remote.isNotEmpty) {
        await _saveLocalConversations(uid, remote);
        return remote;
      }
    } catch (_) {}
    return local;
  }

  /// Create a new conversation doc
  Future<String> createConversation(String uid, {required String title}) async {
    final convId = _uuid.v4();
    final now = DateTime.now();
    final safeTitle = title.trim().isEmpty ? 'New Chat' : title.trim();
    final conv = ChatConversation(
      id: convId,
      title: safeTitle,
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    );

    // 1. Save locally immediately
    final local = await _getLocalConversations(uid);
    local.insert(0, conv);
    await _saveLocalConversations(uid, local);

    // 2. Persist to Worker D1 in background
    _createRemoteConversation(convId: convId, title: safeTitle);

    return convId;
  }

  /// Save a message to a conversation
  Future<void> saveMessage(
    String uid,
    String conversationId, {
    required String text,
    required bool isUser,
    NexoraSearchResponse? searchResponse,
    bool isError = false,
    String? retryQuery,
  }) async {
    if (uid.isEmpty || conversationId.isEmpty) return;

    final msgId = _uuid.v4();
    final now = DateTime.now();

    final message = PersistedChatMessage(
      id: msgId,
      text: text,
      isUser: isUser,
      timestamp: now,
      searchResponse: searchResponse,
      isError: isError,
      retryQuery: retryQuery,
    );

    // 1. Save message locally
    final localMsgs = await _getLocalMessages(uid, conversationId);
    localMsgs.add(message);
    await _saveLocalMessages(uid, conversationId, localMsgs);

    // 2. Update conversation preview locally
    final conversations = await _getLocalConversations(uid);
    final convIndex = conversations.indexWhere((c) => c.id == conversationId);

    String newTitle = 'New Chat';
    if (convIndex != -1) {
      final existing = conversations[convIndex];
      newTitle = existing.title;
      if (isUser && (existing.title == 'New Chat' || existing.title.isEmpty)) {
        newTitle = text.length > 35 ? '${text.substring(0, 35)}...' : text;
      }
      conversations[convIndex] = ChatConversation(
        id: existing.id,
        title: newTitle,
        createdAt: existing.createdAt,
        updatedAt: now,
        isPinned: existing.isPinned,
        lastMessage: text.length > 80 ? '${text.substring(0, 80)}...' : text,
      );
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _saveLocalConversations(uid, conversations);
    }

    // 3. Persist to Worker D1 API in background (fire-and-forget)
    _saveRemoteMessage(
      msgId: msgId,
      conversationId: conversationId,
      role: isUser ? 'user' : 'assistant',
      content: text,
      createdAt: now.toIso8601String(),
    );
  }

  /// Load all messages for a specific conversation
  Future<List<PersistedChatMessage>> getMessages(String uid, String conversationId) async {
    if (uid.isEmpty || conversationId.isEmpty) return [];

    // 1. Return local messages first for instant rendering
    final local = await _getLocalMessages(uid, conversationId);

    // 2. Fetch from Worker D1 to ensure cross-device sync
    try {
      final remote = await _fetchRemoteMessages(conversationId);
      if (remote.isNotEmpty) {
        // Merge: remote messages are content-only (no searchResponse, isError, retryQuery).
        // For messages that exist locally, prefer local metadata. For new remote messages, use remote.
        final localById = <String, PersistedChatMessage>{};
        for (final m in local) {
          localById[m.id] = m;
        }

        final merged = <PersistedChatMessage>[];
        final seenIds = <String>{};

        // First: add all remote messages (with local enrichment if available)
        for (final rm in remote) {
          seenIds.add(rm.id);
          final localMatch = localById[rm.id];
          if (localMatch != null) {
            // Prefer local version (has searchResponse, isError, etc.)
            merged.add(localMatch);
          } else {
            merged.add(rm);
          }
        }

        // Then: add local-only messages that aren't on the server yet
        for (final lm in local) {
          if (!seenIds.contains(lm.id)) {
            merged.add(lm);
          }
        }

        merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        await _saveLocalMessages(uid, conversationId, merged);
        return merged;
      }
    } catch (e) {
      debugPrint('[ChatRepository] getMessages Worker note: $e');
    }

    return local;
  }

  /// Permanently delete a conversation and its messages
  Future<void> deleteConversation(String uid, String conversationId) async {
    if (uid.isEmpty || conversationId.isEmpty) return;

    // 1. Delete locally immediately
    final conversations = await _getLocalConversations(uid);
    conversations.removeWhere((c) => c.id == conversationId);
    await _saveLocalConversations(uid, conversations);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_messagesKeyPrefix${uid}_$conversationId');

    // 2. Delete from Worker D1 API
    try {
      final deleted = await _deleteRemoteConversation(conversationId);
      debugPrint('[ChatRepository] Worker delete conversation $conversationId: $deleted');
    } catch (e) {
      debugPrint('[ChatRepository] Worker delete error: $e');
    }
  }

  /// Rename a conversation
  Future<void> renameConversation(String uid, String conversationId, String newTitle) async {
    if (uid.isEmpty || conversationId.isEmpty) return;

    // 1. Update locally
    final conversations = await _getLocalConversations(uid);
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      conversations[idx] = ChatConversation(
        id: conversations[idx].id,
        title: newTitle.trim(),
        createdAt: conversations[idx].createdAt,
        updatedAt: DateTime.now(),
        isPinned: conversations[idx].isPinned,
        lastMessage: conversations[idx].lastMessage,
      );
      await _saveLocalConversations(uid, conversations);
    }

    // 2. Update on Worker D1 API
    try {
      await _renameRemoteConversation(conversationId, newTitle.trim());
    } catch (e) {
      debugPrint('[ChatRepository] Worker rename error: $e');
    }
  }

  /// Toggle pin status of a conversation (local-only since Worker doesn't store pin state)
  Future<void> togglePinConversation(String uid, String conversationId, bool isPinned) async {
    if (uid.isEmpty || conversationId.isEmpty) return;

    // Update locally only — pinning is a client-side preference
    final conversations = await _getLocalConversations(uid);
    final idx = conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      conversations[idx] = ChatConversation(
        id: conversations[idx].id,
        title: conversations[idx].title,
        createdAt: conversations[idx].createdAt,
        updatedAt: conversations[idx].updatedAt,
        isPinned: isPinned,
        lastMessage: conversations[idx].lastMessage,
      );
      await _saveLocalConversations(uid, conversations);
    }
  }

  /// Filter conversations by query against title and lastMessage preview.
  /// Pure function: does not mutate input list or conversation objects.
  List<ChatConversation> filterConversations(
    List<ChatConversation> conversations,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return conversations;

    final q = trimmed.toLowerCase();
    return conversations.where((conv) {
      final titleMatch = conv.title.toLowerCase().contains(q);
      final lastMsgMatch = conv.lastMessage?.toLowerCase().contains(q) ?? false;
      return titleMatch || lastMsgMatch;
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final userConversationsStreamProvider = StreamProvider<List<ChatConversation>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  final repository = ref.watch(chatRepositoryProvider);
  return repository.streamConversations(user.uid);
});
