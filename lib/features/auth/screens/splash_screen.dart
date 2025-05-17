import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../../dashboard/screens/home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Delayed check to allow animation to play and Firebase to initialize
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkAuth();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for auth status changes
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    // If auth status changes and we're still on the splash screen
    if (!_isCheckingAuth) {
      if (authProvider.status == AuthStatus.authenticated) {
        _navigateToHome();
      } else if (authProvider.status == AuthStatus.unauthenticated) {
        _checkOnboardingStatus();
      }
    }
  }

  Future<void> _checkAuth() async {
    setState(() {
      _isCheckingAuth = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(AppConstants.userLoggedInKey) ?? false;

    if (isLoggedIn) {
      // If SharedPreferences says logged in, but waiting for Firebase
      if (authProvider.status == AuthStatus.initial ||
          authProvider.status == AuthStatus.loading) {
        // Give Firebase a little more time to initialize
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // Final check of auth status
      if (authProvider.status == AuthStatus.authenticated) {
        _navigateToHome();
      } else {
        // If there's a mismatch between shared prefs and Firebase, go to login
        await prefs.setBool(AppConstants.userLoggedInKey, false);
        _checkOnboardingStatus();
      }
    } else {
      _checkOnboardingStatus();
    }

    setState(() {
      _isCheckingAuth = false;
    });
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    if (!mounted) return;

    if (hasSeenOnboarding) {
      _navigateToLogin();
    } else {
      _navigateToOnboarding();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _navigateToLogin() {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _navigateToOnboarding() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // App Name
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),

                const SizedBox(height: 8),

                // By Author
                Text(
                  "by Ekraj",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),

                const Spacer(),

                // Loading Indicator
                const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    color: Colors.blue,
                    minHeight: 3,
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
