import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/chat/data/chat_repository.dart';

void main() {
  group('ChatRepository.filterConversations Tests', () {
    late ChatRepository repository;
    final time1 = DateTime(2026, 9, 1, 10, 0);
    final time2 = DateTime(2026, 9, 2, 11, 0);
    final time3 = DateTime(2026, 9, 3, 12, 0);

    final sampleConversations = [
      ChatConversation(
        id: 'conv-1',
        title: 'BVC Exam Timetable 2026',
        createdAt: time1,
        updatedAt: time1,
        isPinned: true,
        lastMessage: 'Mid examinations commence on October 12.',
      ),
      ChatConversation(
        id: 'conv-2',
        title: 'Library Timings and Books',
        createdAt: time2,
        updatedAt: time2,
        isPinned: false,
        lastMessage: 'Central library closes at 8 PM on weekdays.',
      ),
      ChatConversation(
        id: 'conv-3',
        title: 'Fee Payment Guidelines',
        createdAt: time3,
        updatedAt: time3,
        isPinned: false,
        lastMessage: 'Submit fee receipt to administrative office.',
      ),
    ];

    setUp(() {
      repository = ChatRepository();
    });

    test('exact title match returns matching conversation', () {
      final results = repository.filterConversations(
        sampleConversations,
        'Fee Payment Guidelines',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('conv-3'));
      expect(results.first.title, equals('Fee Payment Guidelines'));
    });

    test('partial title match returns matching conversation', () {
      final results = repository.filterConversations(
        sampleConversations,
        'Timetable',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('conv-1'));
    });

    test('case-insensitive title match returns matching conversation', () {
      final results = repository.filterConversations(
        sampleConversations,
        'bvc exam',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('conv-1'));
    });

    test('lastMessage match returns matching conversation', () {
      final results = repository.filterConversations(
        sampleConversations,
        'Central library closes',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('conv-2'));
    });

    test('partial lastMessage match returns matching conversation', () {
      final results = repository.filterConversations(
        sampleConversations,
        'administrative office',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('conv-3'));
    });

    test('query with leading and trailing whitespace is trimmed properly', () {
      final results = repository.filterConversations(
        sampleConversations,
        '   Library   ',
      );
      expect(results.length, equals(1));
      expect(results.first.id, equals('conv-2'));
    });

    test('empty query returns original conversations in same order', () {
      final results = repository.filterConversations(sampleConversations, '');
      expect(results.length, equals(3));
      expect(results[0].id, equals('conv-1'));
      expect(results[1].id, equals('conv-2'));
      expect(results[2].id, equals('conv-3'));
    });

    test('whitespace-only query returns original conversations in same order', () {
      final results = repository.filterConversations(sampleConversations, '   ');
      expect(results.length, equals(3));
      expect(results[0].id, equals('conv-1'));
      expect(results[1].id, equals('conv-2'));
      expect(results[2].id, equals('conv-3'));
    });

    test('empty conversation list returns empty list', () {
      final results = repository.filterConversations([], 'exam');
      expect(results, isEmpty);
    });

    test('no-match query returns empty list', () {
      final results = repository.filterConversations(
        sampleConversations,
        'NonexistentQuery12345',
      );
      expect(results, isEmpty);
    });

    test('preserves conversation ordering when multiple matches exist', () {
      // Both conv-1 and conv-2 contain 'Tim' in title ('Timetable' and 'Timings')
      final results = repository.filterConversations(sampleConversations, 'Tim');
      expect(results.length, equals(2));
      expect(results[0].id, equals('conv-1'));
      expect(results[1].id, equals('conv-2'));
    });

    test('preserves pinned status and all metadata', () {
      final results = repository.filterConversations(sampleConversations, 'Exam');
      expect(results.length, equals(1));
      final conv = results.first;
      expect(conv.id, equals('conv-1'));
      expect(conv.isPinned, isTrue);
      expect(conv.createdAt, equals(time1));
      expect(conv.updatedAt, equals(time1));
      expect(conv.lastMessage, equals('Mid examinations commence on October 12.'));
    });

    test('original list is not mutated', () {
      final listCopy = List<ChatConversation>.from(sampleConversations);
      repository.filterConversations(sampleConversations, 'Exam');
      expect(sampleConversations.length, equals(listCopy.length));
      for (int i = 0; i < sampleConversations.length; i++) {
        expect(sampleConversations[i].id, equals(listCopy[i].id));
      }
    });
  });
}
