import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:studenttasktracker/services/auth_service.dart';
import 'package:studenttasktracker/screens/admin/admin_dashboard.dart';
import 'package:studenttasktracker/screens/student/student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final student = await authService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (student != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => student.isAdmin
                ? const AdminDashboard()
                : StudentDashboard(studentId: student.id!),
          ),
              (route) => false,
        );
      } else {
        setState(() => _errorMessage = 'Invalid credentials');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _login,
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}