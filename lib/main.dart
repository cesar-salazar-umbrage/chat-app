import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math';

import 'services/chat_service.dart';
import 'models/chat_models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAuth.instance.signInAnonymously();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatService()),
      ],
      child: MaterialApp(
        title: 'Philosopher Chat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const PhilosopherSelectionPage(),
      ),
    );
  }
}

class Quote {
  final String text;
  final String author;
  final String date;
  bool isFavorited;

  Quote({
    required this.text,
    required this.author,
    required this.date,
    this.isFavorited = false,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      text: json['text'],
      author: json['author'],
      date: json['date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'author': author,
      'date': date,
      'isFavorited': isFavorited,
    };
  }
}

class QuoteService {
  static List<Quote> _quotes = [];
  static Quote? _currentQuote;

  static Future<void> loadQuotes() async {
    try {
      final String response = await rootBundle.loadString('assets/quotes.json');
      final List<dynamic> data = json.decode(response);
      _quotes = data.map((json) => Quote.fromJson(json)).toList();
      await _loadFavorites();
      _setDailyQuote();
    } catch (e) {
      print('Error loading quotes: $e');
    }
  }

  static Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteQuotes = prefs.getStringList('favorite_quotes') ?? [];

    for (var quote in _quotes) {
      quote.isFavorited = favoriteQuotes.contains(quote.text);
    }
  }

  static Future<void> toggleFavorite(Quote quote) async {
    quote.isFavorited = !quote.isFavorited;
    await _saveFavorites();
  }

  static Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteQuotes = _quotes
        .where((quote) => quote.isFavorited)
        .map((quote) => quote.text)
        .toList();
    await prefs.setStringList('favorite_quotes', favoriteQuotes);
  }

  static void _setDailyQuote() {
    if (_quotes.isNotEmpty) {
      final dayOfYear =
          DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      _currentQuote = _quotes[dayOfYear % _quotes.length];
    }
  }

  static Quote? getCurrentQuote() => _currentQuote;

  static void refreshQuote() {
    if (_quotes.isNotEmpty) {
      final random = Random();
      _currentQuote = _quotes[random.nextInt(_quotes.length)];
    }
  }

  static List<Quote> getFavoriteQuotes() {
    return _quotes.where((quote) => quote.isFavorited).toList();
  }
}

class Philosopher {
  final String name;
  final String description;
  final String systemPrompt;
  final String previewQuote;
  final IconData icon;

  const Philosopher({
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.previewQuote,
    required this.icon,
  });
}

class PhilosopherSelectionPage extends StatefulWidget {
  const PhilosopherSelectionPage({super.key});

  @override
  State<PhilosopherSelectionPage> createState() =>
      _PhilosopherSelectionPageState();
}

