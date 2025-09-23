// Create a new file: lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:convert'; // Import for Base64 encoding
import 'package:url_launcher/url_launcher.dart';
import 'package:mime/mime.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String lawyerId;
  final String lawyerName;
  final String? lawyerProfileImage;

  const ChatScreen({
    Key? key,
    required this.lawyerId,
    required this.lawyerName,
    this.lawyerProfileImage,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _chatId;
  bool _isLoading = true;
  bool _isSendingMessage = false;
  bool _isCurrentUserLawyer = false; // Add this state variable

  @override
  void initState() {
    super.initState();
    _initializeChat();
    // Check if the user has agreed to the policy before
    _checkAndShowPrivacyDialog();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      final currentUser = _auth.currentUser!;

      // --- ADD THIS BLOCK TO DETERMINE USER ROLE ---
      final lawyerDocSnapshot = await _firestore.collection('lawyers').doc(currentUser.uid).get();
      if (mounted) {
        setState(() {
          _isCurrentUserLawyer = lawyerDocSnapshot.exists;
        });
      }
      // --- END BLOCK ---
      
      List<String> ids = [currentUser.uid, widget.lawyerId];
      ids.sort();
      _chatId = '${ids[0]}_${ids[1]}';
      
      final chatDoc = await _firestore.collection('chats').doc(_chatId).get();
      
      if (!chatDoc.exists) {
        await _firestore.collection('chats').doc(_chatId).set({
          'participants': [currentUser.uid, widget.lawyerId],
          'participantNames': {
            currentUser.uid: await _getUserName(currentUser.uid),
            widget.lawyerId: widget.lawyerName,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageSender': '',
          'unreadCount': {
            currentUser.uid: 0,
            widget.lawyerId: 0,
          },
        });
      }
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing chat: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) return userDoc.data()?['name'] ?? 'User';
      
      final lawyerDoc = await _firestore.collection('lawyers').doc(userId).get();
      if (lawyerDoc.exists) return lawyerDoc.data()?['name'] ?? 'Lawyer';
      
      return 'Unknown User';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown User';
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSendingMessage) return;

    final message = _messageController.text.trim();

    // --- SENSITIVE INFO CHECK ---
    if (_containsContactInfo(message)) {
      _showContactInfoWarning(message); // Show warning and stop
      return;
    }

    // --- NEW: LINK SHARING CHECK ---
    final linkViolation = _validateLinkSharing(message);
    if (linkViolation != null) {
      _showLinkViolationWarning(linkViolation); // Show new warning and stop
      return;
    }
    // --- END CHECK ---

    _messageController.clear();

    try {
      if (mounted) setState(() => _isSendingMessage = true);
      
      // This part now only runs if the check passes
      await _sendValidatedMessage(message);
      
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  // New method to show the warning dialog
  void _showContactInfoWarning(String originalMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF3D4559),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: const BorderSide(color: Colors.red, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text(
                'Policy Violation Warning',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Sharing personal contact details (phone numbers, emails) is against our policy. Repeated violations may lead to administrative action. Please edit your message.',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Edit Message', style: TextStyle(color: Color(0xFFD0A554))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8)),
              child: const Text('Send Anyway', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.of(context).pop();
                // User acknowledges the warning and proceeds to send
                try {
                  if (mounted) setState(() => _isSendingMessage = true);
                  await _sendValidatedMessage(originalMessage, isFlagged: true);
                } finally {
                  if (mounted) setState(() => _isSendingMessage = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // New method containing the original Firestore logic, now callable from multiple places
  Future<void> _sendValidatedMessage(String message, {bool isFlagged = false}) async {
    final currentUser = _auth.currentUser!;
    
    await _firestore.collection('chats').doc(_chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'senderName': await _getUserName(currentUser.uid),
      'receiverId': widget.lawyerId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
      'isFlagged': isFlagged, // Add a flag for admin review
    });

    await _firestore.collection('chats').doc(_chatId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': currentUser.uid,
      'unreadCount.${widget.lawyerId}': FieldValue.increment(1),
    });

    _scrollToBottom();
  }

  // MODIFIED: This function now uses Base64 encoding to store files in Firestore
  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null && result.files.single.bytes != null) {
      final fileBytes = result.files.single.bytes!;
      final fileName = result.files.single.name;
      
      // Check file size (Firestore limit is 1MB, we'll use 750KB as a safe buffer)
      if (fileBytes.lengthInBytes > 750 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File is too large. Please select a file smaller than 750 KB.')),
          );
        }
        return;
      }

      if (mounted) setState(() => _isSendingMessage = true);

      try {
        // Encode the file bytes to a Base64 string
        final String base64String = base64Encode(fileBytes);

        // Add message to Firestore with the Base64 data
        await _firestore.collection('chats').doc(_chatId).collection('messages').add({
          'senderId': _auth.currentUser!.uid,
          'senderName': await _getUserName(_auth.currentUser!.uid),
          'receiverId': widget.lawyerId,
          'type': 'file',
          'fileName': fileName,
          'fileData': base64String, // Store the encoded string
          'timestamp': FieldValue.serverTimestamp(),
        });

        await _firestore.collection('chats').doc(_chatId).update({
          'lastMessage': '[Attachment] $fileName',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': _auth.currentUser!.uid,
          'unreadCount.${widget.lawyerId}': FieldValue.increment(1),
        });

        _scrollToBottom();
      } catch (e) {
        print('Error sending file: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send file: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSendingMessage = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // New method to check shared preferences and show the dialog if needed
  Future<void> _checkAndShowPrivacyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    // We use a unique key for each user to store their agreement status
    final hasAgreed = prefs.getBool('hasAgreedToChatPolicy_${_auth.currentUser!.uid}') ?? false;

    if (!hasAgreed && mounted) {
      // Show the dialog after the first frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPrivacyPolicyDialog();
      });
    }
  }

  // New method to display the actual alert dialog
  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF3D4559),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: const BorderSide(color: Color(0xFFD0A554), width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.security, color: Color(0xFFD0A554)),
              SizedBox(width: 10),
              Text(
                'Important Notice',
                style: TextStyle(color: Color(0xFFD0A554), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Welcome to LegalWeb\'s secure chat. By continuing, you agree to the following terms:',
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 16),
                _buildPolicyPoint(
                  icon: Icons.lock_outline,
                  text: 'All communications are subject to our Privacy Policy.',
                ),
                const SizedBox(height: 12),
                _buildPolicyPoint(
                  icon: Icons.gavel,
                  text: 'All legal work and discussions must remain within the LegalWeb platform to ensure security and record-keeping.',
                ),
                const SizedBox(height: 12),
                _buildPolicyPoint(
                  icon: Icons.video_call_outlined,
                  text: 'External meetings must be conducted exclusively via Google Meet links shared within this chat.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFD0A554),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'I Understand and Agree',
                style: TextStyle(color: Color(0xFF353E55), fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('hasAgreedToChatPolicy_${_auth.currentUser!.uid}', true);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper widget for styling the points in the dialog
  Widget _buildPolicyPoint({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD0A554), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
      ],
    );
  }

  // New helper function to detect contact information
  bool _containsContactInfo(String message) {
    // RegEx for common phone number formats (international, local, with/without spaces/dashes)
    final phoneRegex = RegExp(
      r'(\+?\d{1,4}?[-.\s]?\(?\d{1,3}?\)?[-.\s]?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{1,9})|(\d{10})'
    );
    
    // RegEx for email addresses
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
    );

    // Check if the message contains a match for either pattern
    return phoneRegex.hasMatch(message) || emailRegex.hasMatch(message);
  }

  // New helper function to validate link sharing based on user role
  String? _validateLinkSharing(String message) {
    final urlRegex = RegExp(
      r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+'
    );
    
    if (!urlRegex.hasMatch(message)) {
      return null; // No links found, no violation.
    }

    // A link was found, now apply rules.
    if (_isCurrentUserLawyer) {
      // Lawyer is sending a link. It MUST be a Google Meet link.
      final googleMeetRegex = RegExp(r'meet\.google\.com\/[a-z]{3}-[a-z]{4}-[a-z]{3}');
      if (!googleMeetRegex.hasMatch(message)) {
        return 'As a lawyer, you may only share valid Google Meet links (e.g., meet.google.com/xxx-xxxx-xxx).';
      }
    } else {
      // A non-lawyer user is sending a link. This is not allowed.
      return 'For security reasons, only lawyers can share links. Please remove the URL from your message.';
    }

    return null; // Google Meet link from a lawyer is valid.
  }

  // New method to show the link violation warning dialog
  void _showLinkViolationWarning(String violationMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF3D4559),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: const BorderSide(color: Colors.orange, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.link_off, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                'Link Policy Violation',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            violationMessage,
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFD0A554),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Edit Message',
                style: TextStyle(color: Color(0xFF353E55), fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF353E55),
        appBar: AppBar(
          title: Text(widget.lawyerName),
          backgroundColor: const Color(0xFF353E55),
          foregroundColor: const Color(0xFFD0A554),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFD0A554)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3D4559),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD0A554)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFD0A554),
              backgroundImage: widget.lawyerProfileImage != null 
                  ? NetworkImage(widget.lawyerProfileImage!)
                  : null,
              child: widget.lawyerProfileImage == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lawyerName,
                    style: const TextStyle(
                      color: Color(0xFFD0A554),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Lawyer',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFFD0A554)),
            onPressed: () {
              // Navigate back to lawyer details
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD0A554)),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                // Auto-scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == _auth.currentUser!.uid;
                    
                    return _buildMessageBubble(messageData, isMe);
                  },
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF3D4559),
              border: Border(
                top: BorderSide(color: Color(0xFFD0A554), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Attachment icon here
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Color(0xFFD0A554)),
                  onPressed: _isSendingMessage ? null : _pickAndSendFile, // MODIFICATION: Disable when sending
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF353E55),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0xFFD0A554), width: 1),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFD0A554),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSendingMessage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF353E55),
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Color(0xFF353E55),
                          ),
                    onPressed: _isSendingMessage ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData, bool isMe) {
    final timestamp = messageData['timestamp'] as Timestamp?;
    final timeString = timestamp != null
        ? _formatTime(timestamp.toDate())
        : 'Sending...';
    
    final messageType = messageData['type'] ?? 'text';

    Widget messageContent;

    if (messageType == 'file') {
      messageContent = InkWell(
        // REPLACE THE ENTIRE onTap FUNCTION WITH THIS:
        onTap: () async {
          try {
            final base64String = messageData['fileData'];
            final fileName = messageData['fileName'];

            if (kIsWeb) {
              // WEB: The canLaunchUrl check is unreliable for data URIs on web.
              // We can directly launch it, and the browser will handle the download.
              final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
              final uri = Uri.parse('data:$mimeType;base64,$base64String');
              
              await launchUrl(uri, mode: LaunchMode.externalApplication);

            } else {
              // MOBILE: Save to a temporary file and use the Share dialog to let the user save it.
              final decodedBytes = base64Decode(base64String);
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/$fileName');
              await tempFile.writeAsBytes(decodedBytes);
              
              // Use the Share dialog, which includes a "Save to device" option
              await Share.shareXFiles(
                [XFile(tempFile.path)],
                subject: 'File from chat: $fileName',
              );
            }
          } catch (e) {
            print('Error sharing/downloading file: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not download or share file.')),
              );
            }
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMe ? const Color(0xFF353E55) : Colors.white,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                messageData['fileName'] ?? 'File',
                style: TextStyle(
                  color: isMe ? const Color(0xFF353E55) : Colors.white,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      // Default to text message
      messageContent = Text(
        messageData['message'] ?? '',
        style: TextStyle(
          color: isMe ? const Color(0xFF353E55) : Colors.white,
          fontSize: 16,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFD0A554),
              backgroundImage: widget.lawyerProfileImage != null 
                  ? NetworkImage(widget.lawyerProfileImage!)
                  : null,
              child: widget.lawyerProfileImage == null
                  ? const Icon(Icons.person, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFD0A554) : const Color(0xFF3D4559),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Use the dynamic messageContent widget here
                  messageContent,
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeString,
                      style: TextStyle(
                        color: isMe 
                            ? const Color(0xFF353E55).withOpacity(0.7)
                            : Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF6C8EBF),
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    if (now.difference(dateTime).inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else {
      final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $amPm';
    }
  }
}