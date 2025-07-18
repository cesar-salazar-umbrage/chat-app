import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
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
    final chatSession = ChatSession(
      id: '',
      philosopherId: philosopher.name,
      philosopherName: philosopher.name,
      createdAt: now,
      lastMessageAt: now,
    );

    final docRef =
        await _firestore.collection('chats').add(chatSession.toFirestore());
    _currentChatId = docRef.id;

    // Add welcome message
    await _addWelcomeMessage(philosopher);

    return docRef.id;
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
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      _messages.clear();
      _messages.addAll(
        snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList(),
      );
      return _messages;
    });
  }

  Future<void> sendMessage(String text, Philosopher philosopher) async {
    if (_currentChatId == null || text.trim().isEmpty) return;

    // Create user message
    final userMessage = ChatMessage(
      id: '',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Add to Firestore
    final docRef = await _firestore
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .add(userMessage.toFirestore());

    // Update message status to sent
    await docRef
        .update({'status': MessageStatus.sent.toString().split('.').last});

    // Show typing indicator
    _setTyping(true);

    // Generate AI response
    await _generateAIResponse(philosopher);
  }

  Future<void> _generateAIResponse(Philosopher philosopher) async {
    try {
      // Get conversation history for context
      final conversationHistory = _messages
          .where((msg) => msg.status == MessageStatus.sent)
          .map((msg) =>
              '${msg.isUser ? "Human" : philosopher.name}: ${msg.text}')
          .toList();

      // Call Cloud Function for AI response
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

      // Update chat session last message time
      await _firestore.collection('chats').doc(_currentChatId).update({
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error generating AI response: $e');

      // Add error message
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

  // Method to test Cloud Function connectivity
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
}
