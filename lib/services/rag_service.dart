import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  RagService({http.Client? client}) : _client = client ?? http.Client();

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
