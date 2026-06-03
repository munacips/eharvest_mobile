class AdminDashboardStats {
  final int totalUsers;
  final int totalFarmers;
  final int totalBuyers;
  final int totalLogisticsProviders;
  final int totalAdmins;
  final int totalProduce;
  final int totalVehicles;
  final int totalOrders;
  final int totalReviews;
  final int totalDisputeReports;
  final int unattendedDisputeReports;
  final int unverifiedUsers;

  const AdminDashboardStats({
    required this.totalUsers,
    required this.totalFarmers,
    required this.totalBuyers,
    required this.totalLogisticsProviders,
    required this.totalAdmins,
    required this.totalProduce,
    required this.totalVehicles,
    required this.totalOrders,
    required this.totalReviews,
    required this.totalDisputeReports,
    required this.unattendedDisputeReports,
    required this.unverifiedUsers,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) => int.tryParse(value?.toString() ?? '0') ?? 0;

    return AdminDashboardStats(
      totalUsers: readInt(json['totalUsers'] ?? json['total_users']),
      totalFarmers: readInt(json['totalFarmers'] ?? json['total_farmers']),
      totalBuyers: readInt(json['totalBuyers'] ?? json['total_buyers']),
      totalLogisticsProviders: readInt(
        json['totalLogisticsProviders'] ?? json['total_logistics_providers'],
      ),
      totalAdmins: readInt(json['totalAdmins'] ?? json['total_admins']),
      totalProduce: readInt(json['totalProduce'] ?? json['total_produce']),
      totalVehicles: readInt(json['totalVehicles'] ?? json['total_vehicles']),
      totalOrders: readInt(json['totalOrders'] ?? json['total_orders']),
      totalReviews: readInt(json['totalReviews'] ?? json['total_reviews']),
      totalDisputeReports: readInt(
        json['totalDisputeReports'] ?? json['total_dispute_reports'],
      ),
      unattendedDisputeReports: readInt(
        json['unattendedDisputeReports'] ??
            json['unattended_dispute_reports'],
      ),
      unverifiedUsers: readInt(
        json['unverifiedUsers'] ?? json['unverified_users'],
      ),
    );
  }
}

class DisputeReport {
  final int id;
  final String description;
  final String status;
  final bool attendedTo;
  final DateTime createdAt;
  final int? reporterId;
  final int? orderId;
  final String? reporterName;
  final String? orderReference;

  const DisputeReport({
    required this.id,
    required this.description,
    required this.status,
    required this.attendedTo,
    required this.createdAt,
    this.reporterId,
    this.orderId,
    this.reporterName,
    this.orderReference,
  });

  factory DisputeReport.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'];
    final order = json['order'];
    final rawCreatedAt =
        json['createdAt'] ?? json['created_at'] ?? json['dateCreated'];

    return DisputeReport(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      description: (json['description'] ?? json['details'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      attendedTo: json['attendedTo'] ?? json['attended_to'] ?? false,
      createdAt:
          DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now(),
      reporterId: int.tryParse(
        (json['reporterId'] ??
                json['reporter_id'] ??
                (reporter is Map ? reporter['id'] : null))
            ?.toString() ??
            '',
      ),
      orderId: int.tryParse(
        (json['orderId'] ??
                json['order_id'] ??
                (order is Map ? order['id'] : null))
            ?.toString() ??
            '',
      ),
      reporterName: reporter is Map
          ? _userDisplayName(reporter)
          : json['reporterName']?.toString(),
      orderReference: order is Map
          ? (order['id'] ?? order['reference'])?.toString()
          : json['orderReference']?.toString(),
    );
  }

  static String userDisplayName(Map<dynamic, dynamic> user) {
    final firstName =
        (user['firstName'] ?? user['first_name'] ?? '').toString();
    final lastName = (user['lastName'] ?? user['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    if (fullName.isNotEmpty) return fullName;
    return (user['username'] ?? '').toString();
  }

  static String _userDisplayName(Map<dynamic, dynamic> user) =>
      userDisplayName(user);
}

class PagedResult<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool last;

  const PagedResult({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.last,
  });

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final rawContent = json['content'];
    final content = rawContent is List
        ? rawContent
              .whereType<Map>()
              .map(
                (item) => fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .toList()
        : <T>[];

    return PagedResult(
      content: content,
      totalElements:
          int.tryParse(json['totalElements']?.toString() ?? '0') ?? 0,
      totalPages: int.tryParse(json['totalPages']?.toString() ?? '0') ?? 0,
      number: int.tryParse(json['number']?.toString() ?? '0') ?? 0,
      size: int.tryParse(json['size']?.toString() ?? '0') ?? 0,
      last: json['last'] == true,
    );
  }
}

class AdminTransaction {
  final int id;
  final String transactionReference;
  final DateTime transactionDate;
  final double amount;
  final String status;
  final String? currency;
  final String? type;
  final String? provider;
  final String? providerReference;
  final String? buyerName;
  final String? farmerName;
  final int? orderId;

  const AdminTransaction({
    required this.id,
    required this.transactionReference,
    required this.transactionDate,
    required this.amount,
    required this.status,
    this.currency,
    this.type,
    this.provider,
    this.providerReference,
    this.buyerName,
    this.farmerName,
    this.orderId,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    final buyer = json['buyer'];
    final farmer = json['farmer'];
    final order = json['order'];
    final rawDate =
        json['transactionDate'] ??
        json['transaction_date'] ??
        json['date'];

    return AdminTransaction(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      transactionReference:
          (json['transactionReference'] ??
                  json['transaction_reference'] ??
                  '')
              .toString(),
      transactionDate:
          DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: (json['status'] ?? '').toString(),
      currency: json['currency']?.toString(),
      type: json['type']?.toString(),
      provider: json['provider']?.toString(),
      providerReference:
          (json['providerReference'] ?? json['provider_reference'])?.toString(),
      buyerName: buyer is Map ? DisputeReport.userDisplayName(buyer) : null,
      farmerName:
          farmer is Map ? DisputeReport.userDisplayName(farmer) : null,
      orderId: int.tryParse(
        (order is Map ? order['id'] : json['orderId'])?.toString() ?? '',
      ),
    );
  }
}
