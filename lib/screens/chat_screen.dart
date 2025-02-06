import 'dart:convert';

import 'package:athena/models/message.dart';
import 'package:athena/models/session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:athena/services/openrouter_api.dart';
import 'package:athena/widgets/chat_bubble.dart';
import '../widgets/message_input.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart'; // For asset loading

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  Color _bgColor = Colors.grey[200]!;
  Color _textColor = Colors.black;
  bool _isDarkMode = false;
  late AudioPlayer _audioPlayer;

  // Animation controllers for new message transitions
  late AnimationController _listAnimationController;
  late Animation<double> _listAnimation;

  @override
  void initState() {
    _audioPlayer = AudioPlayer();

    super.initState();
    _loadTheme(); // Load the saved theme preference

    // Initialize list animation controller
    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _listAnimation = CurvedAnimation(
      parent: _listAnimationController,
      curve: Curves.easeOutCubic,
    );

    // Add initial message with animation
    _messages.add({
      "role": "assistant",
      "content": "Hello! How can I help you today?",
      "animationController": _createAnimationController(),
    });

    // Start initial message animation
    _messages.first["animationController"].forward();
  }

  _loadTheme() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('isDarkMode') ?? false;
        _bgColor = _isDarkMode ? Colors.black87 : Colors.grey[200]!;
        _textColor = _isDarkMode ? Colors.white : Colors.black;
      });
    } catch (e) {
      print('Error loading theme: $e');
    }
  }

  _saveTheme(bool isDarkMode) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode);
    } catch (e) {
      print('Error saving theme: $e');
    }
  }

  AnimationController _createAnimationController() {
    return AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // Function to play the send sound asynchronously
  Future<void> _playSendMessageSound() async {
    try {
      await _audioPlayer.setAsset('assets/audio/sent.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing send message sound: $e");
    }
  }

// Function to play the received sound asynchronously
  Future<void> _playReceivedMessageSound() async {
    try {
      await _audioPlayer.setAsset('assets/audio/reciveved.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing received message sound: $e");
    }
  }

// Your original _sendMessage method
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    _playSendMessageSound();

    final userMessageController = _createAnimationController();
    final loadingMessageController = _createAnimationController();

    setState(() {
      _messages.add({
        "role": "user",
        "content": message,
        "animationController": userMessageController,
      });
      _messages.add({
        "role": "assistant",
        "content": "Loading...",
        "isLoading": true,
        "animationController": loadingMessageController,
      });
      _isTyping = true;
    });

    userMessageController.forward();
    loadingMessageController.forward();
    _scrollToBottom();

    // Make the actual API call using the sessionId (if available)
    final APIResponse response = await OpenRouterAPI.fetchAIResponse(message);

    final assistantMessageController = _createAnimationController();

    setState(() {
      _isTyping = false;
      loadingMessageController.dispose();
      _messages.removeLast(); // Remove the loading message

      _messages.add({
        "role": "assistant",
        "content": response.isSuccess
            ? response.content!
            : (response.error ?? "An error occurred"),
        "isError": !response.isSuccess,
        "animationController": assistantMessageController,
      });
    });

    _playReceivedMessageSound();
    assistantMessageController.forward();
    _scrollToBottom();
  }

  void _launchURL() async {
    final Uri url = Uri.parse('https://github.com/golanpiyush');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      _bgColor = _isDarkMode ? Colors.black87 : Colors.grey[200]!;
      _textColor = _isDarkMode ? Colors.white : Colors.black;
    });
    _saveTheme(_isDarkMode); // Save the new theme preference
  }

  Future<List<String>> _fetchSessionTitles() async {
    List<Session> sessions =
        await OpenRouterAPI.getRecentSessions(); // Fetch sessions
    return sessions.map((session) => session.title).toList(); // Extract titles
  }

  // Navigate to the session screen with the selected session
  void _navigateToSession(String sessionName) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsString = prefs.getString('sessions_history');
    if (sessionsString != null) {
      Map<String, dynamic> sessions = json.decode(sessionsString);
      final conversationHistory = List<Map<String, String>>.from(
          sessions[sessionName].map((item) => Map<String, String>.from(item)));

      // Append conversation history to the _messages list
      setState(() {
        _messages.insertAll(0,
            conversationHistory); // Insert at the beginning of the conversation
      });

      // Scroll to the bottom to show the newly added messages
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        elevation: 1,
        title: Text(
          "Athena 2.4",
          style: TextStyle(
            fontFamily: 'SFDisplayPro', // Use the custom font family here
            fontSize: 20,
            fontWeight: FontWeight.bold, // Bold for AppBar text
            color: _textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: _textColor),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: _isDarkMode ? Colors.black87 : Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.greenAccent : Colors.blue,
                ),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontFamily: 'SFDisplayPro',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ),
              ListTile(
                title: Text(
                  'About',
                  style:
                      TextStyle(fontFamily: 'SFDisplayPro', color: _textColor),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor:
                          _isDarkMode ? Colors.black87 : Colors.white,
                      title: Text(
                        'About',
                        style: TextStyle(
                            fontFamily: 'SFDisplayPro', color: _textColor),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Piyush (Flywich)',
                            style: TextStyle(
                                fontFamily: 'SFDisplayPro', color: _textColor),
                          ),
                          SizedBox(height: 10),
                          InkWell(
                            onTap: _launchURL,
                            child: Row(
                              children: [
                                Icon(Icons.link, color: _textColor),
                                SizedBox(width: 5),
                                Text(
                                  'GitHub Profile',
                                  style: TextStyle(
                                      fontFamily: 'SFDisplayPro',
                                      color: _textColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                title: Text(
                  'Toggle Dark Mode',
                  style:
                      TextStyle(fontFamily: 'SFDisplayPro', color: _textColor),
                ),
                onTap: _toggleDarkMode,
              ),

              // Display session names from getRecentSessions

              FutureBuilder<List<String>>(
                future:
                    _fetchSessionTitles(), // Call an async function that gets session titles
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  List<String> sessionTitles = snapshot.data ?? [];

                  return Column(
                    children: [
                      // New Conversation tile
                      ListTile(
                        leading: Icon(Icons.add, color: _textColor),
                        title: Text(
                          'New Conversation',
                          style: TextStyle(
                            fontFamily: 'SFDisplayPro',
                            color: _textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
                          print("New Conversation button tapped!");

                          setState(() {
                            _messages.clear(); // Clear previous messages
                          });

                          String initialMessage =
                              "Hello! How can I help you today?";
                          print("Initial message: $initialMessage");

                          try {
                            // ✅ Start a new session (but don't request AI response)
                            final session = await OpenRouterAPI()
                                .startNewConversation(initialMessage);
                            print(
                                "Started new conversation with session: ${session.id}");

                            setState(() {
                              _messages.add({
                                'sender':
                                    'Assistant', // ✅ AI initiates the conversation
                                'content': initialMessage,
                                'role': 'assistant',
                              });
                            });
                          } catch (error) {
                            print("Error starting new conversation: $error");
                          }

                          Navigator.pop(context); // Close the drawer
                        },
                      ),

                      // If no sessions exist, show message
                      if (sessionTitles.isEmpty)
                        ListTile(
                          title: Text(
                            'No Sessions Available',
                            style: TextStyle(
                                fontFamily: 'SFDisplayPro', color: _textColor),
                          ),
                        )
                      else
                        ...sessionTitles.map((title) {
                          return ListTile(
                            title: Text(
                              title, // Display session title
                              style: TextStyle(
                                  fontFamily: 'SFDisplayPro',
                                  color: _textColor),
                            ),
                            onTap: () {
                              _navigateToSession(title); // Navigate using title
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final AnimationController? animationController =
                    message["animationController"] as AnimationController?;

                if (animationController == null) {
                  return ChatBubble(
                    message: message["content"] ?? "",
                    isUser: message["role"] == "user",
                    isLoading: message["isLoading"] ?? false,
                    textColor: _textColor,
                    fontWeight: message["role"] == "user"
                        ? FontWeight.normal
                        : FontWeight.normal,
                  );
                }

                return SlideTransition(
                  position: Tween<Offset>(
                          begin: Offset(
                              message["role"] == "user" ? 0.3 : 0.0, 0.05),
                          end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animationController,
                          curve: Curves.easeOutCubic)),
                  child: FadeTransition(
                    opacity: animationController,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                        CurvedAnimation(
                            parent: animationController,
                            curve: Curves.easeOutCubic),
                      ),
                      child: ChatBubble(
                        message: message["content"] ?? "",
                        isUser: message["role"] == "user",
                        isLoading: message["isLoading"] ?? false,
                        textColor: _textColor,
                        fontWeight: message["role"] == "user"
                            ? FontWeight.normal
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          MessageInput(
            controller: _controller,
            onSendMessage: (message) {
              _sendMessage(message);
              _controller.clear();
            },
            enabled: !_isTyping,
            textColor: _textColor,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Dispose the audio player
    _controller.dispose();
    _scrollController.dispose();
    _listAnimationController.dispose();
    // Dispose all message animation controllers
    for (final message in _messages) {
      message["animationController"]?.dispose();
    }
    super.dispose();
  }
}
