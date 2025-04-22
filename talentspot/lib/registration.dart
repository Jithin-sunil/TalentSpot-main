import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart'; // Added file_picker package
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:typed_data'; // Required for Uint8List
import 'package:talentspot/login.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedGender = 'Male'; // Default gender
  String? _selectedCategoryId; // Selected category ID
  Map<String, String> _categories = {}; // Map of category IDs to names
  PlatformFile? _pickedImage; // Stores the selected image file
  bool _isLoading = false;
  bool _obscurePassword = true;
  final supabase = Supabase.instance.client;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _fetchCategories(); // Fetch categories from tbl_category
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Fetch categories from tbl_category
  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('tbl_category').select();
      if (response != null) {
        setState(() {
          _categories = Map<String, String>.fromEntries(
            (response as List).map(
              (category) => MapEntry(
                category['id'].toString(),
                category['category_name'],
              ),
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  // Method to pick an image using file_picker
  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image, // Only allow image files
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedImage = result.files.first; // Set the selected image
      });
    }
  }

  // Method to upload the image directly to the bucket
  Future<String?> _uploadProfilePicture(String userId) async {
    if (_pickedImage == null) return null;

    final fileName = '$userId-${_pickedImage!.name}';
    try {
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName, // Upload directly to the bucket without a subfolder
            _pickedImage!.bytes!, // Use bytes for web compatibility
          );

      return supabase.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (authResponse.user != null) {
        String? profilePicUrl = await _uploadProfilePicture(
          authResponse.user!.id,
        );

        await supabase.from('tbl_user').insert({
          'user_id': authResponse.user!.id,
          'user_email': _emailController.text.trim(),
          'user_name': _nameController.text.trim(),
          'user_age': int.tryParse(_ageController.text.trim()) ?? 0,
          'user_gender': _selectedGender,
          'user_contact': _phoneController.text.trim(),
          'category_id': _selectedCategoryId, // Use category ID
          'user_photo': profilePicUrl,
          'user_password': _passwordController.text,
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Create Account', style: GoogleFonts.poppins()),
        elevation: 0,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile image picker
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage:
                              _pickedImage != null
                                  ? _pickedImage!.bytes != null
                                      ? MemoryImage(
                                        Uint8List.fromList(
                                          _pickedImage!.bytes!,
                                        ),
                                      )
                                      : FileImage(File(_pickedImage!.path!))
                                  : null,
                          child:
                              _pickedImage == null
                                  ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: theme.colorScheme.primary,
                                  )
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap:
                                _pickImage, // Use file_picker to select an image
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Please enter your name'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(
                        Icons.email,
                        color: theme.colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(
                        Icons.lock,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: _obscurePassword,
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
                  // Age
                  TextFormField(
                    controller: _ageController,
                    decoration: InputDecoration(
                      labelText: 'Age',
                      prefixIcon: Icon(
                        Icons.cake,
                        color: theme.colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your age';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid age';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Gender selection using RadioListTile
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gender',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8), // Vertical spacing
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding:
                                  EdgeInsets.zero, // Remove default padding
                              title: const Text(
                                'Male',
                                 style: TextStyle(
                                  fontSize: 12,
                                ),
                                // textAlign: TextAlign.left,
                              ),
                              value: 'Male',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() => _selectedGender = value!);
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding:
                                  EdgeInsets.zero, // Remove default padding
                              title: const Text(
                                'Female',
                                style: TextStyle(
                                  fontSize: 12,
                                ),
                                // textAlign: TextAlign.center,
                              ),
                              value: 'Female',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() => _selectedGender = value!);
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              contentPadding:
                                  EdgeInsets.zero, // Remove default padding
                              title: const Text(
                                'Other',
                                 style: TextStyle(
                                  fontSize: 12,
                                ),
                                // textAlign: TextAlign.center,
                              ),
                              value: 'Other',
                              groupValue: _selectedGender,
                              onChanged: (value) {
                                setState(() => _selectedGender = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Category selection from tbl_category
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Talent Category',
                      prefixIcon: Icon(
                        Icons.category,
                        color: theme.colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: _selectedCategoryId,
                    items:
                        _categories.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Please select a talent category'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(
                        Icons.phone,
                        color: theme.colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Please enter your phone number'
                                : null,
                  ),
                  const SizedBox(height: 32),
                  // Register button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child:
                        _isLoading
                            ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onPrimary,
                                ),
                              ),
                            )
                            : Text(
                              'Register',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                  const SizedBox(height: 16),
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            ),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
