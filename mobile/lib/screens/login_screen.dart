// """
// Login Screen
// ============
// This screen allows users to login with their email and password.
// After successful login, the user is redirected to the flight search screen.
// """

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ait_fly_logo.dart';
import 'register_screen.dart';
import 'flight_search_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for text fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Password visibility toggle
  bool _obscurePassword = true;
  
  // Loading state
  bool _isLoading = false;
  
  // Error message
  String? _errorMessage;

  @override
  void dispose() {
    // Clean up controllers when screen is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle login button press
  Future<void> _handleLogin() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call API to login
      final request = LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      await ApiService.login(request);

      // If successful, navigate to flight search
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FlightSearchScreen()),
        );
      }
    } catch (e) {
      // Show error message
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Gemini_Generated_Image_y9h8vry9h8vry9h8.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Semi-transparent overlay for better text readability
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
          ),
          child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                  
                  // Header with AIT Fly logo
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cloud background
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CloudPainter(),
                          ),
                        ),
                        // AIT Fly Logo
                        const AITFlyLogo(size: 80),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Welcome title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => AITFlyTheme.primaryGradient.createShader(bounds),
                          child: const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Log in to continue your journey',
                          style: AITFlyTheme.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Form fields
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.black),
                            labelStyle: const TextStyle(
                              color: AITFlyTheme.darkGray,
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Colors.black.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AITFlyTheme.darkPurple),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AITFlyTheme.darkPurple, width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AITFlyTheme.darkPurple),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.black),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.black,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            labelStyle: const TextStyle(
                              color: AITFlyTheme.darkGray,
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Colors.black.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AITFlyTheme.darkPurple),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AITFlyTheme.darkPurple, width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AITFlyTheme.darkPurple),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        // Forgot password
                        // Align(
                        //   alignment: Alignment.centerRight,
                        //   child: TextButton(
                        //     onPressed: () {
                        //       // TODO: Implement forgot password
                        //     },
                        //     child: Text(
                        //       'Forgot Password?',
                        //       style: AITFlyTheme.bodySmall.copyWith(
                        //         color: AITFlyTheme.primaryPurple,
                        //         fontWeight: FontWeight.w600,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AITFlyTheme.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AITFlyTheme.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AITFlyTheme.error, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AITFlyTheme.bodySmall.copyWith(color: AITFlyTheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Login button
                        Container(
                          decoration: AITFlyTheme.purpleGradientButton,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _handleLogin,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Log In',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AITFlyTheme.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'Sign Up',
                                style: AITFlyTheme.bodyMedium.copyWith(
                                  color: AITFlyTheme.primaryPurple,
                                  fontWeight: FontWeight.w600,
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
                )
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for cloud background
class CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AITFlyTheme.lightPurple.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    // Draw simple cloud shapes
    final path = Path();
    
    // Cloud 1
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.3), radius: 30));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.3, size.height * 0.3), radius: 35));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.25, size.height * 0.25), radius: 25));
    
    // Cloud 2
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.7, size.height * 0.6), radius: 28));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.6), radius: 32));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.75, size.height * 0.55), radius: 24));
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}




