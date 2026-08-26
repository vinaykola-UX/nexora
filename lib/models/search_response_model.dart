/// Represents an individual search result from official BVC College portals
class SearchResultItem {
  final String title;
  final String url;
  final String source;
  final String snippet;
  final String? publishedDate;

  const SearchResultItem({
    required this.title,
    required this.url,
    required this.source,
    required this.snippet,
    this.publishedDate,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      source: json['source'] as String? ?? 'BVC Engineering College',
      snippet: json['snippet'] as String? ?? '',
      publishedDate: json['publishedDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'source': source,
      'snippet': snippet,
      'publishedDate': publishedDate,
    };
  }
}

/// Represents an official source reference
class SourceInfo {
  final String title;
  final String url;

  const SourceInfo({
    required this.title,
    required this.url,
  });

  factory SourceInfo.fromJson(Map<String, dynamic> json) {
    return SourceInfo(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }
}

/// Root response model for Nexora official retrieval search endpoint
class NexoraSearchResponse {
  final bool success;
  final String query;
  final List<SearchResultItem> results;
  final List<SourceInfo> sources;
  final String? message;
  final String? error;

  const NexoraSearchResponse({
    required this.success,
    required this.query,
    this.results = const [],
    this.sources = const [],
    this.message,
    this.error,
  });

  factory NexoraSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'] as List<dynamic>? ?? [];
    final resultsList = rawResults
        .whereType<Map<String, dynamic>>()
        .map((e) => SearchResultItem.fromJson(e))
        .toList();

    final rawSources = json['sources'] as List<dynamic>? ?? [];
    final sourcesList = rawSources
        .whereType<Map<String, dynamic>>()
        .map((e) => SourceInfo.fromJson(e))
        .toList();

    return NexoraSearchResponse(
      success: json['success'] as bool? ?? false,
      query: json['query'] as String? ?? '',
      results: resultsList,
      sources: sourcesList,
      message: json['message'] as String?,
      error: json['error'] as String?,
    );
  }

  factory NexoraSearchResponse.failure(String query, String errorMessage) {
    return NexoraSearchResponse(
      success: false,
      query: query,
      results: const [],
      sources: const [],
      error: errorMessage,
    );
  }
}
