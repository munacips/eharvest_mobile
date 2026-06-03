import 'package:eharvest_mobile/global_variables.dart';
import 'package:flutter/material.dart';

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Color(primaryColour),
        foregroundColor: Colors.white,
        actions: actions,
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}

class AdminLoadingBody extends StatelessWidget {
  const AdminLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class AdminErrorBody extends StatelessWidget {
  const AdminErrorBody({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.error_outline, color: Colors.red[400], size: 56),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}

class AdminEmptyBody extends StatelessWidget {
  const AdminEmptyBody({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: Colors.grey),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }
}

Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showAdminDetailsDialog(
  BuildContext context, {
  required String title,
  required List<(String label, String value)> rows,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(row.$2),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void showAdminSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Widget adminStatusChip(String label, {Color? color}) {
  return Chip(
    label: Text(label),
    backgroundColor: (color ?? Color(primaryColour)).withValues(alpha: 0.12),
    labelStyle: TextStyle(color: color ?? Color(primaryDarkColour)),
    visualDensity: VisualDensity.compact,
  );
}

Future<Map<String, String>?> showAdminFormDialog(
  BuildContext context, {
  required String title,
  required List<AdminFormField> fields,
  String submitLabel = 'Save',
}) async {
  final controllers = <String, TextEditingController>{
    for (final field in fields) field.key: TextEditingController(text: field.initialValue),
  };

  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: fields
              .map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[field.key],
                    decoration: InputDecoration(
                      labelText: field.label,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: field.keyboardType,
                    obscureText: field.obscureText,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              controllers.map((key, controller) => MapEntry(key, controller.text.trim())),
            );
          },
          child: Text(submitLabel),
        ),
      ],
    ),
  );

  for (final controller in controllers.values) {
    controller.dispose();
  }
  return result;
}

class AdminFormField {
  const AdminFormField({
    required this.key,
    required this.label,
    this.initialValue = '',
    this.keyboardType,
    this.obscureText = false,
  });

  final String key;
  final String label;
  final String initialValue;
  final TextInputType? keyboardType;
  final bool obscureText;
}

String formatAdminDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

Map<String, dynamic> userPayloadFromForm(Map<String, String> form) {
  return {
    'nationalId': form['nationalId'],
    'firstName': form['firstName'],
    'lastName': form['lastName'],
    'username': form['username'],
    'email': form['email'],
    'password': form['password'],
    'phoneNumber': form['phoneNumber'],
    'address': form['address'],
    'role': form['role'],
  }..removeWhere((key, value) => value == null || value.toString().isEmpty);
}
