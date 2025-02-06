import 'package:flutter/material.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSendMessage;
  final bool enabled;
  final Color textColor; // Added textColor parameter

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSendMessage,
    this.enabled = true,
    required this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.transparent, // Transparent background for a cleaner look
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                    255, 216, 216, 216), // Light background similar to iMessage
                borderRadius: BorderRadius.circular(30), // Rounded edges
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.1), // Subtle shadow for depth
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3), // Shadow below the input field
                  ),
                ],
              ),
              child: Container(
                width: double
                    .infinity, // This makes the TextField take up the available width
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Colors.black,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: enabled ? onSendMessage : null,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: enabled
                ? () {
                    onSendMessage(controller.text);
                    controller.clear();
                  }
                : null,
            color: textColor, // Apply textColor to the send button icon
            splashColor:
                textColor.withOpacity(0.3), // Apply textColor to splash effect
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(), // No extra padding or constraints
          ),
        ],
      ),
    );
  }
}
