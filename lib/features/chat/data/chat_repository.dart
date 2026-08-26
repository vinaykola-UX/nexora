import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/search_response_model.dart';

/// Representation of a persisted conversation in Firestore:
/// `students/{uid}/conversations/{conversationId}`
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
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ChatConversation(
      id: doc.id,
      title: data['title'] as String? ?? 'New Conversation',
      createdAt: parseTime(data['createdAt']),
      updatedAt: parseTime(data['updatedAt']),
      isPinned: data['isPinned'] as bool? ?? false,
      lastMessage: data['lastMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isPinned': isPinned,
      if (lastMessage != null) 'lastMessage': lastMessage,
    };
  }
}

/// Representation of a persisted message in Firestore:
/// `students/{uid}/conversations/{conversationId}/messages/{messageId}`
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
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    NexoraSearchResponse? parsedSearch;
    if (data['searchResponse'] is Map<String, dynamic>) {
      try {
        parsedSearch = NexoraSearchResponse.fromJson(data['searchResponse'] as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[ChatRepository] Error parsing persisted searchResponse: $e');
      }
    }

    return PersistedChatMessage(
      id: doc.id,
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

/// Repository responsible for persisting conversations and messages in Firestore
class ChatRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _userConversations(String uid) {
    return _firestore.collection('students').doc(uid).collection('conversations');
  }

  /// Stream of user conversations ordered by pinned and most recently updated
  Stream<List<ChatConversation>> streamConversations(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _userConversations(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatConversation.fromFirestore(doc)).toList();
    });
  }

  /// Get list of user conversations
  Future<List<ChatConversation>> getConversations(String uid) async {
    if (uid.isEmpty) return [];
    try {
      final snapshot = await _userConversations(uid)
          .orderBy('updatedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ChatConversation.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[ChatRepository] Error getting conversations: $e');
      return [];
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

    await _userConversations(uid).doc(convId).set(conv.toMap());
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

    try {
      final convRef = _userConversations(uid).doc(conversationId);
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

      final batch = _firestore.batch();
      final msgRef = convRef.collection('messages').doc(msgId);
      batch.set(msgRef, message.toMap());

      // Update parent conversation timestamp & last message preview
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
        'lastMessage': text.length > 80 ? '${text.substring(0, 80)}...' : text,
      };

      // If this is a new conversation without a specific title, title it with the first user question
      if (isUser) {
        final convDoc = await convRef.get();
        if (!convDoc.exists || convDoc.data()?['title'] == 'New Chat') {
          updateData['title'] = text.length > 35 ? '${text.substring(0, 35)}...' : text;
        }
      }

      batch.set(convRef, updateData, SetOptions(merge: true));
      await batch.commit();
    } catch (e) {
      debugPrint('[ChatRepository] Error saving message: $e');
    }
  }

  /// Stream messages for a specific conversation
  Stream<List<PersistedChatMessage>> streamMessages(String uid, String conversationId) {
    if (uid.isEmpty || conversationId.isEmpty) return Stream.value([]);
    return _userConversations(uid)
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PersistedChatMessage.fromFirestore(doc)).toList();
    });
  }

  /// Load all messages for a specific conversation
  Future<List<PersistedChatMessage>> getMessages(String uid, String conversationId) async {
    if (uid.isEmpty || conversationId.isEmpty) return [];
    try {
      final snapshot = await _userConversations(uid)
          .doc(conversationId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();
      return snapshot.docs.map((doc) => PersistedChatMessage.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[ChatRepository] Error loading messages: $e');
      return [];
    }
  }

  /// Permanently delete a conversation and its messages from Firestore
  Future<void> deleteConversation(String uid, String conversationId) async {
    if (uid.isEmpty || conversationId.isEmpty) return;

    try {
      final convRef = _userConversations(uid).doc(conversationId);
      final messagesSnapshot = await convRef.collection('messages').get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(convRef);
      await batch.commit();
      debugPrint('[ChatRepository] Successfully deleted conversation $conversationId for user $uid');
    } catch (e) {
      debugPrint('[ChatRepository] Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Rename a conversation
  Future<void> renameConversation(String uid, String conversationId, String newTitle) async {
    if (uid.isEmpty || conversationId.isEmpty) return;
    try {
      await _userConversations(uid).doc(conversationId).update({
        'title': newTitle.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ChatRepository] Error renaming conversation: $e');
    }
  }

  /// Toggle pin status of a conversation
  Future<void> togglePinConversation(String uid, String conversationId, bool isPinned) async {
    if (uid.isEmpty || conversationId.isEmpty) return;
    try {
      await _userConversations(uid).doc(conversationId).update({
        'isPinned': isPinned,
      });
    } catch (e) {
      debugPrint('[ChatRepository] Error toggling pin: $e');
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
