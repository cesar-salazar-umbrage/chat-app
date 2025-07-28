import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_models.dart';
import '../main.dart';

class ChatService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _currentChatId;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  String? get currentChatId => _currentChatId;

  Future<String> createChatSession(Philosopher philosopher) async {
    final now = DateTime.now();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final chatSession = ChatSession(
      id: '',
      userId: uid ?? '',
      philosopherId: philosopher.name,
      philosopherName: philosopher.name,
      createdAt: now,
      lastMessageAt: now,
    );

    final docRef =
        await _firestore.collection('chats').add(chatSession.toFirestore());
    _currentChatId = docRef.id;

    await _addWelcomeMessage(philosopher);
    return docRef.id;
  }

  Future<String?> getExistingChatId(String philosopherName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final query = await _firestore
        .collection('chats')
        .where('userId', isEqualTo: uid)
        .where('philosopherId', isEqualTo: philosopherName)
        .orderBy('lastMessageAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  Future<void> _addWelcomeMessage(Philosopher philosopher) async {
    if (_currentChatId == null) return;

    final welcomeMessage = ChatMessage(
      id: '',
      text:
          'Greetings! I am ${philosopher.name}. How may I guide your thoughts today?',
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    await _firestore
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .add(welcomeMessage.toFirestore());
  }

  Stream<List<ChatMessage>> getMessagesStream(String chatId) {
    _currentChatId = chatId;
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) {
      _messages.clear();
      _messages.addAll(
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
      return _messages;
    });
  }

  Future<void> sendMessage(String text, Philosopher philosopher) async {
    if (_currentChatId == null || text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: '',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    final docRef = await _firestore
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .add(userMessage.toFirestore());

    await docRef
        .update({'status': MessageStatus.sent.toString().split('.').last});

    _setTyping(true);
    await _generateAIResponse(philosopher);
  }

  Future<void> _generateAIResponse(Philosopher philosopher) async {
    try {
      final conversationHistory = _messages
          .where((msg) => msg.status == MessageStatus.sent)
          .map((msg) =>
              '${msg.isUser ? "Human" : philosopher.name}: ${msg.text}')
          .toList();

      final response = await _callPhilosopherCloudFunction(
        philosopher.name,
        _messages.last.text,
        conversationHistory,
      );

      final aiMessage = ChatMessage(
        id: '',
        text: response,
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .add(aiMessage.toFirestore());

      await _firestore.collection('chats').doc(_currentChatId).update({
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error generating AI response: $e');

      final errorMessage = ChatMessage(
        id: '',
        text: _getErrorMessage(e),
        isUser: false,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );

      await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .add(errorMessage.toFirestore());
    } finally {
      _setTyping(false);
    }
  }

  Future<String> _callPhilosopherCloudFunction(
    String philosopherId,
    String message,
    List<String> conversationHistory,
  ) async {
    try {
      final callable =
          _functions.httpsCallable('getPhilosopherResponseCallable');
      final result = await callable.call({
        'message': message,
        'philosopherId': philosopherId,
        'conversationHistory': conversationHistory,
      });

      if (result.data['success'] == true) {
        return result.data['response'] as String;
      } else {
        throw Exception(
            result.data['error'] ?? 'Unknown error from Cloud Function');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      throw Exception(_getCloudFunctionErrorMessage(e));
    } catch (e) {
      debugPrint('Network error calling Cloud Function: $e');
      throw Exception(
          'Network error. Please check your connection and try again.');
    }
  }

  String _getCloudFunctionErrorMessage(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'resource-exhausted':
        return 'The AI service is currently busy. Please try again in a moment.';
      case 'invalid-argument':
        return 'There was an issue with your message. Please try rephrasing it.';
      case 'internal':
        return 'The AI service is temporarily unavailable. Please try again later.';
      case 'unauthenticated':
        return 'Authentication required. Please restart the app.';
      default:
        return 'Unable to get a response right now. Please try again.';
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('network') ||
        error.toString().contains('connection')) {
      return 'Network connection issue. Please check your internet and try again.';
    } else if (error.toString().contains('quota') ||
        error.toString().contains('rate limit')) {
      return 'The AI service is currently busy. Please try again in a few minutes.';
    } else {
      return 'I apologize, but I\'m having trouble responding right now. Please try again.';
    }
  }

  void _setTyping(bool typing) {
    _isTyping = typing;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _currentChatId = null;
    _isTyping = false;
    notifyListeners();
  }

  Future<bool> testCloudFunction() async {
    try {
      final callable = _functions.httpsCallable('testPhilosopherResponse');
      final result = await callable.call();
      debugPrint('Cloud Function test result: ${result.data}');
      return true;
    } catch (e) {
      debugPrint('Cloud Function test failed: $e');
      return false;
    }
  }

  Future<List<ChatSession>> fetchUserChatSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final querySnapshot = await _firestore
        .collection('chats')
        .orderBy('lastMessageAt', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => ChatSession.fromFirestore(doc))
        .toList();
  }

  Future<void> deleteChatSession(String chatId) async {
    final messagesRef =
        _firestore.collection('chats').doc(chatId).collection('messages');

    final messages = await messagesRef.get();
    for (final doc in messages.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('chats').doc(chatId).delete();
  }
}
