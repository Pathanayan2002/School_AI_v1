import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '/frontend/screens/auth/login.dart';
import '/frontend/screens/admin/admin_home_page.dart';
import '/frontend/screens/clerk/clerk_home_page.dart';
import '/frontend/screens/teacher/teacher_home_page.dart';
import '/frontend/screens/MDM/MDM_home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Management',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminHomePage(),
        '/teacher': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final teacherId = args?['teacherId']?.toString() ?? '';
          if (teacherId.isEmpty) {
            return const LoginPage();
          }
          return TeacherHomePage(teacherId: teacherId);
        },
        '/clerk': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final clerkIdStr = args?['clerkId']?.toString();
          final clerkId = int.tryParse(clerkIdStr ?? '') ?? 0;
          if (clerkId == 0) {
            return const LoginPage();
          }
          return ClerkHomePage(clerkId: clerkId,);
        },
        '/mdm': (context) => const MDMHomePage(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const LoginPage());
      },
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'token');
    if (token != null && !JwtDecoder.isExpired(token)) {
      final role = await storage.read(key: 'user_role');
      final userId = await storage.read(key: 'user_id');
      if (role != null && userId != null) {
        switch (role) {
          case 'Admin':
          case 'SuperAdmin':
            Navigator.pushReplacementNamed(context, '/admin');
            return;
          case 'Teacher':
            Navigator.pushReplacementNamed(context, '/teacher', arguments: {'teacherId': userId});
            return;
          case 'Clerk':
            Navigator.pushReplacementNamed(context, '/clerk', arguments: {'clerkId': userId});
            return;
          case 'MDM':
            Navigator.pushReplacementNamed(context, '/mdm');
            return;
        }
      }
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}