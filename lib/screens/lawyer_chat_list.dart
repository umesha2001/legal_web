import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class LawyerChatList extends StatefulWidget {
  const LawyerChatList({Key? key}) : super(key: key);

  @override
  _LawyerChatListState createState() => _LawyerChatListState();
}

class _LawyerChatListState extends State<LawyerChatList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Color(0xFFD0A554),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A554)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: _auth.currentUser!.uid)
            .snapshots(), // Remove orderBy to avoid index requirement
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading chats: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD0A554)),
            );
          }

          final chatDocs = snapshot.data?.docs ?? [];

          // Sort chats manually by lastMessageTime
          final sortedChats = chatDocs.toList();
          sortedChats.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime); // Descending order
          });

          if (sortedChats.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Messages from clients will appear here',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedChats.length,
            itemBuilder: (context, index) {
              final chatData = sortedChats[index].data() as Map<String, dynamic>;
              return _buildChatTile(chatData, sortedChats[index].id);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chatData, String chatId) {
    final currentUserId = _auth.currentUser!.uid;
    final participants = List<String>.from(chatData['participants'] ?? []);
    final participantNames = Map<String, dynamic>.from(chatData['participantNames'] ?? {});

    // Get the other participant (client)
    final otherParticipantId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    final otherParticipantName = participantNames[otherParticipantId] ?? 'Unknown User';
    final lastMessage = chatData['lastMessage'] ?? '';
    final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
    final unreadCount = (chatData['unreadCount'] as Map<String, dynamic>?)?[currentUserId] ?? 0;

    return Card(
      color: const Color(0xFF3D4559),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFF6C8EBF),
              child: Icon(Icons.person, color: Colors.white, size: 28),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          otherParticipantName,
          style: const TextStyle(
            color: Color(0xFFD0A554),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              lastMessage.isEmpty ? 'No messages yet' : lastMessage,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: lastMessage.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              lastMessageTime != null
                  ? _formatTime(lastMessageTime.toDate())
                  : '',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: unreadCount > 0
            ? const Icon(
          Icons.circle,
          color: Colors.red,
          size: 12,
        )
            : const Icon(
          Icons.chevron_right,
          color: Color(0xFFD0A554),
        ),
        onTap: () {
          // Mark messages as read
          _markMessagesAsRead(chatId);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                lawyerId: otherParticipantId,
                lawyerName: otherParticipantName,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.${_auth.currentUser!.uid}': 0,
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}