import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/chat/data/chat_repository.dart';
import 'package:nexora/models/search_response_model.dart';

void main() {
  group('ChatPersistence Model Tests', () {
    test('ChatConversation model maps to and from Map correctly', () {
      final now = DateTime(2026, 8, 26, 12, 0, 0);
      final conv = ChatConversation(
        id: 'conv-123',
        title: 'BR23 Exam Dates',
        createdAt: now,
        updatedAt: now,
        isPinned: true,
        lastMessage: 'Found 2 official updates...',
      );

      final map = conv.toMap();
      expect(map['title'], equals('BR23 Exam Dates'));
      expect(map['isPinned'], isTrue);
      expect(map['lastMessage'], equals('Found 2 official updates...'));
    });

    test('PersistedChatMessage model preserves searchResponse and sources', () {
      final now = DateTime.now();
      final searchResponse = NexoraSearchResponse(
        success: true,
        query: 'BR23',
        results: const [
          SearchResultItem(
            title: 'B.Tech Supplementary',
            url: 'https://bvcec.edu.in/exam',
            source: 'BVC Engineering College',
            snippet: 'Exams begin from September 2026',
            publishedDate: 'August 2026',
          ),
        ],
        sources: const [
          SourceInfo(
            title: 'BVC Engineering College',
            url: 'https://bvcec.edu.in',
          ),
        ],
      );

      final msg = PersistedChatMessage(
        id: 'msg-456',
        text: 'Found 1 official update for BR23:',
        isUser: false,
        timestamp: now,
        searchResponse: searchResponse,
      );

      final map = msg.toMap();
      expect(map['isUser'], isFalse);
      expect(map['text'], contains('Found 1'));
      expect(map['searchResponse'], isNotNull);
      expect(map['searchResponse']['query'], equals('BR23'));
      expect(map['searchResponse']['results'], isNotEmpty);
      expect(map['searchResponse']['results'][0]['title'], equals('B.Tech Supplementary'));
      expect(map['searchResponse']['sources'][0]['title'], equals('BVC Engineering College'));
    });

    test('PersistedChatMessage correctly handles user query messages', () {
      final now = DateTime.now();
      final userMsg = PersistedChatMessage(
        id: 'msg-user-1',
        text: 'When are BR23 mid exams?',
        isUser: true,
        timestamp: now,
      );

      final map = userMsg.toMap();
      expect(map['isUser'], isTrue);
      expect(map['text'], equals('When are BR23 mid exams?'));
      expect(map['searchResponse'], isNull);
    });
  });
}
