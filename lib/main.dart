import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Philosopher Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PhilosopherSelectionPage(),
    );
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

class PhilosopherSelectionPage extends StatelessWidget {
  const PhilosopherSelectionPage({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Philosopher'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                              color:
                                  Theme.of(context).colorScheme.surfaceVariant,
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
}

class ChatPage extends StatefulWidget {
  final Philosopher philosopher;

  const ChatPage({super.key, required this.philosopher});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Add welcome message from the philosopher
    _messages.add(ChatMessage(
      text:
          'Greetings! I am ${widget.philosopher.name}. How may I guide your thoughts today?',
      isUser: false,
    ));
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: _messageController.text,
        isUser: true,
      ));

      // Simple echo response for now - this is where you'd integrate with an AI service
      _messages.add(ChatMessage(
        text:
            'As ${widget.philosopher.name} would say: "${widget.philosopher.previewQuote}" (This is a placeholder response)',
        isUser: false,
      ));
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
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
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
