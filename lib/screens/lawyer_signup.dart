import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:complete/screens/signup_success.dart';

class LawyerSignUpScreen extends StatefulWidget {
  const LawyerSignUpScreen({super.key});

  @override
  State<LawyerSignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<LawyerSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _educationController = TextEditingController();
  final _experienceController = TextEditingController();

  // Dropdown values
  String? _selectedGender;
  String? _selectedLanguage = 'Sinhala'; // Default value
  String? _selectedSpecialization;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _languages = ['Sinhala', 'Tamil', 'English'];
  final List<String> _specializations = [
    'Property Law',
    'Marriage Law',
    'Employment Law'
  ];

  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _educationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_selectedGender == null || _selectedLanguage == null || _selectedSpecialization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isSuccess = false;
    });

    try {
      // 1. Create user in Firebase Authentication
      UserCredential userCredential = 
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );      // 2. Generate search keywords for better searchability
      List<String> searchKeywords = [];
      
      // Add name keywords
      String fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
      searchKeywords.addAll(fullName.toLowerCase().split(' '));
      searchKeywords.add(_firstNameController.text.trim().toLowerCase());
      searchKeywords.add(_lastNameController.text.trim().toLowerCase());
      
      // Add email prefix (before @ symbol) for better searchability
      String email = _emailController.text.trim().toLowerCase();
      if (email.contains('@')) {
        String emailPrefix = email.split('@')[0];
        searchKeywords.add(emailPrefix);
        // Also add parts if email has dots or numbers
        if (emailPrefix.contains('.')) {
          searchKeywords.addAll(emailPrefix.split('.'));
        }
      }
      
      // Add specialization keywords
      if (_selectedSpecialization != null) {
        searchKeywords.add(_selectedSpecialization!.toLowerCase());
        searchKeywords.addAll(_selectedSpecialization!.toLowerCase().split(' '));
      }
      
      // Add education keywords
      if (_educationController.text.trim().isNotEmpty) {
        searchKeywords.addAll(_educationController.text.trim().toLowerCase().split(' '));
      }
      
      // Add language keywords
      if (_selectedLanguage != null) {
        searchKeywords.add(_selectedLanguage!.toLowerCase());
      }
      
      // Remove duplicates and empty strings
      searchKeywords = searchKeywords.where((keyword) => keyword.isNotEmpty).toSet().toList();

      // 3. Save lawyer data in Firestore 'lawyers' collection
      await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'name': fullName, // Add combined name field
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim(),
        'education': _educationController.text.trim(),
        'experience': _experienceController.text.trim(),
        'gender': _selectedGender,
        'language': _selectedLanguage,
        'specialization': _selectedSpecialization,
        'searchKeywords': searchKeywords, // Add the generated search keywords
        'userType': 'lawyer',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'profileComplete': false,
        'approved': false, // Admin needs to approve lawyers
        'rating': 0.0,
        'casesHandled': 0,
      }, SetOptions(merge: false));

      // 4. Create a subcollection for lawyer settings/preferences
      await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(userCredential.user!.uid)
          .collection('private')
          .doc('auth')
          .set({
        'passwordLastChanged': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // 4. Send email verification
      await userCredential.user!.sendEmailVerification();

      // 5. Set success state and navigate
      setState(() => _isSuccess = true);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SignUpSuccessScreen(),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Sign up failed. Please try again.';
      if (e.code == 'weak-password') {
        errorMessage = 'Password should be at least 6 characters';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Email already in use. Please sign in instead.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database error: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted && !_isSuccess) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return const SignUpSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF353E55),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo and Title Section
                Column(
                  children: [
                    Image.asset(
                      'assets/images/legal_web_1.png',
                      width: 100,
                      height: 100,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'LEGAL WEB',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD0A554),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'YOUR TRUSTED LEGAL PARTNER,',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFFD9D9D9),
                      ),
                    ),
                    Text(
                      'ANYTIME, ANYWHERE.....',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFFD9D9D9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Sign Up Form
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      // First Name Field
                      TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          if (value.length < 2) {
                            return 'Name too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Last Name Field
                      TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Phone Number Field
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your phone number';
                          }
                          if (value.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Gender Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: const Icon(Icons.transgender),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _genders.map((String gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your gender';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Education Field
                      TextFormField(
                        controller: _educationController,
                        decoration: InputDecoration(
                          labelText: 'Education',
                          prefixIcon: const Icon(Icons.school),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your education';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Experience Field
                      TextFormField(
                        controller: _experienceController,
                        decoration: InputDecoration(
                          labelText: 'Experience (Years)',
                          prefixIcon: const Icon(Icons.work_history),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your experience';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Language Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: InputDecoration(
                          labelText: 'Language',
                          prefixIcon: const Icon(Icons.language),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _languages.map((String language) {
                          return DropdownMenuItem<String>(
                            value: language,
                            child: Text(language),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your language';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Specialization Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedSpecialization,
                        decoration: InputDecoration(
                          labelText: 'Practice Courts',
                          prefixIcon: const Icon(Icons.gavel),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _specializations.map((String specialization) {
                          return DropdownMenuItem<String>(
                            value: specialization,
                            child: Text(specialization),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedSpecialization = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select your specialization';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),
                      // Confirm Password Field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 25),
                      // Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD0A554),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isLoading ? null : _signUp,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Already have an account? Sign In
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(
                              color: const Color(0xFF353E55),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.pushReplacementNamed(context, '/signin');
                                  },
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: const Color(0xFFD0A554),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}