class _PhilosopherSelectionPageState extends State<PhilosopherSelectionPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Quote? _currentQuote;
  bool _isLoading = true;

  static const List<Philosopher> philosophers = [
    Philosopher(
      name: 'Socrates',
      description:
          'Ancient Greek philosopher known for the Socratic method and questioning everything.',
      systemPrompt:
          'You are Socrates. Respond with questions that lead to deeper understanding. Use the Socratic method to guide conversations.',
      previewQuote: '"The only true wisdom is in knowing you know nothing."',
      icon: Icons.psychology,
    ),
    Philosopher(
      name: 'Marcus Aurelius',
      description:
          'Roman Emperor and Stoic philosopher focused on virtue, duty, and inner peace.',
      systemPrompt:
          'You are Marcus Aurelius. Speak with stoic wisdom, emphasizing virtue, acceptance, and duty. Be practical and grounded.',
      previewQuote:
          '"You have power over your mind - not outside events. Realize this, and you will find strength."',
      icon: Icons.shield,
    ),
    Philosopher(
      name: 'Lao Tzu',
      description:
          'Ancient Chinese philosopher and founder of Taoism, teaching harmony with nature.',
      systemPrompt:
          'You are Lao Tzu. Speak in paradoxes and simple truths. Emphasize balance, wu wei (non-action), and harmony with the Tao.',
      previewQuote: '"The journey of a thousand miles begins with one step."',
      icon: Icons.temple_buddhist,
    ),
    Philosopher(
      name: 'Buddha',
      description:
          'Enlightened teacher who founded Buddhism, focusing on suffering and liberation.',
      systemPrompt:
          'You are Buddha. Teach about the Four Noble Truths, impermanence, and compassion. Speak with gentle wisdom.',
      previewQuote: '"Peace comes from within. Do not seek it without."',
      icon: Icons.self_improvement,
    ),
    Philosopher(
      name: 'Nietzsche',
      description:
          'German philosopher who challenged traditional values and proclaimed individual will.',
      systemPrompt:
          'You are Nietzsche. Be provocative and challenge conventional thinking. Emphasize individual will and self-creation.',
      previewQuote: '"What does not kill me, makes me stronger."',
      icon: Icons.bolt,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _loadQuoteOfTheDay();
  }

  Future<void> _loadQuoteOfTheDay() async {
    await QuoteService.loadQuotes();
    setState(() {
      _currentQuote = QuoteService.getCurrentQuote();
      _isLoading = false;
    });
    _animationController.forward();
  }

  void _refreshQuote() {
    _animationController.reverse().then((_) {
      QuoteService.refreshQuote();
      setState(() {
        _currentQuote = QuoteService.getCurrentQuote();
      });
      _animationController.forward();
    });
  }

  void _toggleFavorite() async {
    if (_currentQuote != null) {
      await QuoteService.toggleFavorite(_currentQuote!);
      setState(() {});
    }
  }

  IconData _getPhilosopherIcon(String author) {
    switch (author) {
      case 'Socrates':
        return Icons.psychology;
      case 'Marcus Aurelius':
        return Icons.shield;
      case 'Lao Tzu':
        return Icons.temple_buddhist;
      case 'Buddha':
        return Icons.self_improvement;
      case 'Nietzsche':
        return Icons.bolt;
      default:
        return Icons.format_quote;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Philosopher'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quote of the Day Section
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_currentQuote != null)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getPhilosopherIcon(_currentQuote!.author),
                              size: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Quote of the Day',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                _currentQuote!.isFavorited
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _currentQuote!.isFavorited
                                    ? Colors.red
                                    : null,
                              ),
                              onPressed: _toggleFavorite,
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _refreshQuote,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"${_currentQuote!.text}"',
                          style: const TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '— ${_currentQuote!.author}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const Text(
              'Select a philosopher to guide your conversation:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: philosophers.length,
                itemBuilder: (context, index) {
                  final philosopher = philosophers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                philosopher.icon,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  philosopher.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            philosopher.description,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              philosopher.previewQuote,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChatPage(philosopher: philosopher),
                                  ),
                                );
                              },
                              child: const Text('Select'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Quote> _favoriteQuotes = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  void _loadFavorites() {
    setState(() {
      _favoriteQuotes = QuoteService.getFavoriteQuotes();
    });
  }

  IconData _getPhilosopherIcon(String author) {
    switch (author) {
      case 'Socrates':
        return Icons.psychology;
      case 'Marcus Aurelius':
        return Icons.shield;
      case 'Lao Tzu':
        return Icons.temple_buddhist;
      case 'Buddha':
        return Icons.self_improvement;
      case 'Nietzsche':
        return Icons.bolt;
      default:
        return Icons.format_quote;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Quotes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _favoriteQuotes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No favorite quotes yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start favoriting quotes to see them here!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _favoriteQuotes.length,
              itemBuilder: (context, index) {
                final quote = _favoriteQuotes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getPhilosopherIcon(quote.author),
                              size: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              quote.author,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon:
                                  const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () async {
                                await QuoteService.toggleFavorite(quote);
                                _loadFavorites();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"${quote.text}"',
                          style: const TextStyle(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final Philosopher philosopher;

  const ChatPage({super.key, required this.philosopher});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late ChatService _chatService;
  String? _chatId;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _chatService = Provider.of<ChatService>(context, listen: false);
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      _chatId = await _chatService.createChatSession(widget.philosopher);
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      // Handle error - maybe show a snackbar
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _chatId == null) return;

    _chatService.sendMessage(_messageController.text, widget.philosopher);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.philosopher.name} is thinking',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (message.status == MessageStatus.sending) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isUser
                            ? Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.7)
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sending...',
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.7)
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
            if (message.status == MessageStatus.error) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 12,
                    color: Colors.red.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Failed to send',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(widget.philosopher.icon),
              const SizedBox(width: 8),
              Text('Chat with ${widget.philosopher.name}'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.philosopher.icon),
            const SizedBox(width: 8),
            Text('Chat with ${widget.philosopher.name}'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesStream(_chatId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];

                // Auto-scroll when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return Consumer<ChatService>(
                  builder: (context, chatService, child) {
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          messages.length + (chatService.isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length && chatService.isTyping) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(messages[index]);
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Ask your question...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<ChatService>(
                  builder: (context, chatService, child) {
                    return IconButton(
                      onPressed: chatService.isTyping ? null : _sendMessage,
                      icon: const Icon(Icons.send),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
