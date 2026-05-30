import 'package:flutter/material.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/utils/responsive_breakpoints.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmLocationController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _defensiveIdController = TextEditingController();

  String _selectedRole = 'FARMER';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _farmNameController.dispose();
    _farmLocationController.dispose();
    _companyNameController.dispose();
    _licenseNumberController.dispose();
    _defensiveIdController.dispose();
    super.dispose();
  }

  bool get _isFarmer => _selectedRole == 'FARMER';
  bool get _isBuyer => _selectedRole == 'BUYER';
  bool get _isLogisticsProvider => _selectedRole == 'LOGISTICS_PROVIDER';

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.register(
      username: _usernameController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
      password: _passwordController.text,
      role: _selectedRole,
      nationalId: _nationalIdController.text,
      address: _addressController.text,
      farmName: _isFarmer ? _farmNameController.text : null,
      farmLocation: _isFarmer ? _farmLocationController.text : null,
      companyName: _isBuyer ? _companyNameController.text : null,
      licenseNumber: _isLogisticsProvider ? _licenseNumberController.text : null,
      defensiveId: _isLogisticsProvider ? _defensiveIdController.text : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      setState(() {
        _errorMessage = result.message;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Please log in.')),
    );
    Navigator.of(context).pushReplacementNamed('/login');
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      enabled: !_isLoading,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: const Color(backgroundNeutral),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(backgroundLight),
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: const Color(primaryColour),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = ResponsiveBreakpoints.isDesktopWidth(
            constraints.maxWidth,
          );
          final signupCard = Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      filled: true,
                      fillColor: const Color(backgroundNeutral),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'FARMER', child: Text('Farmer')),
                      DropdownMenuItem(value: 'BUYER', child: Text('Buyer')),
                      DropdownMenuItem(
                        value: 'LOGISTICS_PROVIDER',
                        child: Text('Logistics Provider'),
                      ),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedRole = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.person_outline,
                    validator: (v) => _requiredValidator(v, 'Username'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller: _firstNameController,
                          label: 'First Name',
                          validator: (v) => _requiredValidator(v, 'First name'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _textField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          validator: (v) => _requiredValidator(v, 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => _requiredValidator(v, 'Email'),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) => _requiredValidator(v, 'Phone number'),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _nationalIdController,
                    label: 'National ID',
                    icon: Icons.badge_outlined,
                    validator: (v) => _requiredValidator(v, 'National ID'),
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _addressController,
                    label: 'Address',
                    icon: Icons.home_outlined,
                    validator: (v) => _requiredValidator(v, 'Address'),
                  ),
                  const SizedBox(height: 12),
                  if (_isFarmer) ...[
                    _textField(
                      controller: _farmNameController,
                      label: 'Farm Name',
                      icon: Icons.agriculture_outlined,
                      validator: (v) => _requiredValidator(v, 'Farm name'),
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _farmLocationController,
                      label: 'Farm Location',
                      icon: Icons.location_on_outlined,
                      validator: (v) => _requiredValidator(v, 'Farm location'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isBuyer) ...[
                    _textField(
                      controller: _companyNameController,
                      label: 'Company Name',
                      icon: Icons.business_outlined,
                      validator: (v) => _requiredValidator(v, 'Company name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isLogisticsProvider) ...[
                    _textField(
                      controller: _licenseNumberController,
                      label: 'License Number',
                      icon: Icons.local_shipping_outlined,
                      validator: (v) => _requiredValidator(v, 'License number'),
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _defensiveIdController,
                      label: 'Defensive ID',
                      icon: Icons.verified_user_outlined,
                      validator: (v) => _requiredValidator(v, 'Defensive ID'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _textField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _textField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_reset_outlined,
                    obscure: true,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[300]!),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(primaryColour),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ResponsiveBreakpoints.maxLoginWidth,
                      ),
                      child: signupCard,
                    ),
                  )
                : signupCard,
          );
        },
      ),
    );
  }
}
