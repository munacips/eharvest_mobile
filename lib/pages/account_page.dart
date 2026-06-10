import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/chat_models.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/chat_service.dart';
import 'package:eharvest_mobile/pages/chat_conversation_page.dart';
import 'package:eharvest_mobile/widgets/reviews_section.dart';
import 'package:eharvest_mobile/services/dispute_report_service.dart';

class AccountPage extends StatefulWidget {
  final int id;

  const AccountPage({super.key, required this.id});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  User? user;
  Farmer? farmer;
  Buyer? buyer;
  LogisticsProvider? logisticsProvider;
  bool isLoading = true;
  bool isStartingConversation = false;
  String? errorMessage;
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    fetchAccountData();
  }

  Future<void> fetchAccountData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await AuthService.getToken();
      final currentId = await AuthService.getUserId();
      if (token == null || token.isEmpty) {
        setState(() {
          errorMessage = 'Authentication error. Please log in again.';
          isLoading = false;
        });
        return;
      }

      setState(() {
        currentUserId = currentId;
      });

      final candidateEndpoints = <String>[
        'farmers',
        'buyers',
        'logistics-providers',
        'users',
      ];
      final triedStatuses = <String>[];

      Map<String, dynamic>? finalData;
      String? resolvedEndpoint;

      for (final endpoint in candidateEndpoints) {
        final uri = Uri.parse('$api$endpoint/${widget.id}');
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        triedStatuses.add('/$endpoint/${widget.id}: ${response.statusCode}');

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            finalData = decoded;
            resolvedEndpoint = endpoint;
            break;
          }
        }
      }

      if (finalData == null) {
        setState(() {
          errorMessage =
              'Failed to load account details. Tried ${triedStatuses.join(', ')}';
          isLoading = false;
        });
        return;
      }

      final roleRaw = (finalData['role'] ?? '').toString();
      final roleKey = roleRaw.trim().toLowerCase().replaceAll(' ', '_');

      if (roleKey == 'farmer' || resolvedEndpoint == 'farmers') {
        farmer = Farmer.fromJson(finalData);
        buyer = null;
        logisticsProvider = null;
        user = null;
      } else if (roleKey == 'buyer' || resolvedEndpoint == 'buyers') {
        buyer = Buyer.fromJson(finalData);
        farmer = null;
        logisticsProvider = null;
        user = null;
      } else if (roleKey == 'logistics_provider' ||
          roleKey == 'logisticsprovider' ||
          resolvedEndpoint == 'logistics-providers') {
        logisticsProvider = LogisticsProvider.fromJson(finalData);
        buyer = null;
        farmer = null;
        user = null;
      } else {
        user = User.fromJson(finalData);
        buyer = null;
        farmer = null;
        logisticsProvider = null;
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading account details: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _startConversation() async {
    if (isStartingConversation) return;

    setState(() {
      isStartingConversation = true;
    });

    try {
      final currentUserId = await AuthService.getUserId();
      if (currentUserId == null) {
        throw Exception('Authentication required to start a conversation.');
      }

      if (currentUserId == widget.id) {
        throw Exception('You cannot start a conversation with yourself.');
      }

      final chatService = ChatService.instance;
      await chatService.ensureConnected();

      final conversations = await chatService.fetchConversations(
        userId: currentUserId,
      );

      ChatConversation? existingConversation;
      for (final conversation in conversations) {
        final memberIds =
            conversation.members.map((member) => member.userId).toSet();
        if (!conversation.isGroup &&
            memberIds.length == 2 &&
            memberIds.contains(currentUserId) &&
            memberIds.contains(widget.id)) {
          existingConversation = conversation;
          break;
        }
      }

      final conversation = existingConversation ??
          await chatService.createConversation(
            CreateConversationRequest(
              memberIds: [currentUserId, widget.id],
              name: null,
              isGroup: false,
            ),
          );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationPage(conversation: conversation),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isStartingConversation = false;
        });
      }
    }
  }

  void _showReportDialog() {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    var isSubmitting = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Report User'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please provide a description or reason for filing this report/dispute.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Reason for report',
                        hintText: 'Enter details here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState?.validate() != true) return;

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          final navigator = Navigator.of(dialogContext);
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            await DisputeReportService.createReport(
                              description: controller.text.trim(),
                              filedAgainstId: widget.id,
                            );

                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Report filed successfully.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final personalTiles = _buildPersonalInfoTiles();
    final businessTiles = _buildBusinessInfoTiles();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Account Profile'),
        backgroundColor: Color(primaryColour),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTrustCard(),
                            const SizedBox(height: 20),
                            ReviewsSection(userId: widget.id),
                            const SizedBox(height: 20),
                            if (personalTiles.isNotEmpty) ...[
                              _buildInfoSection(
                                'Contact Information',
                                personalTiles,
                              ),
                              const SizedBox(height: 20),
                            ],
                            if (businessTiles.isNotEmpty) ...[
                              _buildInfoSection(
                                'Business Details',
                                businessTiles,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _getField('fullName')?.toString() ?? '-';
    final role = _normalizedRole;
    final verified = _getField('verified') == true;
    final canInteract = widget.id > 0 && currentUserId != widget.id;

    return Container(
      width: double.infinity,
      // No fixed height — let content dictate size
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 28),
      decoration: BoxDecoration(
        color: Color(primaryColour),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 52, color: Colors.grey),
              ),
              if (verified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            role.isNotEmpty ? role : '-',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 1.1,
            ),
          ),
          if (canInteract) ...[
            const SizedBox(height: 16),
            // Use Column instead of Wrap so both buttons always render
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed:
                      isStartingConversation ? null : _startConversation,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(primaryColour),
                    minimumSize: const Size(200, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: isStartingConversation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    isStartingConversation ? 'Opening chat...' : 'Message user',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _showReportDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    minimumSize: const Size(200, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Report user'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrustCard() {
    final trustScore = _getField('trustScore');
    double trustValue = 0;
    if (trustScore != null) {
      trustValue = double.tryParse(trustScore.toString()) ?? 0;
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trust Score',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trustScore != null ? '$trustScore/100' : '-',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(primaryColour),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: trustValue / 100,
                backgroundColor: Colors.grey[200],
                color: Color(primaryColour),
                strokeWidth: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(
            title,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  List<Widget> _buildPersonalInfoTiles() {
    final tiles = <Widget>[];
    _addInfoTileIfValue(tiles, Icons.email, 'Email', _getField('email'));
    _addInfoTileIfValue(
        tiles, Icons.phone, 'Phone', _getField('phoneNumber'));
    _addInfoTileIfValue(tiles, Icons.home, 'Address', _getField('address'));
    return tiles;
  }

  List<Widget> _buildBusinessInfoTiles() {
    final tiles = <Widget>[];
    if (_isFarmer) {
      _addInfoTileIfValue(
          tiles, Icons.agriculture, 'Farm Name', _getField('farmName'));
      _addInfoTileIfValue(tiles, Icons.location_on, 'Farm Location',
          _getField('farmLocation'));
      _addInfoTileIfValue(tiles, Icons.check_circle, 'Successful Sales',
          _getField('successfulSales'));
    } else if (_isBuyer) {
      _addInfoTileIfValue(
          tiles, Icons.business, 'Company Name', _getField('companyName'));
      _addInfoTileIfValue(tiles, Icons.shopping_cart_checkout,
          'Successful Buys', _getField('successfulBuys'));
    } else if (_isLogisticsProvider) {
      _addInfoTileIfValue(tiles, Icons.local_shipping, 'License Number',
          _getField('licenseNumber'));
    }
    return tiles;
  }

  void _addInfoTileIfValue(
    List<Widget> tiles,
    IconData icon,
    String label,
    Object? value,
  ) {
    if (_hasValue(value)) {
      tiles.add(_infoTile(icon, label, value));
    }
  }

  bool _hasValue(Object? value) {
    if (value == null) return false;
    final text = value.toString().trim();
    return text.isNotEmpty && text.toLowerCase() != 'null';
  }

  String get _normalizedRole =>
      (_getField('role')?.toString().trim().toUpperCase() ?? '');

  bool get _isFarmer => _normalizedRole == 'FARMER';
  bool get _isBuyer => _normalizedRole == 'BUYER';
  bool get _isLogisticsProvider => _normalizedRole == 'LOGISTICS_PROVIDER';

  Object? _getField(String key) {
    if (farmer != null) {
      switch (key) {
        case 'fullName':
          return farmer!.fullName;
        case 'role':
          return farmer!.role;
        case 'verified':
          return farmer!.verified;
        case 'email':
          return farmer!.email;
        case 'phoneNumber':
          return farmer!.phoneNumber;
        case 'address':
          return farmer!.address;
        case 'trustScore':
          return farmer!.trustScore.toString();
        case 'farmName':
          return farmer!.farmName;
        case 'farmLocation':
          return farmer!.farmLocation;
        case 'successfulSales':
          return farmer!.successfulSales.toString();
        default:
          return null;
      }
    }

    if (buyer != null) {
      switch (key) {
        case 'fullName':
          return buyer!.fullName;
        case 'role':
          return buyer!.role;
        case 'verified':
          return buyer!.verified;
        case 'email':
          return buyer!.email;
        case 'phoneNumber':
          return buyer!.phoneNumber;
        case 'address':
          return buyer!.address;
        case 'trustScore':
          return buyer!.trustScore.toString();
        case 'companyName':
          return buyer!.companyName;
        case 'successfulBuys':
          return buyer!.successfulBuys.toString();
        default:
          return null;
      }
    }

    if (logisticsProvider != null) {
      switch (key) {
        case 'fullName':
          return logisticsProvider!.fullName;
        case 'role':
          return logisticsProvider!.role;
        case 'verified':
          return logisticsProvider!.verified;
        case 'email':
          return logisticsProvider!.email;
        case 'phoneNumber':
          return logisticsProvider!.phoneNumber;
        case 'address':
          return logisticsProvider!.address;
        case 'trustScore':
          return logisticsProvider!.trustScore.toString();
        case 'licenseNumber':
          return logisticsProvider!.licenseNumber;
        default:
          return null;
      }
    }

    if (user != null) {
      switch (key) {
        case 'fullName':
          return user!.fullName;
        case 'role':
          return user!.role;
        case 'verified':
          return user!.verified;
        case 'email':
          return user!.email;
        case 'phoneNumber':
          return user!.phoneNumber;
        case 'address':
          return user!.address;
        case 'trustScore':
          return user!.trustScore.toString();
        default:
          return null;
      }
    }

    return null;
  }

  Widget _infoTile(IconData icon, String label, Object? value) {
    return ListTile(
      leading: Icon(icon, color: Color(primaryColour)),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value?.toString() ?? '-',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );
  }
}