import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../models/search_response_model.dart';

/// Representation of a persisted conversation in Firestore & local storage
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

  factory ChatConversation.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatConversation.fromMap(doc.id, data);
  }

  factory ChatConversation.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return ChatConversation(
      id: id,
      title: data['title'] as String? ?? 'New Conversation',
      createdAt: parseTime(data['createdAt']),
      updatedAt: parseTime(data['updatedAt']),
      isPinned: data['isPinned'] as bool? ?? false,
      lastMessage: data['lastMessage'] as String?,
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

  Map<String, dynamic> toFirestoreMap() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPinned': isPinned,
      if (lastMessage != null) 'lastMessage': lastMessage,
    };
  }
}

/// Representation of a persisted message in Firestore & local storage
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

  factory PersistedChatMessage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PersistedChatMessage.fromMap(doc.id, data);
  }

  factory PersistedChatMessage.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
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
      text: data['text'] as String? ?? '',
      isUser: data['isUser'] as bool? ?? false,
      timestamp: parseTime(data['timestamp']),
      searchResponse: parsedSearch,
      isError: data['isError'] as bool? ?? false,
      retryQuery: data['retryQuery'] as String?,
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

  Map<String, dynamic> toFirestoreMap() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': Timestamp.fromDate(timestamp),
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

/// Dual-layer Chat Repository (Local SharedPreferences + Cloud Firestore)
/// Ensures chat history is 100% persistent across app restarts, offline usage, and device reboots.
class ChatRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _conversationsKeyPrefix = 'nexora_conversations_';
  static const String _messagesKeyPrefix = 'nexora_messages_';

  // StreamController to broadcast real-time conversation updates to the UI
  final _conversationsStreamController = StreamController<List<ChatConversation>>.broadcast();

  CollectionReference<Map<String, dynamic>> _userConversations(String uid) {
    return _firestore.collection('students').doc(uid).collection('conversations');
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
      return conversations;
    } catch (e) {
      debugPrint('[ChatRepository] Error reading local conversations: $e');
      return [];
    }
  }

  Future<void> _saveLocalConversations(String uid, List<ChatConversation> list) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_conversationsKeyPrefix$uid';
      final jsonStr = jsonEncode(list.map((c) => c.toMap()).toList());
      await prefs.setString(key, jsonStr);
      _conversationsStreamController.add(list);
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
  // Public Conversation APIs
  // ---------------------------------------------------------------------------

  /// Stream conversations for an authenticated UID
  Stream<List<ChatConversation>> streamConversations(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    // Trigger immediate local load & remote sync
    _syncConversations(uid);

    return _conversationsStreamController.stream;
  }

  /// Initial sync: load local first, then merge with Firestore
  Future<void> _syncConversations(String uid) async {
    final local = await _getLocalConversations(uid);
    if (local.isNotEmpty) {
      _conversationsStreamController.add(local);
    }

    try {
      final snapshot = await _userConversations(uid)
          .orderBy('updatedAt', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final remote = snapshot.docs
            .map((doc) => ChatConversation.fromFirestore(doc))
            .toList();

        // Merge remote and local (remote takes precedence on conflict)
        final map = <String, ChatConversation>{};
        for (final c in local) {
          map[c.id] = c;
        }
        for (final c in remote) {
          map[c.id] = c;
        }

        final merged = map.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        await _saveLocalConversations(uid, merged);
      } else if (local.isNotEmpty) {
        _conversationsStreamController.add(local);
      } else {
        _conversationsStreamController.add([]);
      }
    } catch (e) {
      debugPrint('[ChatRepository] Firestore sync note (offline/fallback): $e');
      if (local.isNotEmpty) {
        _conversationsStreamController.add(local);
      } else {
        _conversationsStreamController.add([]);
      }
    }
  }

  /// Get list of conversations
  Future<List<ChatConversation>> getConversations(String uid) async {
    if (uid.isEmpty) return [];
    final local = await _getLocalConversations(uid);
    if (local.isNotEmpty) return local;

    try {
      final snapshot = await _userConversations(uid)
          .orderBy('updatedAt', descending: true)
          .get();
      final remote = snapshot.docs.map((doc) => ChatConversation.fromFirestore(doc)).toList();
      await _saveLocalConversations(uid, remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  /// Create a new conversation doc
  Future<String> createConversation(String uid, {required String title}) async {
    final convId = _uuid.v4();
    final now = DateTime.now();
    final conv = ChatConversation(
      id: convId,
      title: title.trim().isEmpty ? 'New Chat' : title.trim(),
      createdAt: now,
      updatedAt: now,
      isPinned: false,
    );

    // 1. Save locally immediately
    final local = await _getLocalConversations(uid);
    local.insert(0, conv);
    await _saveLocalConversations(uid, local);

    // 2. Persist to Firestore in background
    try {
      await _userConversations(uid).doc(convId).set(conv.toFirestoreMap());
    } catch (e) {
      debugPrint('[ChatRepository] Firestore createConversation error: $e');
    }

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

    // 3. Persist to Firestore
    try {
      final convRef = _userConversations(uid).doc(conversationId);
      final batch = _firestore.batch();
      final msgRef = convRef.collection('messages').doc(msgId);
      batch.set(msgRef, message.toFirestoreMap());

      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
        'lastMessage': text.length > 80 ? '${text.substring(0, 80)}...' : text,
        if (convIndex != -1 && isUser) 'title': newTitle,
      };

      batch.set(convRef, updateData, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatRepository] Firestore saveMessage note: $e');
    }
  }

  /// Load all messages for a specific conversation
  Future<List<PersistedChatMessage>> getMessages(String uid, String conversationId) async {
    if (uid.isEmpty || conversationId.isEmpty) return [];

    // 1. Return local messages first for instant rendering
    final local = await _getLocalMessages(uid, conversationId);

    // 2. Fetch from Firestore to ensure full sync
    try {
      final snapshot = await _userConversations(uid)
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final remote = snapshot.docs
            .map((doc) => PersistedChatMessage.fromFirestore(doc))
            .toList();
        await _saveLocalMessages(uid, conversationId, remote);
        return remote;
      }
    } catch (e) {
      debugPrint('[ChatRepository] getMessages Firestore note: $e');
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

    // 2. Delete from Firestore
    try {
      final convRef = _userConversations(uid).doc(conversationId);
      final messagesSnapshot = await convRef.collection('messages').get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(convRef);
      await batch.commit();
      debugPrint('[ChatRepository] Permanently deleted conversation $conversationId from Firestore');
    } catch (e) {
      debugPrint('[ChatRepository] Firestore delete note: $e');
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

    // 2. Update in Firestore
    try {
      await _userConversations(uid).doc(conversationId).update({
        'title': newTitle.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ChatRepository] Firestore rename note: $e');
    }
  }

  /// Toggle pin status of a conversation
  Future<void> togglePinConversation(String uid, String conversationId, bool isPinned) async {
    if (uid.isEmpty || conversationId.isEmpty) return;

    // 1. Update locally
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

    // 2. Update in Firestore
    try {
      await _userConversations(uid).doc(conversationId).update({
        'isPinned': isPinned,
      });
    } catch (e) {
      debugPrint('[ChatRepository] Firestore pin note: $e');
    }
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
