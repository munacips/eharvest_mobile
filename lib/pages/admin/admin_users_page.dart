import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  bool _loading = true;
  String? _error;
  List<User> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await AdminService.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _createUser() async {
    final form = await showAdminFormDialog(
      context,
      title: 'Create User',
      fields: const [
        AdminFormField(key: 'firstName', label: 'First name'),
        AdminFormField(key: 'lastName', label: 'Last name'),
        AdminFormField(key: 'username', label: 'Username'),
        AdminFormField(key: 'email', label: 'Email'),
        AdminFormField(key: 'password', label: 'Password', obscureText: true),
        AdminFormField(key: 'phoneNumber', label: 'Phone number'),
        AdminFormField(key: 'nationalId', label: 'National ID'),
        AdminFormField(key: 'address', label: 'Address'),
        AdminFormField(key: 'role', label: 'Role (ADMIN/FARMER/BUYER/LOGISTICS)'),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.createUser(userPayloadFromForm(form));
      if (!mounted) return;
      showAdminSnackBar(context, 'User created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editUser(User user) async {
    final form = await showAdminFormDialog(
      context,
      title: 'Edit User #${user.id}',
      fields: [
        AdminFormField(key: 'firstName', label: 'First name', initialValue: user.firstName),
        AdminFormField(key: 'lastName', label: 'Last name', initialValue: user.lastName),
        AdminFormField(key: 'username', label: 'Username', initialValue: user.username),
        AdminFormField(key: 'email', label: 'Email', initialValue: user.email),
        AdminFormField(key: 'phoneNumber', label: 'Phone number', initialValue: user.phoneNumber),
        AdminFormField(key: 'nationalId', label: 'National ID', initialValue: user.nationalId),
        AdminFormField(key: 'address', label: 'Address', initialValue: user.address),
        AdminFormField(key: 'role', label: 'Role', initialValue: user.role),
      ],
    );
    if (form == null) return;

    try {
      await AdminService.updateUser(user.id, userPayloadFromForm(form));
      if (!mounted) return;
      showAdminSnackBar(context, 'User updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete user?',
      message: 'Delete ${user.displayName}?',
    );
    if (!confirmed) return;

    try {
      await AdminService.deleteUser(user.id);
      if (!mounted) return;
      showAdminSnackBar(context, 'User deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleActive(User user) async {
    try {
      await AdminService.setUserActive(user.id, !user.active);
      if (!mounted) return;
      showAdminSnackBar(context, user.active ? 'User deactivated' : 'User activated');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleVerified(User user) async {
    try {
      await AdminService.setUserVerified(user.id, !user.verified);
      if (!mounted) return;
      showAdminSnackBar(context, user.verified ? 'User unverified' : 'User verified');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showDetails(User user) {
    showAdminDetailsDialog(
      context,
      title: user.displayName,
      rows: [
        ('ID', user.id.toString()),
        ('Username', user.username),
        ('Email', user.email),
        ('Role', user.role),
        ('Phone', user.phoneNumber),
        ('Address', user.address),
        ('Active', user.active ? 'Yes' : 'No'),
        ('Verified', user.verified ? 'Yes' : 'No'),
        ('Trust score', user.trustScore.toString()),
        ('USD balance', user.usdBalance.toStringAsFixed(2)),
        ('ZIG balance', user.zigBalance.toStringAsFixed(2)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Users',
      floatingActionButton: FloatingActionButton(
        onPressed: _createUser,
        backgroundColor: Color(primaryColour),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AdminLoadingBody();
    if (_error != null) {
      return AdminErrorBody(message: _error!, onRetry: _load);
    }
    if (_users.isEmpty) {
      return const AdminEmptyBody(message: 'No users found.');
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${user.username} · ${user.role}'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    adminStatusChip(user.active ? 'Active' : 'Inactive',
                        color: user.active ? Colors.green : Colors.grey),
                    adminStatusChip(user.verified ? 'Verified' : 'Unverified',
                        color: user.verified ? Colors.blue : Colors.orange),
                  ],
                ),
              ],
            ),
            onTap: () => _showDetails(user),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _editUser(user);
                    break;
                  case 'active':
                    _toggleActive(user);
                    break;
                  case 'verified':
                    _toggleVerified(user);
                    break;
                  case 'delete':
                    _deleteUser(user);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'active',
                  child: Text(user.active ? 'Deactivate' : 'Activate'),
                ),
                PopupMenuItem(
                  value: 'verified',
                  child: Text(user.verified ? 'Mark unverified' : 'Mark verified'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}
