import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/pages/admin/admin_shared.dart';
import 'package:eharvest_mobile/services/admin_service.dart';
import 'package:flutter/material.dart';

enum AdminRoleUsersPageRole { farmer, buyer, logisticsProvider }

class AdminRoleUsersPage extends StatefulWidget {
  const AdminRoleUsersPage({super.key, required this.role});

  final AdminRoleUsersPageRole role;

  @override
  State<AdminRoleUsersPage> createState() => _AdminRoleUsersPageState();
}

class _AdminRoleUsersPageState extends State<AdminRoleUsersPage> {
  bool _loading = true;
  String? _error;
  List<User> _users = [];
  int _page = 0;
  bool _lastPage = true;
  final TextEditingController _searchController = TextEditingController();

  String get _title {
    switch (widget.role) {
      case AdminRoleUsersPageRole.farmer:
        return 'Farmers';
      case AdminRoleUsersPageRole.buyer:
        return 'Buyers';
      case AdminRoleUsersPageRole.logisticsProvider:
        return 'Logistics Providers';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (page != null) _page = page;
    });

    try {
      final search = _searchController.text.trim();
      switch (widget.role) {
        case AdminRoleUsersPageRole.farmer:
          final result = await AdminService.searchFarmers(
            search: search.isEmpty ? null : search,
            page: _page,
          );
          if (!mounted) return;
          setState(() {
            _users = result.content;
            _lastPage = result.last;
            _loading = false;
          });
        case AdminRoleUsersPageRole.buyer:
          final result = await AdminService.searchBuyers(
            search: search.isEmpty ? null : search,
            page: _page,
          );
          if (!mounted) return;
          setState(() {
            _users = result.content;
            _lastPage = result.last;
            _loading = false;
          });
        case AdminRoleUsersPageRole.logisticsProvider:
          final users = await AdminService.fetchLogisticsProviders();
          if (!mounted) return;
          setState(() {
            _users = search.isEmpty
                ? users
                : users
                      .where(
                        (user) =>
                            user.displayName.toLowerCase().contains(search.toLowerCase()) ||
                            user.email.toLowerCase().contains(search.toLowerCase()) ||
                            user.username.toLowerCase().contains(search.toLowerCase()),
                      )
                      .toList();
            _lastPage = true;
            _loading = false;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<AdminFormField> _createFields() {
    switch (widget.role) {
      case AdminRoleUsersPageRole.farmer:
        return const [
          AdminFormField(key: 'firstName', label: 'First name'),
          AdminFormField(key: 'lastName', label: 'Last name'),
          AdminFormField(key: 'username', label: 'Username'),
          AdminFormField(key: 'email', label: 'Email'),
          AdminFormField(key: 'password', label: 'Password', obscureText: true),
          AdminFormField(key: 'phoneNumber', label: 'Phone number'),
          AdminFormField(key: 'nationalId', label: 'National ID'),
          AdminFormField(key: 'address', label: 'Address'),
          AdminFormField(key: 'farmName', label: 'Farm name'),
          AdminFormField(key: 'farmLocation', label: 'Farm location'),
        ];
      case AdminRoleUsersPageRole.buyer:
        return const [
          AdminFormField(key: 'firstName', label: 'First name'),
          AdminFormField(key: 'lastName', label: 'Last name'),
          AdminFormField(key: 'username', label: 'Username'),
          AdminFormField(key: 'email', label: 'Email'),
          AdminFormField(key: 'password', label: 'Password', obscureText: true),
          AdminFormField(key: 'phoneNumber', label: 'Phone number'),
          AdminFormField(key: 'nationalId', label: 'National ID'),
          AdminFormField(key: 'address', label: 'Address'),
          AdminFormField(key: 'companyName', label: 'Company name'),
        ];
      case AdminRoleUsersPageRole.logisticsProvider:
        return const [
          AdminFormField(key: 'firstName', label: 'First name'),
          AdminFormField(key: 'lastName', label: 'Last name'),
          AdminFormField(key: 'username', label: 'Username'),
          AdminFormField(key: 'email', label: 'Email'),
          AdminFormField(key: 'password', label: 'Password', obscureText: true),
          AdminFormField(key: 'phoneNumber', label: 'Phone number'),
          AdminFormField(key: 'nationalId', label: 'National ID'),
          AdminFormField(key: 'address', label: 'Address'),
          AdminFormField(key: 'licenseNumber', label: 'License number'),
          AdminFormField(key: 'defensiveId', label: 'Defensive ID'),
        ];
    }
  }

  Map<String, dynamic> _payloadFromForm(Map<String, String> form) {
    final payload = userPayloadFromForm(form);
    switch (widget.role) {
      case AdminRoleUsersPageRole.farmer:
        payload['farmName'] = form['farmName'];
        payload['farmLocation'] = form['farmLocation'];
      case AdminRoleUsersPageRole.buyer:
        payload['companyName'] = form['companyName'];
      case AdminRoleUsersPageRole.logisticsProvider:
        payload['licenseNumber'] = form['licenseNumber'];
        payload['defensiveId'] = form['defensiveId'];
    }
    return payload;
  }

  Future<void> _create() async {
    final createTitle = switch (widget.role) {
      AdminRoleUsersPageRole.farmer => 'Create Farmer',
      AdminRoleUsersPageRole.buyer => 'Create Buyer',
      AdminRoleUsersPageRole.logisticsProvider => 'Create Logistics Provider',
    };
    final form = await showAdminFormDialog(
      context,
      title: createTitle,
      fields: _createFields(),
    );
    if (form == null) return;

    try {
      switch (widget.role) {
        case AdminRoleUsersPageRole.farmer:
          await AdminService.createFarmer(_payloadFromForm(form));
        case AdminRoleUsersPageRole.buyer:
          await AdminService.createBuyer(_payloadFromForm(form));
        case AdminRoleUsersPageRole.logisticsProvider:
          await AdminService.createLogisticsProvider(_payloadFromForm(form));
      }
      if (!mounted) return;
      showAdminSnackBar(context, 'Created successfully');
      _load(page: 0);
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _edit(User user) async {
    final form = await showAdminFormDialog(
      context,
      title: 'Edit ${user.displayName}',
      fields: _createFields().map((field) {
        String initial = '';
        switch (field.key) {
          case 'firstName':
            initial = user.firstName;
          case 'lastName':
            initial = user.lastName;
          case 'username':
            initial = user.username;
          case 'email':
            initial = user.email;
          case 'phoneNumber':
            initial = user.phoneNumber;
          case 'nationalId':
            initial = user.nationalId;
          case 'address':
            initial = user.address;
        }
        return AdminFormField(
          key: field.key,
          label: field.label,
          initialValue: initial,
          keyboardType: field.keyboardType,
          obscureText: field.obscureText,
        );
      }).toList(),
    );
    if (form == null) return;

    try {
      switch (widget.role) {
        case AdminRoleUsersPageRole.farmer:
          await AdminService.updateFarmer(user.id, _payloadFromForm(form));
        case AdminRoleUsersPageRole.buyer:
          await AdminService.updateBuyer(user.id, _payloadFromForm(form));
        case AdminRoleUsersPageRole.logisticsProvider:
          await AdminService.updateLogisticsProvider(user.id, _payloadFromForm(form));
      }
      if (!mounted) return;
      showAdminSnackBar(context, 'Updated successfully');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAdminSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(User user) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete?',
      message: 'Delete ${user.displayName}?',
    );
    if (!confirmed) return;

    try {
      switch (widget.role) {
        case AdminRoleUsersPageRole.farmer:
          await AdminService.deleteFarmer(user.id);
        case AdminRoleUsersPageRole.buyer:
          await AdminService.deleteBuyer(user.id);
        case AdminRoleUsersPageRole.logisticsProvider:
          await AdminService.deleteLogisticsProvider(user.id);
      }
      if (!mounted) return;
      showAdminSnackBar(context, 'Deleted');
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
        ('Active', user.active ? 'Yes' : 'No'),
        ('Verified', user.verified ? 'Yes' : 'No'),
        ('Trust score', user.trustScore.toString()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: _title,
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: Color(primaryColour),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search $_title',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _load(page: 0);
                  },
                ),
              ),
              onSubmitted: (_) => _load(page: 0),
            ),
          ),
          if (widget.role != AdminRoleUsersPageRole.logisticsProvider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _page > 0 && !_loading
                        ? () => _load(page: _page - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  Text('Page ${_page + 1}'),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: !_lastPage && !_loading
                        ? () => _load(page: _page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const AdminLoadingBody();
    if (_error != null) {
      return AdminErrorBody(message: _error!, onRetry: () => _load());
    }
    if (_users.isEmpty) {
      return AdminEmptyBody(message: 'No $_title found.');
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
            title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${user.username} · ${user.email}'),
            onTap: () => _showDetails(user),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _edit(user);
                    break;
                  case 'delete':
                    _delete(user);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }
}
