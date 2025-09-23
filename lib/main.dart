import 'package:complete/screens/user_signin.dart';
import 'package:complete/screens/user_signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Auth screens
import 'screens/first_page.dart';
import 'screens/lawyer_signin.dart';
import 'screens/lawyer_signup.dart';
import 'screens/signup_success.dart';
import 'screens/loading_screen.dart';

// User screens
import 'screens/user_home.dart';
import 'screens/user_profile.dart';
import 'screens/user_bookings.dart';

// Lawyer screens
import 'screens/lawyer_dashboard.dart';
import 'screens/lawyer_profile.dart';
import 'screens/lawyer_availability.dart';
import 'screens/clients.dart';
import 'screens/lawyer_bookings.dart';

// Feature screens
import 'screens/ai_chatbot.dart';
import 'screens/payment_gateway.dart';

import 'firebase_options.dart';

// New imports for forgot password screens
import 'screens/lawyer_forgot_password.dart';
import 'screens/user_forgot_password.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await dotenv.load(fileName: ".env");
  runApp(const LegalWebApp());
}

class LegalWebApp extends StatelessWidget {
  const LegalWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legal Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF353E55),
          primary: const Color(0xFF353E55),
          secondary: const Color(0xFFD0A554),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF353E55),
        ),
      ),
      initialRoute: '/',
      routes: {
        // Initial routes
        '/': (context) => const AuthWrapper(),
        '/loading': (context) => const LoadingScreen(),
        
        // Authentication routes
        '/welcome': (context) => const FirstPage(),
        '/client/signin': (context) => const UserSignInScreen(),
        '/lawyer/signin': (context) => LawyerSignInScreen(),
        '/client/signup': (context) => const UserSignUpScreen(),
        '/lawyer/signup': (context) => const LawyerSignUpScreen(),
        '/client/forgot-password': (context) => const UserForgotPasswordScreen(),
        '/lawyer/forgot-password': (context) => const LawyerForgotPasswordScreen(),
        '/signup-success': (context) => const SignUpSuccessScreen(),
        
        // Client routes
        '/client/home': (context) => const UserHome(),
        '/client/profile': (context) => const UserProfileScreen(),
        '/client/bookings': (context) => const UserBookingsScreen(),
        
        // Lawyer routes
        '/lawyer/dashboard': (context) => const LawyerDashboardScreen(), // Changed from LawyerDashboardScreen
        '/lawyer/profile': (context) => const LawyerProfile(),
        '/lawyer/availability': (context) => const LawyerAvailability(),
        '/lawyer/clients': (context) => const ClientsPage(),
        '/lawyer/bookings': (context) => const LawyerBookings(),
        
        // Feature routes
        '/ai-chatbot': (context) => const AIChatBotScreen(),
        '/payment': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args == null || args is! Map<String, dynamic>) {
            return Scaffold(
              appBar: AppBar(title: const Text('Error')),
              body: const Center(child: Text('Invalid payment details provided')),
            );
          }
          return PaymentGatewayScreen(bookingDetails: args);
        },
        '/payment-gateway': (context) {
          // Safely handle the arguments
          final args = ModalRoute.of(context)?.settings.arguments;
          final Map<String, dynamic> bookingDetails = args != null 
              ? args as Map<String, dynamic> 
              : {};
          return PaymentGatewayScreen(bookingDetails: bookingDetails);
        },
        '/user-bookings': (context) => const UserBookingsScreen(),
        '/user-profile': (context) => const UserProfileScreen(),
      },
      onGenerateRoute: (settings) {
        // Handle any additional route generation if needed
        return MaterialPageRoute(
          builder: (context) => const FirstPage(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading screen while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // If user is logged in, check their role
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }
              
              if (userSnapshot.hasError || !userSnapshot.hasData) {
                // If there's an error or no data, send to welcome screen
                return const FirstPage();
              }
              
              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final isLawyer = userData?['userType'] == 'lawyer';
              
              // Check if email is verified
              final emailVerified = snapshot.data!.emailVerified;
              if (!emailVerified) {
                // You might want to add an email verification screen here
                return const FirstPage();
              }
              
              // Check if profile is complete
              final profileComplete = userData?['profileComplete'] ?? false;
              if (!profileComplete) {
                // Redirect to profile completion screen
                return isLawyer 
                    ? const LawyerProfile() 
                    : const UserProfileScreen();
              }
              
              // Redirect to appropriate home screen
              return isLawyer 
                  ? const LawyerDashboardScreen()
                  : const UserHome();
            },
          );
        }

        // If no user is logged in
        return const FirstPage();
      },
    );
  }
}