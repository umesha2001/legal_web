import 'package:complete/screens/lawyer_details.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'chat_screen.dart';
import 'user_chat_list.dart'; // We'll create this

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  _UserHomeState createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> _lawyers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();
  String _selectedPracticeCourt = '';
  List<String> _practiceCourts = [
    'All Courts',
    'Property Law',
    'Marriage Law',
    'Employment Law'
  ];
  
  bool _isFilterVisible = false;
  Timer? _debounceTimer;

  // Chat-related variables
  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoadingChats = false;
  int _totalUnreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _loadLawyers();
    _fetchRecentChats(); // Add chat loading
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Add chat fetching functionality
  Future<void> _fetchRecentChats() async {
    try {
      setState(() => _isLoadingChats = true);
      
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Loading chats for user: ${currentUser.uid}');
        
        final chatsSnapshot = await _firestore
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .get(); // Remove orderBy to avoid index issues

        print('Found ${chatsSnapshot.docs.length} chats');

        List<Map<String, dynamic>> chats = [];
        int totalUnread = 0;
        
        for (var doc in chatsSnapshot.docs) {
          Map<String, dynamic> chat = doc.data();
          chat['id'] = doc.id;
          
          // Get the other participant (lawyer) info
          final participants = List<String>.from(chat['participants'] ?? []);
          final otherParticipantId = participants.firstWhere(
            (id) => id != currentUser.uid,
            orElse: () => '',
          );
          
          if (otherParticipantId.isNotEmpty) {
            // Get lawyer name from lawyers collection
            try {
              final lawyerDoc = await _firestore.collection('lawyers').doc(otherParticipantId).get();
              if (lawyerDoc.exists) {
                final lawyerData = lawyerDoc.data() as Map<String, dynamic>;
                chat['lawyerName'] = lawyerData['name'] ?? 'Unknown Lawyer';
                chat['lawyerEmail'] = lawyerData['email'] ?? '';
                chat['lawyerProfileImage'] = lawyerData['profileImage'];
                chat['lawyerSpecialization'] = lawyerData['specialization'] ?? '';
              } else {
                chat['lawyerName'] = 'Unknown Lawyer';
              }
            } catch (e) {
              chat['lawyerName'] = 'Unknown Lawyer';
            }
            
            chat['lawyerId'] = otherParticipantId;
            
            // Count unread messages for this user
            final unreadCount = (chat['unreadCount'] as Map<String, dynamic>?)?[currentUser.uid] ?? 0;
            totalUnread += unreadCount as int;
            
            chats.add(chat);
          }
        }

        // Sort chats by lastMessageTime locally
        chats.sort((a, b) {
          final aTime = a['lastMessageTime'] as Timestamp?;
          final bTime = b['lastMessageTime'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime); // Descending order
        });

        // Take only the latest 2 chats for home screen
        if (chats.length > 2) {
          chats = chats.take(2).toList();
        }

        setState(() {
          _recentChats = chats;
          _totalUnreadMessages = totalUnread;
          _isLoadingChats = false;
        });
        
        print('Loaded ${chats.length} chats with $totalUnread total unread messages');
      }
    } catch (e) {
      print('Error fetching chats: $e');
      setState(() => _isLoadingChats = false);
    }
  }

  // Mark messages as read
  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.${_auth.currentUser!.uid}': 0,
      });
      
      // Refresh chat data
      _fetchRecentChats();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Format chat time helper
  String _formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _loadLawyers() async {
    try {
      setState(() => _isLoading = true);

      // Try the optimized query first - get all lawyers, prioritize completed profiles
      try {
        final QuerySnapshot snapshot = await _firestore
            .collection('lawyers')
            .orderBy('rating', descending: true)
            .limit(20)
            .get();

        setState(() {
          _lawyers = snapshot.docs;
          _isLoading = false;
        });
        return;
      } catch (indexError) {
        print('Index not ready, using fallback query: $indexError');
        
        // Show user that we're using fallback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading lawyers... (using fallback method)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Fallback: Get all lawyers, then sort locally
        final QuerySnapshot snapshot = await _firestore
            .collection('lawyers')
            .get();

        print('Fallback query found ${snapshot.docs.length} total lawyers');
        
        // Debug: Print first few lawyers
        for (int i = 0; i < snapshot.docs.length && i < 3; i++) {
          final data = snapshot.docs[i].data() as Map<String, dynamic>;
          print('Lawyer $i: name=${data['name']}, email=${data['email']}, profileComplete=${data['profileComplete']}');
        }

        // Sort by profile completion status first, then by rating
        List<DocumentSnapshot> sortedLawyers = snapshot.docs.toList();
        sortedLawyers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          
          // Helper function to safely convert to boolean
          bool _toBool(dynamic value) {
            if (value is bool) return value;
            if (value is String) {
              return value.toLowerCase() == 'true';
            }
            return false;
          }
          
          // First priority: completed profiles
          final aComplete = _toBool(aData['profileComplete']);
          final bComplete = _toBool(bData['profileComplete']);
          
          if (aComplete && !bComplete) return -1;
          if (!aComplete && bComplete) return 1;
          
          // Second priority: rating
          final aRating = (aData['rating'] ?? 0.0) as double;
          final bRating = (bData['rating'] ?? 0.0) as double;
          return bRating.compareTo(aRating); // Descending order
        });

        // Take only the first 10
        if (sortedLawyers.length > 10) {
          sortedLawyers = sortedLawyers.take(10).toList();
        }

        setState(() {
          _lawyers = sortedLawyers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading lawyers: $e');
      setState(() => _isLoading = false);
    }  }

  void _searchLawyers(String query, {String? practiceCourt}) async {
    try {
      setState(() => _isLoading = true);

      // If both query and practice court are empty, load all lawyers
      if (query.isEmpty && (practiceCourt == null || practiceCourt.isEmpty || practiceCourt == 'All Courts')) {
        await _loadLawyers();
        return;
      }

      // Get all lawyers first (no complex queries to avoid index issues)
      final QuerySnapshot snapshot = await _firestore
          .collection('lawyers')
          .get();

      print('Total lawyers in database: ${snapshot.docs.length}');

      List<DocumentSnapshot> filteredLawyers = snapshot.docs.toList();

      // Filter by practice court/specialization if selected
      if (practiceCourt != null && practiceCourt.isNotEmpty && practiceCourt != 'All Courts') {
        filteredLawyers = filteredLawyers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final specialization = (data['specialization'] ?? '').toString().toLowerCase();
          return specialization.contains(practiceCourt.toLowerCase());
        }).toList();
        print('After practice court filter: ${filteredLawyers.length} lawyers');
      }

      // Filter by search query if provided
      if (query.isNotEmpty) {
        String searchQuery = query.toLowerCase().trim();
        print('Searching for: "$searchQuery"');
        
        filteredLawyers = filteredLawyers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Check all possible fields for search
          final searchableFields = [
            data['name'] ?? '',
            data['firstName'] ?? '',
            data['lastName'] ?? '',
            data['email'] ?? '',
            data['specialization'] ?? '',
            data['education'] ?? '',
            data['experience']?.toString() ?? '',
            data['city'] ?? '',
            data['address'] ?? '',
          ];

          // Check if any field contains the search query
          bool fieldMatch = searchableFields.any((field) => 
            field.toString().toLowerCase().contains(searchQuery)
          );
          
          // Also check searchKeywords array if it exists
          bool keywordMatch = false;
          final keywords = data['searchKeywords'];
          if (keywords is List) {
            keywordMatch = keywords.any((keyword) => 
              keyword.toString().toLowerCase().contains(searchQuery)
            );
          }
          
          bool matches = fieldMatch || keywordMatch;
          if (matches) {
            print('Match found: ${data['name']} - ${data['email']}');
          }
          
          return matches;
        }).toList();
        
        print('After search filter: ${filteredLawyers.length} lawyers found');
      }

      // Helper function to safely convert to boolean
      bool _toBool(dynamic value) {
        if (value is bool) return value;
        if (value is String) {
          return value.toLowerCase() == 'true';
        }
        return false;
      }

      // Sort by profile completion first, then by rating
      filteredLawyers.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        
        // First priority: completed profiles
        final aComplete = _toBool(aData['profileComplete']);
        final bComplete = _toBool(bData['profileComplete']);
        
        if (aComplete && !bComplete) return -1;
        if (!aComplete && bComplete) return 1;
        
        // Second priority: rating
        final aRating = (aData['rating'] ?? 0.0).toDouble();
        final bRating = (bData['rating'] ?? 0.0).toDouble();
        return bRating.compareTo(aRating); // Descending order
      });

      // Limit results to 20
      if (filteredLawyers.length > 20) {
        filteredLawyers = filteredLawyers.take(20).toList();
      }

      print('Final results: ${filteredLawyers.length} lawyers');

      if (mounted) {
        setState(() {
          _lawyers = filteredLawyers;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error searching lawyers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: Text(
          'Find Lawyer',
          style: TextStyle(
            color: const Color(0xFFD0A554),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        actions: [
          // Add messages icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFD0A554)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserChatList()),
                  ).then((_) {
                    // Refresh chats when returning from chat list
                    _fetchRecentChats();
                  });
                },
              ),
              if (_totalUnreadMessages > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _totalUnreadMessages > 99 ? '99+' : _totalUnreadMessages.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isFilterVisible ? 120 : 60),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                            
                            // Cancel previous timer
                            _debounceTimer?.cancel();
                            
                            // Create new timer with 500ms delay
                            _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                              _searchLawyers(value, practiceCourt: _selectedPracticeCourt);
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search for lawyers...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search, color: const Color(0xFF353E55)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          style: TextStyle(color: const Color(0xFF353E55)),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFilterVisible ? Icons.tune_outlined : Icons.tune,
                          color: const Color(0xFF353E55),
                        ),
                        onPressed: () {
                          setState(() => _isFilterVisible = !_isFilterVisible);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_isFilterVisible)
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _practiceCourts.length,
                    itemBuilder: (context, index) {
                      final court = _practiceCourts[index];
                      final isSelected = court == _selectedPracticeCourt;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(court),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPracticeCourt = selected ? court : '';
                            });
                            _searchLawyers(_searchQuery, practiceCourt: _selectedPracticeCourt);
                          },
                          backgroundColor: const Color(0xFFD9D9D9),
                          selectedColor: const Color(0xFFD0A554),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF353E55),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView( // Wrap in SingleChildScrollView to fix overflow
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1st: AI Legal ChatBot Card
            _buildFeatureCard(
              icon: Icons.chat_bubble_outline,
              title: 'AI Legal ChatBot',
              subtitle: 'Get instant legal answers',
              color: const Color(0xFFD0A554),
              onTap: () {
                Navigator.pushNamed(context, '/ai-chatbot');
              },
            ),
            const SizedBox(height: 16),
            
            // 2nd: My Bookings Card
            _buildFeatureCard(
              icon: Icons.calendar_today,
              title: 'My Bookings',
              subtitle: 'View and manage appointments',
              color: const Color(0xFF6C8EBF),
              onTap: () {
                Navigator.pushNamed(context, '/user-bookings');
              },
            ),
            const SizedBox(height: 16),
            
            // 3rd: Scam Detection Card
            _buildFeatureCard(
              icon: Icons.security,
              title: 'Scam Detection',
              subtitle: 'Verify legal documents',
              color: const Color(0xFFD9D9D9),
              onTap: () {
                _showComingSoonDialog();
              },
            ),
            const SizedBox(height: 16),
            
            // 4th: Recent Messages Section (only if user has chats)
            if (_recentChats.isNotEmpty) ...[
              _buildRecentMessagesSection(),
              const SizedBox(height: 16),
            ],
            
            // Lawyers List Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recommended Lawyers',
                    style: TextStyle(
                      color: const Color(0xFFD0A554),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/all-lawyers');
                    },
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: const Color(0xFFD9D9D9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Lawyer Cards - Use Container with fixed height to prevent overflow
            Container(
              height: 300, // Fixed height to prevent bottom overflow
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFD0A554)))
                  : _lawyers.isEmpty
                      ? const Center(
                          child: Text(
                            'No lawyers found',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _lawyers.length,
                          itemBuilder: (context, index) {
                            try {
                              final lawyer = _lawyers[index].data() as Map<String, dynamic>;
                              
                              // Helper function to safely convert to boolean
                              bool _toBool(dynamic value) {
                                if (value is bool) return value;
                                if (value is String) {
                                  return value.toLowerCase() == 'true';
                                }
                                return false;
                              }
                              
                              return _buildLawyerCard(
                                name: lawyer['name'] ?? 'Unknown',
                                specialization: lawyer['specialization'] ?? 'Not specified',
                                rating: (lawyer['rating'] ?? 0.0).toDouble(),
                                experience: '${lawyer['experience'] ?? 0} years',
                                profileComplete: _toBool(lawyer['profileComplete']),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LawyerDetailsScreen(
                                        lawyerId: _lawyers[index].id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            } catch (e) {
                              print('Error building lawyer card: $e');
                              return const SizedBox.shrink();
                            }
                          },
                        ),
            ),
            const SizedBox(height: 20), // Add bottom padding
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF353E55),
        selectedItemColor: const Color(0xFFD0A554),
        unselectedItemColor: const Color(0xFFD9D9D9),
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/user-home');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/client/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Recent Messages Section
  Widget _buildRecentMessagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Recent Messages',
                  style: TextStyle(
                    color: const Color(0xFFD0A554),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_totalUnreadMessages > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _totalUnreadMessages.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserChatList()),
                ).then((_) {
                  // Refresh chats when returning from chat list
                  _fetchRecentChats();
                });
              },
              child: Text(
                'View All',
                style: TextStyle(color: const Color(0xFFD0A554)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_isLoadingChats)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFFD0A554)),
          )
        else
          Column(
            children: _recentChats.map((chat) => _buildChatPreviewCard(chat)).toList(),
          ),
      ],
    );
  }

  // Chat Preview Card
  Widget _buildChatPreviewCard(Map<String, dynamic> chat) {
    final lawyerName = chat['lawyerName'] ?? 'Unknown Lawyer';
    final lawyerSpecialization = chat['lawyerSpecialization'] ?? '';
    final lastMessage = chat['lastMessage'] ?? '';
    final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
    final unreadCount = (chat['unreadCount'] as Map<String, dynamic>?)?[_auth.currentUser!.uid] ?? 0;
    final lawyerProfileImage = chat['lawyerProfileImage'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF3D4559),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Mark messages as read when opening chat
          _markMessagesAsRead(chat['id']);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                lawyerId: chat['lawyerId'],
                lawyerName: lawyerName,
                lawyerProfileImage: lawyerProfileImage,
              ),
            ),
          ).then((_) {
            // Refresh chats when returning from chat screen
            _fetchRecentChats();
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Lawyer Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFD0A554),
                    backgroundImage: lawyerProfileImage != null 
                        ? NetworkImage(lawyerProfileImage)
                        : null,
                    child: lawyerProfileImage == null
                        ? const Icon(
                            Icons.person,
                            color: Color(0xFF353E55),
                            size: 24,
                          )
                        : null,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              
              // Message Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            lawyerName,
                            style: TextStyle(
                              color: const Color(0xFFD0A554),
                              fontSize: 14,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime != null)
                          Text(
                            _formatChatTime(lastMessageTime.toDate()),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    if (lawyerSpecialization.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        lawyerSpecialization,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                      style: TextStyle(
                        color: lastMessage.isEmpty ? Colors.white54 : Colors.white70,
                        fontSize: 12,
                        fontStyle: lastMessage.isEmpty ? FontStyle.italic : FontStyle.normal,
                        fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: unreadCount > 0 ? const Color(0xFFD0A554) : Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 40,
              color: const Color(0xFF353E55),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF353E55),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF353E55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLawyerCard({
    required String name,
    required String specialization,
    required double rating,
    required String experience,
    required bool profileComplete,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF3D4559),
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFD0A554),
                child: Icon(Icons.person, color: Color(0xFF353E55)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      specialization,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$experience experience',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFD0A554), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        rating.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View Profile',
                    style: TextStyle(
                      color: const Color(0xFFD0A554),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF3D4559),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.construction,
                color: Color(0xFFD0A554),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Coming Soon',
                style: TextStyle(
                  color: Color(0xFFD0A554),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.security,
                size: 64,
                color: Color(0xFFD0A554),
              ),
              const SizedBox(height: 16),
              const Text(
                'Scam Detection Feature',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We are working hard to bring you an advanced document verification system to help protect you from legal scams.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF353E55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD0A554),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: Color(0xFFD0A554),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expected Release: Around 2026',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay tuned for updates!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFD0A554),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Got it!',
                style: TextStyle(
                  color: Color(0xFF353E55),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        );
      },
    );
  }
}