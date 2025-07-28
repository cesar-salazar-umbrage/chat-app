import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../main.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  late ChatService _chatService;
  bool _isLoading = true;
  List<ChatSession> _sessions = [];
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
    _chatService = Provider.of<ChatService>(context, listen: false);
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final sessions = await _chatService.fetchUserChatSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  void _resumeChat(ChatSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          philosopher: getPhilosopherByName(session.philosopherId),
          existingChatId: session.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Text('No previous chats found.'),
                )
              : ListView.separated(
                  separatorBuilder: (context, index) => const Divider(),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    final philosopher =
                        getPhilosopherByName(session.philosopherId);

                    final tile = ListTile(
                      leading: Icon(
                        philosopher.icon,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(philosopher.name),
                      subtitle: Text(
                        'Last chatted: ${DateFormat.yMMMd().add_jm().format(session.lastMessageAt)}',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _resumeChat(session),
                    );

                    return Dismissible(
                      key: Key(session.id),
                      background: Container(color: Colors.red[300]),
                      onDismissed: (direction) {
                        setState(() {
                          _sessions.removeAt(index);
                        });
                        _chatService.deleteChatSession(session.id);

                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(
                            content:
                                Text('${philosopher.name} chat dismissed')));
                      },
                      child: tile,
                    );
                  },
                ),
    );
  }

  Philosopher getPhilosopherByName(String name) {
    return philosophers.firstWhere(
      (p) => p.name == name,
      orElse: () => philosophers.first,
    );
  }
}
