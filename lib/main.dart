import 'package:flutter/material.dart';
import 'package:teabot/pages/login_page.dart';
import 'package:teabot/pages/register_page.dart';
import 'package:teabot/pages/splash_screen.dart';
import 'package:teabot/pages/home_page.dart';
import 'package:teabot/pages/chat_page.dart';
import 'package:teabot/pages/profile_settings_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Firebase App Check
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('your-recaptcha-v3-site-key'),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    
    // Initialize Firebase Storage in background
    Future(() async {
      try {
        final storage = FirebaseStorage.instance;
        final storageRef = storage.ref();
        debugPrint('Firebase Storage initialized successfully');
        debugPrint('Storage bucket: ${storageRef.bucket}');
      } catch (e) {
        debugPrint('Warning: Firebase Storage initialization failed: $e');
      }
    });
    
    debugPrint('Firebase initialized successfully');
    
    // Log initial auth state in background
    Future(() async {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Initial auth state: ${user != null ? 'Authenticated' : 'Not authenticated'}');
      if (user != null) {
        debugPrint('User ID: ${user.uid}');
        debugPrint('User Email: ${user.email}');
        debugPrint('User Display Name: ${user.displayName}');
        debugPrint('User Email Verified: ${user.emailVerified}');
        debugPrint('User Creation Time: ${user.metadata.creationTime}');
        debugPrint('User Last Sign In: ${user.metadata.lastSignInTime}');
      }
    });

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('\n=== Auth State Changed ===');
      debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
      debugPrint('Auth State: ${user != null ? 'Authenticated' : 'Not authenticated'}');
      
      if (user != null) {
        debugPrint('User Details:');
        debugPrint('- ID: ${user.uid}');
        debugPrint('- Email: ${user.email}');
        debugPrint('- Display Name: ${user.displayName}');
        debugPrint('- Email Verified: ${user.emailVerified}');
        debugPrint('- Creation Time: ${user.metadata.creationTime}');
        debugPrint('- Last Sign In: ${user.metadata.lastSignInTime}');
        debugPrint('- Phone Number: ${user.phoneNumber}');
        debugPrint('- Provider Data: ${user.providerData.map((p) => p.providerId).join(', ')}');
      } else {
        debugPrint('No user is currently signed in');
      }
      debugPrint('========================\n');
    });
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
        platform: TargetPlatform.android,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          },
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Roboto'),
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
        ),
        scrollbarTheme: ScrollbarThemeData(
          thickness: WidgetStateProperty.all(6.0),
          thumbColor: WidgetStateProperty.all(Colors.grey[400]),
          radius: const Radius.circular(3.0),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('\n=== Auth State: Waiting ===');
            debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
            debugPrint('Checking authentication state...');
            debugPrint('========================\n');
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasData) {
            final user = snapshot.data;
            debugPrint('\n=== Auth State: Authenticated ===');
            debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
            debugPrint('User Details:');
            debugPrint('- ID: ${user?.uid}');
            debugPrint('- Email: ${user?.email}');
            debugPrint('- Display Name: ${user?.displayName}');
            debugPrint('- Email Verified: ${user?.emailVerified}');
            
            // Allow access even if email is not verified
            debugPrint('User authenticated - proceeding to home page');
            debugPrint('========================\n');
            return HomePage(userName: user?.displayName);
          }
          
          debugPrint('\n=== Auth State: Not Authenticated ===');
          debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
          debugPrint('No user is currently signed in - redirecting to login');
          debugPrint('========================\n');
          return const LoginPage();
        },
      ),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => HomePage(
          userName: FirebaseAuth.instance.currentUser?.displayName,
        ),
        '/profile': (context) => const ProfileSettingsPage(),
        '/chat': (context) => const ChatPage(),
      },
      onGenerateRoute: (settings) {
        debugPrint('\n=== Route Generation ===');
        debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');
        debugPrint('Route: ${settings.name}');
        debugPrint('Arguments: ${settings.arguments}');
        debugPrint('========================\n');
        
        return MaterialPageRoute(
          builder: (context) {
            switch (settings.name) {
              case '/splash':
                return const SplashScreen();
              case '/login':
                return const LoginPage();
              case '/register':
                return const RegisterPage();
              case '/home':
                return HomePage(
                  userName: FirebaseAuth.instance.currentUser?.displayName,
                );
              case '/profile':
                return const ProfileSettingsPage();
              case '/chat':
                return const ChatPage();
              default:
                return const SplashScreen();
            }
          },
        );
      },
    );
  }
}