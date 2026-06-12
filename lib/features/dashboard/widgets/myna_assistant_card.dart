import 'package:flutter/material.dart';

class MynaAssistantCard extends StatelessWidget {
  final String message;

  const MynaAssistantCard({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Bot Avatar
          TweenAnimationBuilder(
            tween: Tween(begin: 0.95, end: 1.05),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: Image.asset(
                  "assets/images/myna_bot.png",
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      "MYNA Assistant",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.green,
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
