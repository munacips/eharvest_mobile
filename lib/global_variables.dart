// Note: You would need to import the other model files here.
// For example, in Produce.dart, you'd add: import 'farmer.dart';
// I've kept them all in one file for this example.

/// --- Base User Model ---
/// Based on User.java
class User {
  final int id;
  final String nationalId;
  final String firstName;
  final String lastName;
  final String username;
  final String role;
  final String email;
  final String password;
  final String phoneNumber;
  final String address;
  final bool active;
  final bool verified;
  final int trustScore;
  final double usdBalance;
  final double zigBalance;

  User({
    required this.id,
    required this.nationalId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.role,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.address,
    required this.active,
    required this.verified,
    required this.trustScore,
    required this.usdBalance,
    required this.zigBalance,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      nationalId: json['national_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      active: json['active'] ?? false,
      verified: json['verified'] ?? false,
      trustScore: json['trust_score'] ?? 0,
      usdBalance:
          double.tryParse(json['usd_balance']?.toString() ?? '0') ?? 0.0,
      zigBalance:
          double.tryParse(json['zig_balance']?.toString() ?? '0') ?? 0.0,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => fullName.isNotEmpty ? fullName : username;
}

/// --- Buyer Model ---
/// Based on Buyer.java (extends User)
class Buyer {
  // User fields
  final int id;
  final String nationalId;
  final String firstName;
  final String lastName;
  final String username;
  final String role;
  final String email;
  final String password;
  final String phoneNumber;
  final String address;
  final bool active;
  final bool verified;
  final int trustScore;

  // Buyer fields
  final String companyName;
  final int successfulBuys;
  final int unsuccessfulBuys;

  Buyer({
    required this.id,
    required this.nationalId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.role,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.address,
    required this.active,
    required this.verified,
    required this.trustScore,
    required this.companyName,
    required this.successfulBuys,
    required this.unsuccessfulBuys,
  });

  factory Buyer.fromJson(Map<String, dynamic> json) {
    return Buyer(
      // User fields
      id: json['id'] ?? 0,
      nationalId: json['national_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      active: json['active'] ?? false,
      verified: json['verified'] ?? false,
      trustScore: json['trust_score'] ?? 0,

      // Buyer fields
      companyName: json['company_name'] ?? '',
      successfulBuys: json['successful_buys'] ?? 0,
      unsuccessfulBuys: json['unsuccessful_buys'] ?? 0,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => fullName.isNotEmpty ? fullName : username;
}

/// --- Farmer Model ---
/// Based on Farmer.java (extends User)
class Farmer {
  // User fields
  final int id;
  final String nationalId;
  final String firstName;
  final String lastName;
  final String username;
  final String role;
  final String email;
  final String password;
  final String phoneNumber;
  final String address;
  final bool active;
  final bool verified;
  final int trustScore;

  // Farmer fields
  final String farmName;
  final String farmLocation;
  final int successfulSales;
  final int unsuccessfulSales;

  Farmer({
    required this.id,
    required this.nationalId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.role,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.address,
    required this.active,
    required this.verified,
    required this.trustScore,
    required this.farmName,
    required this.farmLocation,
    required this.successfulSales,
    required this.unsuccessfulSales,
  });

  factory Farmer.fromJson(Map<String, dynamic> json) {
    return Farmer(
      // User fields
      id: json['id'] ?? 0,
      nationalId: json['national_id'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      active: json['active'] ?? false,
      verified: json['verified'] ?? false,
      trustScore: json['trust_score'] ?? 0,

      // Farmer fields
      farmName: json['farm_name'] ?? '',
      farmLocation: json['farm_location'] ?? '',
      successfulSales: json['successful_sales'] ?? 0,
      unsuccessfulSales: json['unsuccessful_sales'] ?? 0,
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => fullName.isNotEmpty ? fullName : username;
}

/// --- LogisticsProvider Model ---
/// Based on LogisticsProvider.java (extends User)
class LogisticsProvider {
  // User fields
  final int id;
  final String nationalId;
  final String firstName;
  final String lastName;
  final String username;
  final String role;
  final String email;
  final String password;
  final String phoneNumber;
  final String address;
  final bool active;
  final bool verified;
  final int trustScore;

  // LogisticsProvider fields
  final String licenseNumber;
  final String defensiveId;

  LogisticsProvider({
    required this.id,
    required this.nationalId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.role,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.address,
    required this.active,
    required this.verified,
    required this.trustScore,
    required this.licenseNumber,
    required this.defensiveId,
  });

  factory LogisticsProvider.fromJson(Map<String, dynamic> json) {
    return LogisticsProvider(
      // User fields
      id: json['id'] ?? 0,
      nationalId: json['national_id'] ?? json['nationalId'] ?? '',
      firstName: json['first_name'] ?? json['firstName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      active: json['active'] ?? false,
      verified: json['verified'] ?? false,
      trustScore: json['trust_score'] ?? json['trustScore'] ?? 0,

      // LogisticsProvider fields
      licenseNumber: json['license_number'] ?? json['licenseNumber'] ?? '',
      defensiveId: json['defensive_id'] ?? json['defensiveId'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get displayName => fullName.isNotEmpty ? fullName : username;
}

/// --- Vehicle Model ---
/// Based on Vehicle.java
class Vehicle {
  final int id;
  final String plateNumber;
  final String type;
  final String colour;
  final LogisticsProvider? owner;

  Vehicle({
    required this.id,
    required this.plateNumber,
    required this.type,
    required this.colour,
    this.owner,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? 0,
      plateNumber: json['plate_number'] ?? '',
      type: json['type'] ?? '',
      colour: json['colour'] ?? '',
      owner: json['owner'] != null
          ? LogisticsProvider.fromJson(json['owner'])
          : null,
    );
  }
}

/// --- Produce Model ---
/// Based on Produce.java
class Produce {
  final int id;
  final String name;
  final String category;
  final String description;
  final String qualityGrade;
  final double quantity;
  final double price;
  final DateTime availableFrom;
  final DateTime harvestDate;
  final int? farmerId;
  final Farmer? farmer;

  Produce({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.qualityGrade,
    required this.quantity,
    required this.price,
    required this.availableFrom,
    required this.harvestDate,
    this.farmerId,
    this.farmer,
  });

  factory Produce.fromJson(Map<String, dynamic> json) {
    final nestedFarmerJson = json['farmer'];
    final nestedFarmerId = nestedFarmerJson is Map<String, dynamic>
        ? nestedFarmerJson['id']
        : null;

    final resolvedFarmerId =
        (json['farmer_id'] ?? json['farmerId'] ?? nestedFarmerId) as dynamic;

    return Produce(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      qualityGrade: json['quality_grade'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      availableFrom:
          DateTime.tryParse(json['available_from'] ?? '') ?? DateTime.now(),
      harvestDate:
          DateTime.tryParse(json['harvest_date'] ?? '') ?? DateTime.now(),
      farmerId: int.tryParse(resolvedFarmerId?.toString() ?? ''),
      farmer: json['farmer'] != null ? Farmer.fromJson(json['farmer']) : null,
    );
  }
}

/// --- Order Model ---
/// Based on Order.java
class Order {
  final int id;
  final DateTime orderDate;
  final double totalAmount;
  final String status;
  final Buyer? buyer;
  final Farmer? farmer;
  final LogisticsRequest? logisticsRequest;
  final bool escrowReleased;

  Order({
    required this.id,
    required this.orderDate,
    required this.totalAmount,
    required this.status,
    this.buyer,
    this.farmer,
    this.logisticsRequest,
    required this.escrowReleased,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawOrderDate = json['order_date'] ?? json['orderDate'];
    final rawTotalAmount =
        json['total_amount'] ??
        json['totalAmount'] ??
        json['total'] ??
        json['amount'];

    return Order(
      id: json['id'] ?? 0,
      orderDate:
          DateTime.tryParse(rawOrderDate?.toString() ?? '') ?? DateTime.now(),
      totalAmount: rawTotalAmount is num
          ? rawTotalAmount.toDouble()
          : (double.tryParse(rawTotalAmount?.toString() ?? '0') ?? 0.0),
      status: json['status'] ?? '',
      buyer: json['buyer'] != null ? Buyer.fromJson(json['buyer']) : null,
      farmer: json['farmer'] != null ? Farmer.fromJson(json['farmer']) : null,
      logisticsRequest: json['logistics_request'] != null
          ? LogisticsRequest.fromJson(json['logistics_request'])
          : null,
      escrowReleased: json['escrow_released'] ?? false,
    );
  }
}

/// --- OrderItem Model ---
/// Based on OrderItem.java
class OrderItem {
  final int id;
  final double price;
  final int quantity;
  final Produce? produce;
  final Order? order;

  OrderItem({
    required this.id,
    required this.price,
    required this.quantity,
    this.produce,
    this.order,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      quantity: json['quantity'] ?? 0,
      produce: json['produce'] != null
          ? Produce.fromJson(json['produce'])
          : null,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
    );
  }
}

/// --- LogisticsRequest Model ---
/// Based on LogisticsRequest.java
class LogisticsRequest {
  final int id;
  final String pickupLocation;
  final String deliveryLocation;
  final String status;
  final double cost;
  final LogisticsProvider? assignedProvider;
  final Order? order;

  LogisticsRequest({
    required this.id,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.status,
    required this.cost,
    this.assignedProvider,
    this.order,
  });

  factory LogisticsRequest.fromJson(Map<String, dynamic> json) {
    return LogisticsRequest(
      id: json['id'] ?? 0,
      pickupLocation: json['pickup_location'] ?? json['pickupLocation'] ?? '',
      deliveryLocation:
          json['delivery_location'] ?? json['deliveryLocation'] ?? '',
      status: json['status'] ?? '',
      cost: double.tryParse(json['cost']?.toString() ?? '0') ?? 0.0,
      assignedProvider:
          (json['assigned_provider'] ?? json['assignedProvider']) != null
          ? LogisticsProvider.fromJson(
              Map<String, dynamic>.from(
                (json['assigned_provider'] ?? json['assignedProvider']) as Map,
              ),
            )
          : null,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
    );
  }
}

/// --- Review Model ---
/// Based on Review.java
class Review {
  final int id;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final User? reviewer;
  final User? reviewee;

  Review({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reviewer,
    this.reviewee,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? 0,
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      reviewer: json['reviewer'] != null
          ? User.fromJson(json['reviewer'])
          : null,
      reviewee: json['reviewee'] != null
          ? User.fromJson(json['reviewee'])
          : null,
    );
  }
}

/// --- Transaction Model ---
/// Based on TransactionDto.java
class Transaction {
  final int id;
  final DateTime transactionDate;
  final double amount;
  final String status;
  final String transactionReference;
  final Buyer? buyer;
  final Farmer? farmer;
  final Order? order;

  Transaction({
    required this.id,
    required this.transactionDate,
    required this.amount,
    required this.status,
    required this.transactionReference,
    this.buyer,
    this.farmer,
    this.order,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      transactionDate:
          DateTime.tryParse(json['transaction_date'] ?? '') ?? DateTime.now(),
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? '',
      transactionReference: json['transaction_reference'] ?? '',
      buyer: json['buyer'] != null ? Buyer.fromJson(json['buyer']) : null,
      farmer: json['farmer'] != null ? Farmer.fromJson(json['farmer']) : null,
      order: json['order'] != null ? Order.fromJson(json['order']) : null,
    );
  }
}

const primaryColour = 0xFF4CAF50;
const primaryDarkColour = 0xFF2E7D32;
const accentColour = 0xFF66BB6A;
const backgroundLight = 0xFFF9F9F9;
const backgroundNeutral = 0xFFECECEC;
const textCharcoalGrey = 0xFF212121;

const api = "http://localhost:8080/api/v1/";
const authApi = "http://localhost:8080/auth/";
const aiApi = "http://localhost:8000";
