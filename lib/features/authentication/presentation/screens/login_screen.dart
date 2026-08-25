import 'package:flutter/material.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/nexora_button.dart';
import '../../../../core/widgets/nexora_textfield.dart';

/// Login screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(NexoraColors.background),
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(NexoraSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(NexoraColors.text),
                ),
              ),
              SizedBox(height: NexoraSpacing.md),
              Text(
                'Sign in with your college account',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Email field
              NexoraTextField(
                label: 'Email',
                hint: 'Enter your college email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email,
              ),
              SizedBox(height: NexoraSpacing.lg),

              // Password field
              NexoraTextField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: Icons.lock,
              ),
              SizedBox(height: NexoraSpacing.md),

              // Forgot password link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Navigate to forgot password
                  },
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Color(NexoraColors.primary),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Login button
              NexoraButton(
                label: 'Login',
                onPressed: () {
                  // TODO: Handle login
                },
                isLoading: _isLoading,
                width: double.infinity,
              ),
              SizedBox(height: NexoraSpacing.lg),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: NexoraSpacing.md),
                    child: Text('OR'),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              SizedBox(height: NexoraSpacing.lg),

              // Google login button
              NexoraOutlineButton(
                label: 'Login with Google',
                onPressed: () {
                  // TODO: Handle Google login
                },
                leadingIcon: Icons.login,
                width: double.infinity,
              ),
              SizedBox(height: NexoraSpacing.xl),

              // Sign up link
              Center(
                child: RichText(
                  text: TextSpan(
                    text: "Don't have an account? ",
                    style: TextStyle(
                      color: Color(NexoraColors.textSecondary),
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: 'Sign up',
                        style: TextStyle(
                          color: Color(NexoraColors.primary),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
