// """
// Register Screen
// ===============
// This screen allows new users to create an account.
// After successful registration, the user is automatically logged in.
// """

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/ait_fly_logo.dart';
import 'flight_search_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = RegisterRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      await ApiService.register(request);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FlightSearchScreen()),
        );
      }
    } catch (e) {
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
                          const SizedBox(height: 20),
                  
                  // Back button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: AITFlyTheme.darkGray),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Header with AIT Fly logo
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CloudPainter(),
                          ),
                        ),
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
                            'Welcome! Create your account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join AIT Fly and start your journey',
                          style: AITFlyTheme.bodyMedium.copyWith(
                            color: AITFlyTheme.mediumGray,
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
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, color: AITFlyTheme.primaryPurple),
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
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline, color: AITFlyTheme.primaryPurple),
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
                        const SizedBox(height: 16),

                        // Confirm password field
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: Icon(Icons.lock_outline, color: AITFlyTheme.primaryPurple),
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
                        const SizedBox(height: 24),

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

                        // Register button
                        Container(
                          decoration: AITFlyTheme.purpleGradientButton,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _handleRegister,
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
                                        'Sign Up',
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

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: AITFlyTheme.bodyMedium.copyWith(
                                color: AITFlyTheme.mediumGray,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Log In',
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

// Reuse CloudPainter from login screen
class CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AITFlyTheme.lightPurple.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.3), radius: 30));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.3, size.height * 0.3), radius: 35));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.25, size.height * 0.25), radius: 25));
    
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.7, size.height * 0.6), radius: 28));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.6), radius: 32));
    path.addOval(Rect.fromCircle(center: Offset(size.width * 0.75, size.height * 0.55), radius: 24));
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}




