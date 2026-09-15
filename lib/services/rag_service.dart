import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// A document available in the Nexora RAG knowledge base.
class RagDocument {
  final int id;
  final String title;
  final String subject;
  final int unit;

  const RagDocument({
    required this.id,
    required this.title,
    required this.subject,
    required this.unit,
  });

  factory RagDocument.fromJson(Map<String, dynamic> json) {
    return RagDocument(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      unit: json['unit'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'unit': unit,
    };
  }
}

/// A single retrieved content chunk from the RAG search.
class RagChunk {
  final String content;
  final String title;
  final String subject;
  final int unit;

  const RagChunk({
    required this.content,
    required this.title,
    required this.subject,
    required this.unit,
  });

  factory RagChunk.fromJson(Map<String, dynamic> json) {
    return RagChunk(
      content: json['content'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      unit: json['unit'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'title': title,
      'subject': subject,
      'unit': unit,
    };
  }
}

/// Response wrapper for a RAG search operation.
class RagSearchResponse {
  final String query;
  final List<RagChunk> results;
  final bool success;
  final String? error;

  const RagSearchResponse({
    required this.query,
    required this.results,
    this.success = true,
    this.error,
  });

  bool get hasResults => results.isNotEmpty;

  /// Human-readable source label, e.g. "Data Structures • Unit II"
  String? get sourceLabel {
    if (results.isEmpty) return null;
    final first = results.first;
    final unitRoman = _toRoman(first.unit);
    return '${first.subject} • Unit $unitRoman';
  }

  /// Combine all retrieved chunks into clean, formatted educational text.
  ///
  /// When a future LLM is integrated, pass this text as the retrieval context
  /// instead of displaying it directly.
  String toFormattedContent() {
    if (results.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < results.length; i++) {
      if (i > 0) buffer.write('\n\n');
      buffer.write(_formatChunkText(results[i].content));
    }
    return buffer.toString();
  }

  /// Formats raw chunk content nicely with structured spacing
  static String _formatChunkText(String raw) {
    var text = raw.trim();
    // Normalize excessive multiple spaces into cleaner spacing
    text = text.replaceAll(RegExp(r'\s{3,}'), '\n\n');
    return text;
  }

  factory RagSearchResponse.failure(String query, String errorMessage) {
    return RagSearchResponse(
      query: query,
      results: const [],
      success: false,
      error: errorMessage,
    );
  }

  static String _toRoman(int number) {
    const romanNumerals = {
      10: 'X', 9: 'IX', 5: 'V', 4: 'IV', 1: 'I',
    };
    var result = '';
    var remaining = number;
    for (final entry in romanNumerals.entries) {
      while (remaining >= entry.key) {
        result += entry.value;
        remaining -= entry.key;
      }
    }
    return result.isEmpty ? number.toString() : result;
  }
}

/// A source reference returned by the Nexora conversational AI
class NexoraSource {
  final String title;
  final String url;
  final String? source;
  final String? pageInfo;

  const NexoraSource({
    required this.title,
    required this.url,
    this.source,
    this.pageInfo,
  });

  factory NexoraSource.fromJson(Map<String, dynamic> json) {
    return NexoraSource(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      source: json['source'] as String?,
      pageInfo: json['page_info'] as String?,
    );
  }
}

/// Information about an original college document in the verified BVC repository.
class NexoraDocumentInfo {
  final int? id;
  final String title;
  final String subject;
  final int? unit;
  final String? fileUrl;
  final String? source;
  final bool isAvailable;

  const NexoraDocumentInfo({
    this.id,
    required this.title,
    required this.subject,
    this.unit,
    this.fileUrl,
    this.source,
    this.isAvailable = false,
  });

  factory NexoraDocumentInfo.fromJson(Map<String, dynamic> json) {
    return NexoraDocumentInfo(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      unit: json['unit'] as int?,
      fileUrl: (json['fileUrl'] as String?) ?? (json['file_url'] as String?),
      source: json['source'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'unit': unit,
      'fileUrl': fileUrl,
      'source': source,
      'isAvailable': isAvailable,
    };
  }
}

/// Structured response from the user-facing /chat endpoint
class NexoraChatResponse {
  final String answer;
  final String tool;
  final List<NexoraSource> sources;
  final NexoraDocumentInfo? document;
  final List<NexoraDocumentInfo> documents;
  final String? conversationId;
  final bool success;
  final String? error;

  const NexoraChatResponse({
    required this.answer,
    this.tool = 'explain',
    this.sources = const [],
    this.document,
    this.documents = const [],
    this.conversationId,
    this.success = true,
    this.error,
  });

  factory NexoraChatResponse.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List<dynamic>? ?? [];
    final parsedSources = rawSources
        .map((s) => NexoraSource.fromJson(s as Map<String, dynamic>))
        .toList();

    final docJson = json['document'] as Map<String, dynamic>?;
    final docsJson = json['documents'] as List<dynamic>? ?? [];
    final parsedDocs = docsJson
        .map((d) => NexoraDocumentInfo.fromJson(d as Map<String, dynamic>))
        .toList();

    return NexoraChatResponse(
      answer: json['answer'] as String? ?? '',
      tool: json['tool'] as String? ?? 'explain',
      sources: parsedSources,
      document: docJson != null ? NexoraDocumentInfo.fromJson(docJson) : null,
      documents: parsedDocs,
      conversationId: json['conversation_id'] as String? ?? json['conversationId'] as String?,
      success: true,
    );
  }

  factory NexoraChatResponse.failure(String errorMessage) {
    return NexoraChatResponse(
      answer: '',
      sources: const [],
      document: null,
      documents: const [],
      conversationId: null,
      success: false,
      error: errorMessage,
    );
  }
}

/// A long-term student memory item persisted in Cloudflare D1
class StudentMemoryItem {
  final String id;
  final String memoryText;
  final String category;
  final double importance;
  final DateTime createdAt;

  const StudentMemoryItem({
    required this.id,
    required this.memoryText,
    required this.category,
    required this.importance,
    required this.createdAt,
  });

  factory StudentMemoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return DateTime.now();
    }

    return StudentMemoryItem(
      id: json['id'] as String? ?? '',
      memoryText: json['memory_text'] as String? ?? json['memoryText'] as String? ?? '',
      category: json['category'] as String? ?? 'other_non_sensitive_context',
      importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// RAG Service
// ---------------------------------------------------------------------------

/// Service for communicating with the Nexora Cloudflare Worker RAG API.
///
/// Architecture (ready for future LLM integration):
///
///   User Question
///        ↓
///   RagService.searchDocuments()
///        ↓
///   Retrieved Context (List<RagChunk>)
///        ↓
///   [Future AI Service] <-- plug in LLM here
///        ↓
///   Final Answer
///
/// Currently the retrieved educational content is displayed directly.
/// When an AI provider is added, feed [RagSearchResponse.toFormattedContent()]
/// as the context prompt to the LLM.
class RagService {
  static const String baseUrl =
      'https://nexora-bvc-api-2026.vkola306.workers.dev';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final bool _ownsClient;
  http.Client? _activeChatClient;

  RagService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Cancels the in-flight `/chat` call, if there is one.
  ///
  /// Chat requests receive their own client in production so stopping one
  /// request does not affect future searches or chats.
  bool cancelActiveChatRequest() {
    final activeClient = _activeChatClient;
    if (activeClient == null) return false;

    _activeChatClient = null;
    activeClient.close();
    return true;
  }

  // -------------------------------------------------------------------------
  // GET /documents
  // -------------------------------------------------------------------------

  /// Fetch all available documents from the knowledge base.
  Future<List<dynamic>> getDocuments() async {
    final url = Uri.parse('$baseUrl/documents');
    debugPrint('[RagService] GET $url');

    try {
      final response = await _client.get(url, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          return decoded;
        }
        return [];
      }
      debugPrint('[RagService] GET /documents failed: ${response.statusCode}');
      return [];
    } on SocketException catch (e) {
      debugPrint('[RagService] SocketException: $e');
      return [];
    } on TimeoutException catch (e) {
      debugPrint('[RagService] TimeoutException: $e');
      return [];
    } on FormatException catch (e) {
      debugPrint('[RagService] FormatException: $e');
      return [];
    } catch (e) {
      debugPrint('[RagService] Unexpected error in getDocuments: $e');
      return [];
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Nexora-Flutter-App/1.0',
    };
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('[RagService] Note obtaining Firebase auth token: $e');
    }
    return headers;
  }

  // -------------------------------------------------------------------------
  // POST /chat
  // -------------------------------------------------------------------------

  /// Send student message to the user-facing conversational AI endpoint (/chat).
  /// Returns a clean natural language answer generated by the AI (never raw chunks).
  Future<NexoraChatResponse> sendChatMessage(
    String message, {
    List<Map<String, String>>? conversation,
    String? conversationId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return NexoraChatResponse.failure('Please enter a message.');
    }

    final url = Uri.parse('$baseUrl/chat');
    debugPrint('[RagService] POST $url');

    try {
      final payload = jsonEncode({
        'message': trimmed,
        if (conversation != null && conversation.isNotEmpty)
          'conversation': conversation,
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
      });

      // A dedicated client lets the UI stop an active response without
      // closing the service client used by later requests.
      final chatClient = _ownsClient ? http.Client() : _client;
      if (_ownsClient) {
        _activeChatClient = chatClient;
      }

      final authHeaders = await _getAuthHeaders();

      final response = await chatClient
          .post(
            url,
            headers: authHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('[RagService] POST /chat status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return NexoraChatResponse.fromJson(decoded);
      } else {
        debugPrint('[RagService] POST /chat error: ${response.statusCode} - ${response.body}');
        return NexoraChatResponse.failure('Server returned HTTP ${response.statusCode}');
      }
    } on SocketException {
      return NexoraChatResponse.failure('No internet connection. Please check your network.');
    } on TimeoutException {
      return NexoraChatResponse.failure('Request timed out. Please try again.');
    } on FormatException {
      return NexoraChatResponse.failure('Invalid response format from server.');
    } catch (e) {
      debugPrint('[RagService] Unexpected error in sendChatMessage: $e');
      return NexoraChatResponse.failure('An unexpected error occurred.');
    } finally {
      final activeClient = _activeChatClient;
      if (activeClient != null) {
        _activeChatClient = null;
        activeClient.close();
      }
    }
  }

  // -------------------------------------------------------------------------
  // Student Conversational Memory APIs (Scoped to authenticated student)
  // -------------------------------------------------------------------------

  /// Check whether conversational memory is enabled
  Future<bool> getMemorySettings() async {
    final url = Uri.parse('$baseUrl/student/memory/settings');
    try {
      final headers = await _getAuthHeaders();
      final response = await _client.get(url, headers: headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return decoded['memory_enabled'] as bool? ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('[RagService] getMemorySettings error: $e');
      return true;
    }
  }

  /// Toggle conversational memory ON or OFF
  Future<bool> setMemorySettings(bool enabled) async {
    final url = Uri.parse('$baseUrl/student/memory/settings');
    try {
      final headers = await _getAuthHeaders();
      final response = await _client
          .post(url, headers: headers, body: jsonEncode({'memory_enabled': enabled}))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[RagService] setMemorySettings error: $e');
      return false;
    }
  }

  /// Fetch all active student memories
  Future<List<StudentMemoryItem>> getStudentMemories() async {
    final url = Uri.parse('$baseUrl/student/memories');
    try {
      final headers = await _getAuthHeaders();
      final response = await _client.get(url, headers: headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final rawList = decoded['memories'] as List<dynamic>? ?? [];
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((m) => StudentMemoryItem.fromJson(m))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[RagService] getStudentMemories error: $e');
      return [];
    }
  }

  /// Delete a single memory
  Future<bool> deleteStudentMemory(String memoryId) async {
    final url = Uri.parse('$baseUrl/student/memories/$memoryId');
    try {
      final headers = await _getAuthHeaders();
      final response = await _client.delete(url, headers: headers).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[RagService] deleteStudentMemory error: $e');
      return false;
    }
  }

  /// Clear all saved memories
  Future<bool> clearAllStudentMemories() async {
    final url = Uri.parse('$baseUrl/student/memories');
    try {
      final headers = await _getAuthHeaders();
      final response = await _client.delete(url, headers: headers).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[RagService] clearAllStudentMemories error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // GET /search?q=QUERY
  // -------------------------------------------------------------------------

  /// Search the knowledge base for relevant educational content chunks.
  /// Handles URL encoding, network errors, timeouts, invalid JSON,
  /// and includes intelligent keyword fallback for natural language questions.
  Future<List<dynamic>> searchDocuments(String query) async {
    final searchRes = await searchDocumentsStructured(query);
    if (!searchRes.success || searchRes.results.isEmpty) {
      return [];
    }
    return searchRes.results.map((c) => c.toJson()).toList();
  }

  /// Structured RAG search method returning [RagSearchResponse]
  Future<RagSearchResponse> searchDocumentsStructured(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return RagSearchResponse.failure(query, 'Please enter a question.');
    }

    try {
      // 1. Direct search with user query (using Uri query parameters for proper encoding)
      final initialResults = await _executeSearch(trimmed);
      if (initialResults.isNotEmpty) {
        return RagSearchResponse(
          query: trimmed,
          results: initialResults,
        );
      }

      // 2. Intelligent keyword fallback if natural question yielded 0 exact results
      final fallbackQuery = _extractKeywords(trimmed);
      if (fallbackQuery.isNotEmpty && fallbackQuery.toLowerCase() != trimmed.toLowerCase()) {
        debugPrint('[RagService] Trying keyword fallback search: "$fallbackQuery"');
        final fallbackResults = await _executeSearch(fallbackQuery);
        if (fallbackResults.isNotEmpty) {
          return RagSearchResponse(
            query: trimmed,
            results: fallbackResults,
          );
        }
      }

      // 3. No chunks found in knowledge base
      return RagSearchResponse(
        query: trimmed,
        results: const [],
      );
    } on HttpException catch (e) {
      return RagSearchResponse.failure(
        trimmed,
        e.message,
      );
    } on SocketException {
      return RagSearchResponse.failure(
        trimmed,
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      return RagSearchResponse.failure(
        trimmed,
        'The request timed out. Please try again.',
      );
    } on FormatException {
      return RagSearchResponse.failure(
        trimmed,
        'Unexpected response format from the knowledge base.',
      );
    } catch (e) {
      debugPrint('[RagService] Unexpected error in searchDocuments: $e');
      return RagSearchResponse.failure(
        trimmed,
        'An unexpected error occurred while searching. Please try again.',
      );
    }
  }

  /// Internal HTTP call to /search?q={query}
  Future<List<RagChunk>> _executeSearch(String query) async {
    final url = Uri.parse('$baseUrl/search').replace(
      queryParameters: {'q': query},
    );
    debugPrint('[RagService] GET $url');

    final response = await _client.get(url, headers: _headers).timeout(_timeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      final rawResults = json['results'] as List<dynamic>? ?? [];
      return rawResults
          .whereType<Map<String, dynamic>>()
          .map((e) => RagChunk.fromJson(e))
          .toList();
    } else if (response.statusCode >= 500) {
      debugPrint('[RagService] Search HTTP error: ${response.statusCode}');
      throw const HttpException('The server encountered an error.');
    } else {
      debugPrint('[RagService] Search HTTP error: ${response.statusCode}');
      return [];
    }
  }

  /// Extracts key search terms from natural language student questions.
  String _extractKeywords(String question) {
    const stopWords = {
      'what', 'is', 'a', 'an', 'the', 'explain', 'describe', 'tell', 'me',
      'about', 'define', 'how', 'does', 'do', 'can', 'you', 'give', 'detail',
      'details', 'of', 'in', 'and', 'or', 'for', 'with', 'to', 'from',
    };

    final cleaned = question
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .toLowerCase();
    
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toList();

    return words.join(' ');
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'User-Agent': 'Nexora-Flutter-App/1.0',
      };

  void dispose() {
    cancelActiveChatRequest();
    _client.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final ragServiceProvider = Provider<RagService>((ref) {
  final service = RagService();
  ref.onDispose(() => service.dispose());
  return service;
});
