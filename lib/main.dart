import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(ChatApp());
}

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Athena',
      theme: ThemeData.light(),
      home: ChatScreen(),
    );
  }
}
