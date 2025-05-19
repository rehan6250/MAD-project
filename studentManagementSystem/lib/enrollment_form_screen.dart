import 'package:flutter/material.dart';

class EnrollmentFormScreen extends StatefulWidget {
  final String courseName;
  const EnrollmentFormScreen({Key? key, required this.courseName}) : super(key: key);

  @override
  State<EnrollmentFormScreen> createState() => _EnrollmentFormScreenState();
}

class _EnrollmentFormScreenState extends State<EnrollmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String studentName = '';
  String studentMobile = '';
  String fatherName = '';
  String fatherMobile = '';
  bool currentlyStudying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Enrollment Form',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: _inputDecoration('Student Name'),
                onChanged: (v) => studentName = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration('Student Mobile'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => studentMobile = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration('Father Name'),
                onChanged: (v) => fatherName = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: _inputDecoration('Father Mobile'),
                keyboardType: TextInputType.phone,
                onChanged: (v) => fatherMobile = v,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('Currently Studying', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 12),
                  Checkbox(
                    value: currentlyStudying,
                    onChanged: (v) => setState(() => currentlyStudying = v ?? false),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pop(context, {
                        'courseName': widget.courseName,
                        'studentName': studentName,
                        'studentMobile': studentMobile,
                        'fatherName': fatherName,
                        'fatherMobile': fatherMobile,
                        'currentlyStudying': currentlyStudying,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    minimumSize: const Size(160, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Submit', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
} 