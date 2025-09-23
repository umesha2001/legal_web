import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:firebase_auth/firebase_auth.dart'; // Add this import

class PaymentGatewayScreen extends StatefulWidget {
  final Map<String, dynamic> bookingDetails;

  // Make bookingDetails nullable with a default empty map
  const PaymentGatewayScreen({Key? key, this.bookingDetails = const {}}) : super(key: key);

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  bool _isProcessing = false;
  bool _showCardForm = true;
  CardType _cardType = CardType.other;
  
  // Add these variables
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? _lawyerData;
  Map<String, dynamic>? _userData;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    print('BookingDetails in constructor: ${widget.bookingDetails}');
    _fetchAdditionalData();
  }

  // Add this method to fetch additional data
  Future<void> _fetchAdditionalData() async {
    setState(() => _isLoadingData = true);
    
    try {
      // Get current user data
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Fetching user data for ID: ${currentUser.uid}');
        
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          print('User data retrieved: $userData');
          
          // Check for phone number with correct field name
          final phone = userData?['contact'] ?? userData?['phone'] ?? userData?['phoneNumber'] ?? userData?['mobile'];
          print('Phone number found: $phone');
          
          // Check for name with correct field name
          final name = userData?['firstName'] ?? userData?['name'] ?? userData?['fullName'] ?? userData?['displayName'];
          print('Name found: $name');
          
          setState(() {
            _userData = userData;
          });
        } else {
          print('User document does not exist for ID: ${currentUser.uid}');
          print('Checking if user collection exists...');
          
          // Try different collection names if 'users' doesn't exist
          final clientDoc = await _firestore.collection('clients').doc(currentUser.uid).get();
          if (clientDoc.exists) {
            print('Found user data in clients collection');
            setState(() {
              _userData = clientDoc.data();
            });
          }
        }
      }
      
      // Get lawyer data - use a more reliable method to get the lawyer ID
      // First, try from the bookingDetails directly
      String? lawyerId = widget.bookingDetails['lawyerId'];
      
      // If that doesn't exist, try to get it from the lawyer name
      if (lawyerId == null || lawyerId.isEmpty) {
        final String? lawyerName = widget.bookingDetails['lawyer'] as String?;
        if (lawyerName != null && lawyerName.isNotEmpty) {
          print('Searching for lawyer by name: $lawyerName');
          // Query the lawyers collection to find the lawyer by name
          final querySnapshot = await _firestore
              .collection('lawyers')
              .where('name', isEqualTo: lawyerName)
              .limit(1)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            lawyerId = querySnapshot.docs.first.id;
            print('Found lawyer ID: $lawyerId');
          }
        }
      }
      
      if (lawyerId != null && lawyerId.isNotEmpty) {
        print('Fetching lawyer data for ID: $lawyerId');
        final lawyerDoc = await _firestore.collection('lawyers').doc(lawyerId).get();
        if (lawyerDoc.exists) {
          setState(() {
            _lawyerData = lawyerDoc.data();
            print('Lawyer data retrieved: $_lawyerData');
          });
        } else {
          print('Lawyer document does not exist for ID: $lawyerId');
        }
      } else {
        print('No lawyer ID available to fetch data');
      }
      
    } catch (e) {
      print('Error fetching additional data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Safe access to userData and currentUser with null checks
    final userData = _userData;
    final currentUser = _auth.currentUser;
    
    // Ensure widget.bookingDetails is safely accessed
    final amount = widget.bookingDetails['amount']?.toString() ?? '0.00';
    
    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: const Color(0xFF353E55),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD0A554)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to the booking page
            Navigator.pushReplacementNamed(context, '/user-bookings');
            // Or if you prefer to just go back to the previous screen:
            // Navigator.of(context).pop();
          },
        ),
      ),
      body: _isLoadingData 
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFD0A554)),
          ) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Booking Summary with additional data
                Card(
                  color: const Color(0xFF3D4559),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Booking Summary',
                          style: TextStyle(
                            color: Color(0xFFD0A554),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Client information section
                        const Text(
                          'Client Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _buildDetailRow(
                          Icons.person, 
                          'Name:', 
                          () {
                            if (_userData != null) {
                              final name = _userData!['firstName'] ?? 
                                           _userData!['name'] ?? 
                                           _userData!['fullName'] ?? 
                                           _userData!['displayName'];
                              if (name != null && name.toString().isNotEmpty) {
                                return name.toString();
                              }
                            }
                            
                            // Fallback to booking details
                            final fallbackName = widget.bookingDetails['clientName'] ?? 'N/A';
                            return fallbackName;
                          }()
                        ),
                        _buildDetailRow(
                          Icons.email, 
                          'Email:', 
                          _userData != null 
                            ? (_userData!['email'] ?? currentUser?.email ?? 'N/A')
                            : widget.bookingDetails['clientEmail'] ?? 'N/A'
                        ),
                        _buildDetailRow(
                          Icons.phone, 
                          'Phone:', 
                          () {
                            if (_userData != null) {
                              final phone = _userData!['contact'] ?? 
                                           _userData!['phone'] ?? 
                                           _userData!['phoneNumber'] ?? 
                                           _userData!['mobile'];
                              if (phone != null && phone.toString().isNotEmpty) {
                                return phone.toString();
                              }
                            }
                            
                            // Fallback to booking details
                            final fallbackPhone = widget.bookingDetails['clientPhone'] ?? 'N/A';
                            return fallbackPhone;
                          }()
                        ),
                        const SizedBox(height: 15),
                        
                        // Lawyer information section
                        const Text(
                          'Lawyer Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _buildDetailRow(
                          Icons.person, 
                          'Lawyer:', 
                          _lawyerData != null && _lawyerData!['name'] != null 
                            ? _lawyerData!['name'] 
                            : widget.bookingDetails['lawyer'] ?? 'N/A'
                        ),
                        _buildDetailRow(
                          Icons.work, 
                          'Specialization:', 
                          _lawyerData?['specialization'] ?? 'N/A'
                        ),
                        _buildDetailRow(
                          Icons.star, 
                          'Rating:', 
                          _lawyerData?['rating']?.toString() ?? 'N/A'
                        ),
                        const SizedBox(height: 15),
                        
                        // Appointment details section
                        const Text(
                          'Appointment Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _buildDetailRow(
                          Icons.calendar_today, 
                          'Date:', 
                          widget.bookingDetails['date'] ?? 'N/A'
                        ),
                        _buildDetailRow(
                          Icons.access_time, 
                          'Time:', 
                          widget.bookingDetails['time'] ?? 'N/A'
                        ),
                        _buildDetailRow(
                          Icons.phone, 
                          'Type:', 
                          widget.bookingDetails['type'] ?? 'N/A'
                        ),
                        _buildDetailRow(
                          Icons.note, 
                          'Reason:', 
                          widget.bookingDetails['reason'] ?? 'N/A'
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFFD0A554)),
                        const SizedBox(height: 10),
                        _buildDetailRow(
                          Icons.money, 
                          'Consultation Fee:', 
                          'LKR ${_lawyerData?['consultationFee']?.toString() ?? amount}'
                        ),
                        _buildDetailRow(
                          Icons.attach_money, 
                          'Total Amount:', 
                          'LKR $amount'
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Card Payment Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Card Details',
                        style: TextStyle(
                          color: Color(0xFFD0A554),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      
                      _buildCardInput(
                        controller: _cardNumberController,
                        label: 'Card Number',
                        hint: '4242 4242 4242 4242',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter card number';
                          }
                          final cleaned = value.replaceAll(RegExp(r'\s+\b|\b\s'), '');
                          if (!RegExp(r'^[0-9]{13,19}$').hasMatch(cleaned)) {
                            return 'Enter valid card number';
                          }
                          return null;
                        },
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(19),
                          CardNumberFormatter(),
                        ],
                        prefixIcon: _buildCardTypeIcon(),
                      ),
                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCardInput(
                              controller: _expiryController,
                              label: 'Expiry Date',
                              hint: 'MM/YY',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter expiry date';
                                }
                                if (!RegExp(r'^(0[1-9]|1[0-2])\/?([0-9]{2})$').hasMatch(value)) {
                                  return 'MM/YY format';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                                CardExpiryFormatter(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 15),
                          
                          Expanded(
                            child: _buildCardInput(
                              controller: _cvvController,
                              label: 'CVV',
                              hint: _cardType == CardType.amex ? '4 digits' : '3 digits',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter CVV';
                                }
                                if (_cardType == CardType.amex && value.length != 4) {
                                  return '4 digit code';
                                }
                                if (_cardType != CardType.amex && value.length != 3) {
                                  return '3 digit code';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                  _cardType == CardType.amex ? 4 : 3),
                              ],
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      
                      _buildCardInput(
                        controller: _cardHolderController,
                        label: 'Card Holder Name',
                        hint: 'John Doe',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter card holder name';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD0A554),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isProcessing ? null : _processPayment,
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Color(0xFF353E55))
                        : const Text(
                            'PAY NOW',
                            style: TextStyle(
                              color: Color(0xFF353E55),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD0A554), size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD0A554),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    Widget? prefixIcon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0A554),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFF3D4559),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: prefixIcon,
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          validator: validator,
          onChanged: (value) {
            if (controller == _cardNumberController) {
              _detectCardType(value.replaceAll(' ', ''));
            }
          },
          textCapitalization: textCapitalization,
        ),
      ],
    );
  }

  Widget _buildCardTypeIcon() {
    // For actual implementation, you would use actual card icons
    // This is a simplified version using Icons
    switch (_cardType) {
      case CardType.visa:
        return const Icon(Icons.credit_card, color: Colors.blue);
      case CardType.mastercard:
        return const Icon(Icons.credit_card, color: Colors.red);
      case CardType.amex:
        return const Icon(Icons.credit_card, color: Colors.green);
      case CardType.discover:
        return const Icon(Icons.credit_card, color: Colors.orange);
      default:
        return const Icon(Icons.credit_card, color: Color(0xFFD0A554));
    }
  }

  void _detectCardType(String cardNumber) {
    if (cardNumber.isEmpty) {
      setState(() => _cardType = CardType.other);
      return;
    }

    if (cardNumber.startsWith('4')) {
      setState(() => _cardType = CardType.visa);
    } else if (cardNumber.startsWith(RegExp(r'5[1-5]'))) {
      setState(() => _cardType = CardType.mastercard);
    } else if (cardNumber.startsWith(RegExp(r'3[47]'))) {
      setState(() => _cardType = CardType.amex);
    } else if (cardNumber.startsWith('6')) {
      setState(() => _cardType = CardType.discover);
    } else {
      setState(() => _cardType = CardType.other);
    }
  }

  // Update the _processPayment method
  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final amount = widget.bookingDetails['amount']?.toString() ?? '0.00';
      final transactionId = _generateTransactionId();
      final currentUser = _auth.currentUser;
      
      // Prepare booking data
      final bookingData = {
        'clientId': currentUser?.uid,
        'clientName': _userData?['firstName'] ?? widget.bookingDetails['clientName'] ?? 'Unknown Client',
        'clientEmail': _userData?['email'] ?? currentUser?.email ?? widget.bookingDetails['clientEmail'] ?? '',
        'clientPhone': _userData?['contact'] ?? widget.bookingDetails['clientPhone'] ?? '',
        'lawyerId': widget.bookingDetails['lawyerId'] ?? '',
        'lawyerName': _lawyerData?['name'] ?? widget.bookingDetails['lawyer'] ?? 'Unknown Lawyer',
        'date': widget.bookingDetails['date'] ?? '',
        'time': widget.bookingDetails['time'] ?? '',
        'type': widget.bookingDetails['type'] ?? 'ON Call',
        'reason': widget.bookingDetails['reason'] ?? '',
        'amount': double.tryParse(amount) ?? 0.0,
        'consultationFee': _lawyerData?['consultationFee'] ?? double.tryParse(amount) ?? 0.0,
        'status': 'confirmed',
        'paymentStatus': 'paid',
        'transactionId': transactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save booking to Firestore
      final bookingRef = await _firestore.collection('bookings').add(bookingData);
      print('Booking saved with ID: ${bookingRef.id}');

      // Also save to lawyer's specific bookings subcollection for easier querying
      if (widget.bookingDetails['lawyerId'] != null && widget.bookingDetails['lawyerId'].isNotEmpty) {
        await _firestore
            .collection('lawyers')
            .doc(widget.bookingDetails['lawyerId'])
            .collection('bookings')
            .doc(bookingRef.id)
            .set({
          ...bookingData,
          'bookingId': bookingRef.id,
        });
      }

      // Save to client's bookings subcollection
      if (currentUser != null) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('bookings')
            .doc(bookingRef.id)
            .set({
          ...bookingData,
          'bookingId': bookingRef.id,
        });
      }

      setState(() => _isProcessing = false);

      // Show success dialog
      await _showPaymentSuccessDialog(amount, transactionId);

    } catch (e) {
      print('Error processing payment: $e');
      setState(() => _isProcessing = false);
      
      // Show error dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF3D4559),
          title: const Text(
            'Payment Failed',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(
            'An error occurred while processing your payment. Please try again.',
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
          ],
        ),
      );
    }
  }

  // Update the _showPaymentSuccessDialog method
  Future<void> _showPaymentSuccessDialog(String amount, String transactionId) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3D4559),
        title: const Text(
          'Payment Successful',
          style: TextStyle(
            color: Color(0xFFD0A554),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'Your payment of LKR $amount was successful!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3447),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Booking Confirmed',
                    style: const TextStyle(
                      color: Color(0xFFD0A554),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${widget.bookingDetails['date']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Time: ${widget.bookingDetails['time']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'Lawyer: ${_lawyerData?['name'] ?? widget.bookingDetails['lawyer']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'Transaction ID: $transactionId',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You will receive a confirmation email shortly.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/user-bookings');
                  },
                  child: const Text(
                    'VIEW BOOKINGS',
                    style: TextStyle(color: Color(0xFFD0A554)),
                  ),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD0A554),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/user-home');
                  },
                  child: const Text(
                    'BACK TO HOME',
                    style: TextStyle(
                      color: Color(0xFF353E55),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Update the _generateTransactionId method to be more unique
  String _generateTransactionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'TXN$timestamp$random'.substring(0, 16);
  }

  String? _extractFirstName(Map<String, dynamic>? userData) {
    if (userData == null) return null;
    final name = userData['name'] ?? userData['fullName'] ?? userData['displayName'] ?? userData['userName'];
    if (name is String && name.isNotEmpty) {
      return name.split(' ').first;
    }
    return null;
  }
}

enum CardType {
  visa,
  mastercard,
  amex,
  discover,
  other,
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(' ', '');
    
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) {
        buffer.write(' ');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && i != text.length - 1) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}