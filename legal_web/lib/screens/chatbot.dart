import 'package:complete/screens/user_home.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIChatBotScreen extends StatefulWidget {
  const AIChatBotScreen({super.key});

  @override
  State<AIChatBotScreen> createState() => _AIChatBotScreenState();
}

class _AIChatBotScreenState extends State<AIChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isInitialized = false;
  String? _initializationError;

  // Legal context and system prompt
  final String _legalSystemPrompt = """
You are an expert Sri Lankan legal assistant named "LegalBot SL". Your primary role is to provide accurate, helpful information about Sri Lankan law while maintaining professional standards and ethical guidelines.

SCOPE & EXPERTISE:
- Sri Lankan Constitution and fundamental rights
- Contract Law (Roman-Dutch principles & local statutes)
- Property Law (Land Registration Ordinance, Partition Law)
- Criminal Law (Penal Code, Criminal Procedure Code)
- Family Law (Marriage Registration Ordinance, Divorce Law)
- Employment Law (Shop & Office Employees Act, labor regulations)
- Commercial Law (Companies Act, intellectual property)
- Civil Procedure Code and court procedures
- Administrative law and public law

RESPONSE GUIDELINES:
1. Always clarify you provide general legal information, NOT legal advice
2. Reference specific Sri Lankan acts, ordinances, and case law when relevant
3. Use simple, accessible language while maintaining legal accuracy
4. Include practical examples from Sri Lankan context
5. Acknowledge limitations and recommend professional consultation for complex matters
6. Never provide advice for illegal activities
7. Stay updated with Sri Lankan legal framework
8. Provide clean, readable responses without excessive formatting symbols

RESPONSE FORMAT:
- Start with a brief, clear answer
- Provide relevant legal framework/acts
- Include practical implications
- End with appropriate disclaimers
- Use simple bullet points (•) for clarity when listing multiple points
- Avoid excessive markdown formatting, asterisks, or symbols
- Keep responses professional and easy to read

Always maintain a professional, helpful tone and emphasize the importance of consulting qualified Sri Lankan lawyers for specific legal matters.
""";

  @override
  void initState() {
    super.initState();
    // Don't call _initializeGemini here to avoid widget lifecycle issues
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to initialize here after widget is fully built
    if (!_isInitialized && _initializationError == null) {
      _initializeGemini();
    }
  }

  Future<void> _initializeGemini() async {
    try {
      // Check if dotenv is loaded
      if (!dotenv.isInitialized) {
        throw Exception('Environment variables not loaded. Please ensure .env file exists and is properly configured.');
      }

      // Get API key from environment
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('GEMINI_API_KEY not found in .env file. Please add your API key to the .env file.');
      }

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.4,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        ],
      );

      _chatSession = _model!.startChat(
        history: [Content.text(_legalSystemPrompt)],
      );
      
      setState(() {
        _isInitialized = true;
        _initializationError = null;
      });
      
      _addWelcomeMessage();
      
      print('✅ Gemini Legal Assistant initialized successfully');
    } catch (e) {
      print('❌ Error initializing Gemini: $e');
      setState(() {
        _isInitialized = false;
        _initializationError = e.toString();
      });
      
      // Add error message instead of showing dialog during initialization
      _addErrorMessage('Failed to initialize Legal Assistant: ${e.toString()}');
    }
  }

  void _addWelcomeMessage() {
    if (!mounted) return;
    
    _messages.add(ChatMessage(
      text: """Welcome to LegalBot SL - Your Sri Lankan Legal Assistant!

I'm here to help you understand Sri Lankan law across various domains:

Civil & Contract Law
• Contract formation & breach
• Tort law & damages
• Property rights & transfers

Criminal Law
• Penal Code provisions
• Criminal procedures
• Rights of accused persons

Family Law
• Marriage & divorce laws
• Child custody & maintenance
• Inheritance & succession

Commercial & Employment Law
• Company law & business regulations
• Employment rights & labor disputes
• Intellectual property protection

Constitutional & Administrative Law
• Fundamental rights
• Public administration
• Judicial review

Important Notice: I provide general legal information based on Sri Lankan law. For specific legal advice, always consult a qualified Sri Lankan attorney.

How to get started: Ask me any question about Sri Lankan law, and I'll provide detailed, accurate information with relevant legal references.

What legal topic would you like to explore today?""",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void _addErrorMessage(String error) {
    if (!mounted) return;
    
    _messages.add(ChatMessage(
      text: """Initialization Error

$error

Possible Solutions:
1. Check .env file - Ensure it exists in your project root
2. Verify API key - Make sure GEMINI_API_KEY is correctly set
3. Restart the app - Try hot restart instead of hot reload
4. Check network - Ensure internet connectivity

To get a Gemini API key:
1. Visit Google AI Studio
2. Sign in with your Google account
3. Create a new API key
4. Add it to your .env file as: GEMINI_API_KEY=your_key_here

For urgent legal matters: Contact a qualified Sri Lankan lawyer directly.

Tap the refresh button to retry initialization.""",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty || !_isInitialized) return;

    final userMessage = text.trim();
    _messageController.clear();

    setState(() {
      _messages.insert(0, ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      // Validate if the question is legal-related
      if (!_isLegalQuestion(userMessage)) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: """Legal Topics Only

I specialize exclusively in Sri Lankan legal matters. Please ask questions about:

• Contract & Property Law - "What makes a contract valid in Sri Lanka?"
• Criminal Law - "What are the penalties for theft under Sri Lankan law?"
• Family Law - "What are the grounds for divorce in Sri Lanka?"
• Employment Law - "What are workers' rights under Sri Lankan labor law?"
• Commercial Law - "How to register a company in Sri Lanka?"
• Constitutional Law - "What are fundamental rights in Sri Lankan constitution?"

Please rephrase your question to focus on Sri Lankan legal matters.""",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        return;
      }

      // Enhance query with legal context
      final enhancedQuery = _enhanceLegalQuery(userMessage);
      
      final response = await _chatSession!.sendMessage(
        Content.text(enhancedQuery),
      );

      final responseText = response.text;
      if (responseText != null && responseText.isNotEmpty) {
        setState(() {
          _messages.insert(0, ChatMessage(
            text: _formatLegalResponse(responseText),
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        throw Exception('Empty response from Legal Assistant');
      }
    } catch (e) {
      print('Error getting AI response: $e');
      setState(() {
        _messages.insert(0, ChatMessage(
          text: """Service Temporarily Unavailable

I'm experiencing technical difficulties. This could be due to:

• API Issues - Gemini service may be temporarily down
• Network Problems - Check your internet connection
• Rate Limiting - Too many requests in a short time
• Invalid API Key - API key may need renewal

Suggested Actions:
• Wait a moment and try again
• Simplify your question
• Check your internet connection
• Contact support if problem persists

For Urgent Legal Matters: Please contact a qualified Sri Lankan lawyer directly.

Emergency Legal Aid: Contact the Legal Aid Commission of Sri Lanka at 011-2323049""",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  bool _isLegalQuestion(String query) {
    final legalKeywords = [
      // General legal terms
      'law', 'legal', 'lawyer', 'attorney', 'court', 'judge', 'justice',
      'act', 'ordinance', 'statute', 'regulation', 'code', 'constitution',
      
      // Contract & Property Law
      'contract', 'agreement', 'property', 'land', 'ownership', 'title',
      'deed', 'mortgage', 'lease', 'rent', 'tenant', 'landlord', 'breach',
      'damages', 'liability', 'tort', 'negligence',
      
      // Criminal Law
      'criminal', 'crime', 'theft', 'assault', 'fraud', 'murder', 'bail',
      'arrest', 'police', 'investigation', 'prosecution', 'defence', 'sentence',
      'prison', 'fine', 'penalty', 'accused', 'defendant', 'victim',
      
      // Family Law
      'marriage', 'divorce', 'custody', 'maintenance', 'alimony', 'inheritance',
      'will', 'testament', 'succession', 'adoption', 'guardian', 'minor',
      'spouse', 'child', 'family',
      
      // Employment Law
      'employment', 'worker', 'employee', 'employer', 'salary', 'wages',
      'termination', 'dismissal', 'resignation', 'labor', 'trade union',
      'gratuity', 'provident fund', 'leave', 'overtime',
      
      // Commercial Law
      'company', 'business', 'corporation', 'partnership', 'shareholder',
      'director', 'registration', 'license', 'permit', 'tax', 'vat',
      'intellectual property', 'copyright', 'patent', 'trademark',
      
      // Court procedures
      'case', 'lawsuit', 'litigation', 'appeal', 'supreme court', 'high court',
      'magistrate', 'district court', 'commercial high court', 'tribunal',
      'mediation', 'arbitration', 'settlement',
      
      // Sri Lankan specific
      'sri lanka', 'sri lankan', 'colombo', 'penal code', 'civil procedure',
      'roman dutch', 'customary law', 'muslim law', 'kandyan law',
      'fundamental rights', 'legal aid commission'
    ];

    final lowerQuery = query.toLowerCase();
    return legalKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  String _enhanceLegalQuery(String query) {
    return """Legal Query about Sri Lankan Law: "$query"

Please provide a comprehensive response that includes:
1. Direct answer to the question
2. Relevant Sri Lankan legal acts, ordinances, or case law
3. Practical implications and procedures
4. Any important exceptions or special circumstances
5. Clear disclaimer about seeking professional legal advice

Focus specifically on Sri Lankan legal framework and cite relevant legal provisions where applicable.

Important: Provide clean, readable responses without excessive formatting symbols, asterisks, or markdown. Use simple bullet points (•) when needed and keep the text professional and easy to read.""";
  }

  String _formatLegalResponse(String response) {
    // Clean up the response text by removing excessive formatting
    String cleanedResponse = response
        // Remove excessive asterisks
        .replaceAll(RegExp(r'\*{2,}'), '')
        // Remove markdown headers that are excessive
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        // Clean up bullet points - standardize to simple bullet
        .replaceAll(RegExp(r'[*-]\s*'), '• ')
        // Remove excessive line breaks
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        // Remove excessive spaces
        .replaceAll(RegExp(r' {2,}'), ' ')
        // Clean up any remaining markdown formatting
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'\1')
        // Remove any remaining markdown links format
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1')
        // Clean up any HTML tags if present
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();

    // Ensure proper disclaimer is included
    if (!cleanedResponse.toLowerCase().contains('disclaimer') && 
        !cleanedResponse.toLowerCase().contains('legal advice') &&
        !cleanedResponse.toLowerCase().contains('consult')) {
      cleanedResponse += """

Disclaimer: This information is for general educational purposes only and does not constitute legal advice. Sri Lankan law can be complex and fact-specific. For personalized legal guidance regarding your specific situation, please consult with a qualified Sri Lankan attorney or the Legal Aid Commission.""";
    }
    
    return cleanedResponse;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorDialog(String message) {
    // Only show dialog if widget is mounted and context is available
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D4559),
        title: const Text(
          'Legal Assistant Error',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFFD0A554)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeGemini();
            },
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFFD0A554)),
            ),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D4559),
        title: const Text(
          'Clear Chat History',
          style: TextStyle(color: Color(0xFFD0A554)),
        ),
        content: const Text(
          'Are you sure you want to clear all chat messages? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.clear();
                if (_isInitialized) {
                  _chatSession = _model!.startChat();
                  _addWelcomeMessage();
                } else if (_initializationError != null) {
                  _addErrorMessage(_initializationError!);
                }
              });
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Color(0xFFD0A554)),
            const SizedBox(width: 8),
            const Text(
              'LegalBot SL',
              style: TextStyle(
                color: Color(0xFFD0A554),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _isInitialized ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isInitialized ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD0A554)),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const UserHome()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFD0A554)),
            onPressed: () {
              setState(() {
                _isInitialized = false;
                _initializationError = null;
                _messages.clear();
              });
              _initializeGemini();
            },
            tooltip: 'Reconnect',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Color(0xFFD0A554)),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Legal Topics Quick Access
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildQuickTopicChip('Contract Law', '📝', 'What are the essential elements of a valid contract in Sri Lanka?'),
                _buildQuickTopicChip('Property Law', '🏠', 'How do I transfer property ownership in Sri Lanka?'),
                _buildQuickTopicChip('Criminal Law', '⚖️', 'What are the procedures for criminal cases in Sri Lanka?'),
                _buildQuickTopicChip('Family Law', '💍', 'What are the grounds for divorce under Sri Lankan law?'),
                _buildQuickTopicChip('Employment Law', '💼', 'What are employee rights under Sri Lankan labor law?'),
                _buildQuickTopicChip('Commercial Law', '🏢', 'How do I register a company in Sri Lanka?'),
              ],
            ),
          ),
          const Divider(color: Color(0xFF3D4559), height: 1),
          
          // Chat Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD0A554),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _messages[index],
                  ),
          ),
          
          // Loading Indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFFD0A554),
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Analyzing legal query...',
                    style: TextStyle(
                      color: Color(0xFFD0A554),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          
          // Input Field
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF3D4559),
              border: Border(
                top: BorderSide(color: Color(0xFF2A3447), width: 1),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: null,
                    enabled: _isInitialized && !_isLoading,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _isInitialized 
                          ? 'Ask about Sri Lankan law...' 
                          : 'Initializing Legal Assistant...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Color(0xFFD0A554)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Color(0xFFD0A554)),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: _isInitialized 
                          ? const Color(0xFF2A3447) 
                          : const Color(0xFF1A1F2E),
                    ),
                    onSubmitted: (_isLoading || !_isInitialized) ? null : _handleSubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: (_isInitialized && !_isLoading) 
                        ? const Color(0xFFD0A554) 
                        : Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isLoading 
                          ? Icons.hourglass_empty 
                          : !_isInitialized 
                              ? Icons.cloud_off 
                              : Icons.send,
                      color: const Color(0xFF353E55),
                    ),
                    onPressed: (_isLoading || !_isInitialized) 
                        ? null 
                        : () => _handleSubmitted(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTopicChip(String label, String emoji, String query) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3D4559),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD0A554), width: 1),
        ),
        onPressed: _isInitialized && !_isLoading ? () {
          _messageController.text = query;
          _handleSubmitted(query);
        } : null,
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

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFFD0A554) : const Color(0xFF3D4559),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD0A554),
                width: 2,
              ),
            ),
            child: Icon(
              isUser ? Icons.person : Icons.psychology,
              size: 22,
              color: isUser ? const Color(0xFF353E55) : const Color(0xFFD0A554),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isUser ? 'You' : 'LegalBot SL',
                      style: const TextStyle(
                        color: Color(0xFFD0A554),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(timestamp),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2A3447) : const Color(0xFF3D4559),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isUser ? const Color(0xFFD0A554) : const Color(0xFF4A5568),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}