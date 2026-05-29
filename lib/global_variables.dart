import 'package:flutter/foundation.dart';

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
      trustScore:
          int.tryParse(
            (json['trust_score'] ?? json['trustScore'] ?? 0).toString(),
          ) ??
          0,
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
  final double usdBalance;
  final double zigBalance;

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
    required this.usdBalance,
    required this.zigBalance,
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
      trustScore:
          int.tryParse(
            (json['trust_score'] ?? json['trustScore'] ?? 0).toString(),
          ) ??
          0,
      usdBalance:
          double.tryParse(
            (json['usd_balance'] ?? json['usdBalance']).toString(),
          ) ??
          0.0,
      zigBalance:
          double.tryParse(
            (json['zig_balance'] ?? json['zigBalance']).toString(),
          ) ??
          0.0,

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
  final double usdBalance;
  final double zigBalance;

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
    required this.usdBalance,
    required this.zigBalance,
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
      trustScore:
          int.tryParse(
            (json['trust_score'] ?? json['trustScore'] ?? 0).toString(),
          ) ??
          0,
      usdBalance:
          double.tryParse(
            (json['usd_balance'] ?? json['usdBalance']).toString(),
          ) ??
          0.0,
      zigBalance:
          double.tryParse(
            (json['zig_balance'] ?? json['zigBalance']).toString(),
          ) ??
          0.0,

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
  final double usdBalance;
  final double zigBalance;

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
    required this.usdBalance,
    required this.zigBalance,
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
      trustScore:
          int.tryParse(
            (json['trust_score'] ?? json['trustScore'] ?? 0).toString(),
          ) ??
          0,
      usdBalance:
          double.tryParse(
            (json['usd_balance'] ?? json['usdBalance']).toString(),
          ) ??
          0.0,
      zigBalance:
          double.tryParse(
            (json['zig_balance'] ?? json['zigBalance']).toString(),
          ) ??
          0.0,

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
  final String cityTown;
  final double longitude;
  final double latitude;
  final DateTime availableFrom;
  final DateTime harvestDate;
  final int? farmerId;
  final Farmer? farmer;
  final List<String> imageUrls;
  final bool canProvideTransport;

  Produce({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.qualityGrade,
    required this.quantity,
    required this.price,
    required this.cityTown,
    required this.longitude,
    required this.latitude,
    required this.availableFrom,
    required this.harvestDate,
    this.farmerId,
    this.farmer,
    this.imageUrls = const [],
    this.canProvideTransport = false,
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
      qualityGrade: json['qualityGrade'] ?? json['quality_grade'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      cityTown: json['cityTown'] ?? json['city_town'] ?? '',
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      availableFrom:
          DateTime.tryParse(
            (json['availableFrom'] ?? json['available_from'] ?? '').toString(),
          ) ??
          DateTime.now(),
      harvestDate:
          DateTime.tryParse(
            (json['harvestDate'] ?? json['harvest_date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      farmerId: int.tryParse(resolvedFarmerId?.toString() ?? ''),
      farmer: nestedFarmerJson is Map<String, dynamic>
          ? Farmer.fromJson(nestedFarmerJson)
          : null,
      imageUrls: (json['imageUrls'] ?? json['image_urls']) is List
          ? List<String>.from(
              ((json['imageUrls'] ?? json['image_urls']) as List).map(
                (url) => url.toString(),
              ),
            )
          : const [],
      canProvideTransport:
          json['canProvideTransport'] ?? json['can_provide_transport'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'qualityGrade': qualityGrade,
      'quantity': quantity,
      'price': price,
      'cityTown': cityTown,
      'longitude': longitude,
      'latitude': latitude,
      'availableFrom': availableFrom.toIso8601String().split('T').first,
      'harvestDate': harvestDate.toIso8601String().split('T').first,
      if (farmer != null) 'farmer': {'id': farmer!.id},
      if (farmer == null && farmerId != null) 'farmer': {'id': farmerId},
      'imageUrls': imageUrls,
      'canProvideTransport': canProvideTransport,
    };
  }
}

/// --- Order Model ---
/// Based on Order.java
class Order {
  final int id;
  final DateTime orderDate;
  final double totalAmount;
  final double escrowAmount;
  final String currency;
  final String status;
  final Buyer? buyer;
  final Farmer? farmer;
  final LogisticsRequest? logisticsRequest;
  final bool escrowReleased;
  final String logisticsType;
  final double? transportFee;
  final bool escrowHeld;

  Order({
    required this.id,
    required this.orderDate,
    required this.totalAmount,
    required this.escrowAmount,
    required this.currency,
    required this.status,
    this.buyer,
    this.farmer,
    this.logisticsRequest,
    required this.escrowReleased,
    this.logisticsType = 'THIRD_PARTY',
    this.transportFee,
    this.escrowHeld = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawOrderDate = json['order_date'] ?? json['orderDate'];
    final rawTotalAmount =
        json['total_amount'] ??
        json['totalAmount'] ??
        json['total'] ??
        json['amount'];
    final rawEscrowAmount =
        json['escrow_amount'] ?? json['escrowAmount'] ?? rawTotalAmount;
    final rawTransportFee = json['transport_fee'] ?? json['transportFee'];

    return Order(
      id: json['id'] ?? 0,
      orderDate:
          DateTime.tryParse(rawOrderDate?.toString() ?? '') ?? DateTime.now(),
      totalAmount: rawTotalAmount is num
          ? rawTotalAmount.toDouble()
          : (double.tryParse(rawTotalAmount?.toString() ?? '0') ?? 0.0),
      escrowAmount: rawEscrowAmount is num
          ? rawEscrowAmount.toDouble()
          : (double.tryParse(rawEscrowAmount?.toString() ?? '0') ?? 0.0),
      currency: (json['currency'] ?? 'USD').toString(),
      status: json['status'] ?? '',
      buyer: json['buyer'] != null ? Buyer.fromJson(json['buyer']) : null,
      farmer: json['farmer'] != null ? Farmer.fromJson(json['farmer']) : null,
      logisticsRequest: json['logistics_request'] != null
          ? LogisticsRequest.fromJson(json['logistics_request'])
          : null,
      escrowReleased:
          json['escrow_released'] ?? json['escrowReleased'] ?? false,
      logisticsType:
          (json['logistics_type'] ?? json['logisticsType'] ?? 'THIRD_PARTY')
              .toString(),
      transportFee: rawTransportFee == null
          ? null
          : (rawTransportFee is num
                ? rawTransportFee.toDouble()
                : double.tryParse(rawTransportFee.toString())),
      escrowHeld: json['escrow_held'] ?? json['escrowHeld'] ?? false,
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
  final bool escrowHeld;
  final bool escrowReleased;
  final LogisticsProvider? assignedProvider;
  final Order? order;

  LogisticsRequest({
    required this.id,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.status,
    required this.cost,
    required this.escrowHeld,
    required this.escrowReleased,
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
      escrowHeld: json['escrowHeld'] ?? json['escrow_held'] ?? false,
      escrowReleased:
          json['escrowReleased'] ?? json['escrow_released'] ?? false,
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
  final int orderId;
  final int rating;
  final String comment;
  final String status;
  final DateTime createdAt;
  final int reviewerId;
  final int revieweeId;
  final User? reviewer;
  final User? reviewee;

  Review({
    required this.id,
    required this.orderId,
    required this.rating,
    required this.comment,
    required this.status,
    required this.createdAt,
    required this.reviewerId,
    required this.revieweeId,
    this.reviewer,
    this.reviewee,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final reviewerJson = json['reviewer'];
    final revieweeJson = json['reviewee'];
    final rawCreatedAt =
        json['createdAt'] ?? json['created_at'] ?? json['dateCreated'];
    return Review(
      id: json['id'] ?? 0,
      orderId: int.tryParse(
            (json['orderId'] ??
                    json['order_id'] ??
                    (json['order'] is Map ? json['order']['id'] : 0))
                .toString(),
          ) ??
          0,
      rating: int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      comment: json['comment'] ?? '',
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now(),
      reviewerId:
          int.tryParse(
            (json['reviewerId'] ??
                    json['reviewer_id'] ??
                    (reviewerJson is Map ? reviewerJson['id'] : 0))
                .toString(),
          ) ??
          0,
      revieweeId:
          int.tryParse(
            (json['revieweeId'] ??
                    json['reviewee_id'] ??
                    (revieweeJson is Map ? revieweeJson['id'] : 0))
                .toString(),
          ) ??
          0,
      reviewer: reviewerJson is Map<String, dynamic>
          ? User.fromJson(reviewerJson)
          : (reviewerJson is Map
                ? User.fromJson(
                    reviewerJson.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  )
                : null),
      reviewee: revieweeJson is Map<String, dynamic>
          ? User.fromJson(revieweeJson)
          : (revieweeJson is Map
                ? User.fromJson(
                    revieweeJson.map(
                      (key, value) => MapEntry(key.toString(), value),
                    ),
                  )
                : null),
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

class HeatmapPoint {
  final double latitude;
  final double longitude;
  final double normalizedWeight;

  HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.normalizedWeight,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    final latitude =
        double.tryParse((json['latitude'] ?? json['lat'] ?? '').toString()) ??
        0.0;
    final longitude =
        double.tryParse((json['longitude'] ?? json['lng'] ?? '').toString()) ??
        0.0;
    final rawWeight =
        json['weight_kg'] ??
        json['weightKg'] ??
        json['normalizedWeight'] ??
        json['normalized_weight'] ??
        0.0;
    final weightKg = double.tryParse(rawWeight.toString()) ?? 0.0;

    return HeatmapPoint(
      latitude: latitude,
      longitude: longitude,
      // Legacy property name retained; value is now raw kilograms.
      normalizedWeight: weightKg,
    );
  }
}

const primaryColour = 0xFF4CAF50;
const primaryDarkColour = 0xFF2E7D32;
const accentColour = 0xFF66BB6A;
const backgroundLight = 0xFFF9F9F9;
const backgroundNeutral = 0xFFECECEC;
const textCharcoalGrey = 0xFF212121;

class AppConfig {
  static const String _scheme =
      String.fromEnvironment('EHARVEST_API_SCHEME', defaultValue: 'http');
  static const String _hostOverride = String.fromEnvironment(
    'EHARVEST_API_HOST',
    defaultValue: '',
  );
  static const String _port = String.fromEnvironment(
    'EHARVEST_API_PORT',
    defaultValue: '8080',
  );
  static const String _aiPort = String.fromEnvironment(
    'EHARVEST_AI_PORT',
    defaultValue: '8000',
  );

  static String get host {
    if (_hostOverride.isNotEmpty) {
      return _hostOverride;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static String get baseHttpUrl => '$_scheme://$host:$_port';
  static String get baseAiUrl => '$_scheme://$host:$_aiPort';
  static String get chatWebSocketUrl => '$baseHttpUrl/ws';
  static String get trackingWebSocketUrl =>
      '${_scheme == 'https' ? 'wss' : 'ws'}://$host:$_port/ws/tracking/websocket';
}

String get api => '${AppConfig.baseHttpUrl}/api/v1/';
String get reportsApi => '${AppConfig.baseHttpUrl}/api/reports/';
String get authApi => '${AppConfig.baseHttpUrl}/auth/';
String get aiApi => AppConfig.baseAiUrl;
