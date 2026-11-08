import 'package:flutter/material.dart';

import 'departments.dart';

class Product {
  final String id;
  String name;
  double price;
  String category;
  String unit;
  double stockQuantity;
  double reorderPoint;
  double reorderQuantity;
  String? supplierId;
  String? barcode;
  DateTime? lastRestocked;

  Product({required this.id, required this.name, required this.price, required this.category, this.unit = 'each', this.stockQuantity = 0.0, this.reorderPoint = 5.0, this.reorderQuantity = 20.0, this.supplierId, this.barcode, this.lastRestocked});

  bool get isLowStock => stockQuantity <= reorderPoint;
  bool get isOutOfStock => stockQuantity <= 0;
  Department get department => departmentFor(category);
  bool get sellsByMeasure => isMeasuredUnit(unit);
  String get priceLabel => unit == 'each' ? money(price) : '${money(price)} / $unit';
  String get stockLabel => unit == 'each' ? formatQty(stockQuantity) : '${formatQty(stockQuantity)} $unit';

  /// True when every word of [query] appears in the name, SKU, barcode or
  /// department, so "tap 15" finds "Bib Tap Brass 15mm".
  bool matches(String query) {
    final haystack = '$name $id ${barcode ?? ''} $category'.toLowerCase();
    return query.toLowerCase().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).every(haystack.contains);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'category': category, 'unit': unit, 'stockQuantity': stockQuantity, 'reorderPoint': reorderPoint, 'reorderQuantity': reorderQuantity, 'supplierId': supplierId, 'barcode': barcode, 'lastRestocked': lastRestocked?.toIso8601String()};

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: (json['price'] as num).toDouble(),
    category: normalizeCategory(json['category']),
    unit: json['unit'] ?? 'each',
    stockQuantity: (json['stockQuantity'] as num?)?.toDouble() ?? 0.0,
    reorderPoint: (json['reorderPoint'] as num?)?.toDouble() ?? 5.0,
    reorderQuantity: (json['reorderQuantity'] as num?)?.toDouble() ?? 20.0,
    supplierId: json['supplierId'],
    barcode: json['barcode'],
    lastRestocked: json['lastRestocked'] != null ? DateTime.parse(json['lastRestocked']) : null,
  );
}

class CartItem {
  final Product product;
  double quantity;

  CartItem({required this.product, this.quantity = 1});
  double get totalPrice => product.price * quantity;
  String get qtyLabel => product.unit == 'each' ? formatQty(quantity) : '${formatQty(quantity)} ${product.unit}';

  Map<String, dynamic> toJson() => {'product': product.toJson(), 'quantity': quantity};
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(product: Product.fromJson(json['product']), quantity: (json['quantity'] as num).toDouble());
}

// Loyalty Tier Enum
enum LoyaltyTier {
  bronze('Bronze', 0, Colors.brown, 1.0),
  silver('Silver', 500, Colors.grey, 1.05),
  gold('Gold', 1500, Colors.yellow, 1.1),
  platinum('Platinum', 3000, Colors.blue, 1.15);

  final String displayName;
  final int minPoints;
  final Color color;
  final double pointMultiplier;

  const LoyaltyTier(this.displayName, this.minPoints, this.color, this.pointMultiplier);

  static LoyaltyTier fromPoints(int points) {
    if (points >= platinum.minPoints) return platinum;
    if (points >= gold.minPoints) return gold;
    if (points >= silver.minPoints) return silver;
    return bronze;
  }
}

class Customer {
  final String id;
  String name;
  String? businessName;
  String? phone;
  String? email;
  double totalSpent;
  double outstandingBalance;
  int loyaltyPoints;
  final DateTime createdAt;
  int visits;
  double? redeemedDiscount;

  Customer({required this.id, required this.name, this.businessName, this.phone, this.email, this.totalSpent = 0.0, this.outstandingBalance = 0.0, this.loyaltyPoints = 0, required this.createdAt, this.visits = 1, this.redeemedDiscount});

  LoyaltyTier get tier => LoyaltyTier.fromPoints(loyaltyPoints);
  int get pointsToNextTier {
    switch (tier) {
      case LoyaltyTier.bronze: return LoyaltyTier.silver.minPoints - loyaltyPoints;
      case LoyaltyTier.silver: return LoyaltyTier.gold.minPoints - loyaltyPoints;
      case LoyaltyTier.gold: return LoyaltyTier.platinum.minPoints - loyaltyPoints;
      case LoyaltyTier.platinum: return 0;
    }
  }
  double get discountPercentage => tier.pointMultiplier - 1.0;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'businessName': businessName, 'phone': phone, 'email': email, 'totalSpent': totalSpent, 'outstandingBalance': outstandingBalance, 'loyaltyPoints': loyaltyPoints, 'createdAt': createdAt.toIso8601String(), 'visits': visits, 'redeemedDiscount': redeemedDiscount};

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    name: json['name'],
    businessName: json['businessName'],
    phone: json['phone'],
    email: json['email'],
    totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
    outstandingBalance: (json['outstandingBalance'] as num?)?.toDouble() ?? 0.0,
    loyaltyPoints: json['loyaltyPoints'] ?? 0,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    visits: json['visits'] ?? 1,
    redeemedDiscount: (json['redeemedDiscount'] as num?)?.toDouble(),
  );
}

class Expense {
  final String id;
  String description;
  double amount;
  String category;
  final DateTime date;

  Expense({required this.id, required this.description, required this.amount, required this.category, required this.date});

  Map<String, dynamic> toJson() => {'id': id, 'description': description, 'amount': amount, 'category': category, 'date': date.toIso8601String()};
  
  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'], 
    description: json['description'], 
    amount: (json['amount'] as num).toDouble(), 
    category: json['category'], 
    date: DateTime.parse(json['date'])
  );
}

class OrderTransaction {
  final String id;
  final DateTime date;
  final double total;
  final double subtotal;
  final double discount;
  final double vat;
  final List<CartItem> items;
  final bool includesVat;
  String paymentStatus;
  String paymentMethod;
  String? customerId; 
  String? customerName;
  String? businessName;
  String? notes;

  OrderTransaction({
    required this.id, required this.date, required this.total, required this.subtotal, this.discount = 0.0, required this.vat, required this.items, this.includesVat = true, this.paymentStatus = 'Paid', this.paymentMethod = 'Cash', this.customerId, this.customerName, this.businessName, this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'total': total, 'subtotal': subtotal, 'discount': discount, 'vat': vat, 'items': items.map((i) => i.toJson()).toList(), 'includesVat': includesVat, 'paymentStatus': paymentStatus, 'paymentMethod': paymentMethod, 'customerId': customerId, 'customerName': customerName, 'businessName': businessName, 'notes': notes,
  };

  factory OrderTransaction.fromJson(Map<String, dynamic> json) => OrderTransaction(
    id: json['id'],
    date: DateTime.parse(json['date']),
    total: (json['total'] as num).toDouble(),
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? ((json['total'] as num) / 1.15).toDouble(),
    discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    vat: (json['vat'] as num?)?.toDouble() ?? ((json['total'] as num) - ((json['total'] as num) / 1.15)).toDouble(),
    items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
    includesVat: json['includesVat'] ?? true,
    paymentStatus: json['paymentStatus'] ?? 'Paid',
    paymentMethod: json['paymentMethod'] ?? 'Cash',
    customerId: json['customerId'],
    customerName: json['customerName'],
    businessName: json['businessName'],
    notes: json['notes'],
  );
}

// Supplier Model
class Supplier {
  final String id;
  String name;
  String? contactPerson;
  String? phone;
  String? email;
  String? address;
  String? notes;
  final DateTime createdAt;

  Supplier({required this.id, required this.name, this.contactPerson, this.phone, this.email, this.address, this.notes, required this.createdAt});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'contactPerson': contactPerson, 'phone': phone, 'email': email, 'address': address, 'notes': notes, 'createdAt': createdAt.toIso8601String()};

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'],
    name: json['name'],
    contactPerson: json['contactPerson'],
    phone: json['phone'],
    email: json['email'],
    address: json['address'],
    notes: json['notes'],
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
  );
}

// Refund Model
class Refund {
  final String id;
  final String originalTransactionId;
  final DateTime date;
  final double amount;
  final String reason;
  final List<CartItem> items;
  final String? customerId;
  final String? customerName;
  String status; // 'Pending', 'Approved', 'Rejected', 'Processed'

  Refund({required this.id, required this.originalTransactionId, required this.date, required this.amount, required this.reason, required this.items, this.customerId, this.customerName, this.status = 'Pending'});

  Map<String, dynamic> toJson() => {'id': id, 'originalTransactionId': originalTransactionId, 'date': date.toIso8601String(), 'amount': amount, 'reason': reason, 'items': items.map((i) => i.toJson()).toList(), 'customerId': customerId, 'customerName': customerName, 'status': status};

  factory Refund.fromJson(Map<String, dynamic> json) => Refund(
    id: json['id'],
    originalTransactionId: json['originalTransactionId'],
    date: DateTime.parse(json['date']),
    amount: (json['amount'] as num).toDouble(),
    reason: json['reason'],
    items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
    customerId: json['customerId'],
    customerName: json['customerName'],
    status: json['status'] ?? 'Pending',
  );
}

// Quote Model
class Quote {
  final String id;
  final DateTime date;
  final DateTime? validUntil;
  final double total;
  final double subtotal;
  final double discount;
  final double vat;
  final List<CartItem> items;
  final bool includesVat;
  String status; // 'Draft', 'Sent', 'Accepted', 'Rejected', 'Expired', 'Converted'
  final String? customerId;
  final String? customerName;
  final String? businessName;
  String? notes;
  String? convertedToTransactionId;

  Quote({
    required this.id,
    required this.date,
    this.validUntil,
    required this.total,
    required this.subtotal,
    this.discount = 0.0,
    required this.vat,
    required this.items,
    this.includesVat = true,
    this.status = 'Draft',
    this.customerId,
    this.customerName,
    this.businessName,
    this.notes,
    this.convertedToTransactionId,
  });

  bool get isExpired => validUntil != null && DateTime.now().isAfter(validUntil!);
  bool get canConvert => status == 'Accepted' && !isExpired && convertedToTransactionId == null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'validUntil': validUntil?.toIso8601String(),
    'total': total,
    'subtotal': subtotal,
    'discount': discount,
    'vat': vat,
    'items': items.map((i) => i.toJson()).toList(),
    'includesVat': includesVat,
    'status': status,
    'customerId': customerId,
    'customerName': customerName,
    'businessName': businessName,
    'notes': notes,
    'convertedToTransactionId': convertedToTransactionId,
  };

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    id: json['id'],
    date: DateTime.parse(json['date']),
    validUntil: json['validUntil'] != null ? DateTime.parse(json['validUntil']) : null,
    total: (json['total'] as num).toDouble(),
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? ((json['total'] as num) / 1.15).toDouble(),
    discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    vat: (json['vat'] as num?)?.toDouble() ?? ((json['total'] as num) - ((json['total'] as num) / 1.15)).toDouble(),
    items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
    includesVat: json['includesVat'] ?? true,
    status: json['status'] ?? 'Draft',
    customerId: json['customerId'],
    customerName: json['customerName'],
    businessName: json['businessName'],
    notes: json['notes'],
    convertedToTransactionId: json['convertedToTransactionId'],
  );
}

// User Model
class User {
  final String id;
  String username;
  String? fullName;
  String role; // 'Admin', 'Manager', 'Cashier'
  String? email;
  String? phone;
  bool isActive;
  final DateTime createdAt;
  DateTime? lastLogin;

  User({
    required this.id,
    required this.username,
    this.fullName,
    this.role = 'Cashier',
    this.email,
    this.phone,
    this.isActive = true,
    required this.createdAt,
    this.lastLogin,
  });

  bool get isAdmin => role == 'Admin';
  bool get isManager => role == 'Manager' || isAdmin;
  bool get canManageInventory => isManager;
  bool get canManageUsers => isAdmin;
  bool get canViewReports => isManager;
  bool get canProcessRefunds => isManager;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'role': role,
    'email': email,
    'phone': phone,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'lastLogin': lastLogin?.toIso8601String(),
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    username: json['username'],
    fullName: json['fullName'],
    role: json['role'] ?? 'Cashier',
    email: json['email'],
    phone: json['phone'],
    isActive: json['isActive'] ?? true,
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
  );
}

// Stock Adjustment Model
class StockAdjustment {
  final String id;
  final String productId;
  final String productName;
  final double previousQuantity;
  final double newQuantity;
  final double adjustment;
  final String reason; // 'Sale', 'Restock', 'Damage', 'Loss', 'Correction', 'Return'
  final String? referenceId; // Transaction ID, Refund ID, etc.
  final DateTime date;
  final String? performedBy;

  StockAdjustment({
    required this.id,
    required this.productId,
    required this.productName,
    required this.previousQuantity,
    required this.newQuantity,
    required this.adjustment,
    required this.reason,
    this.referenceId,
    required this.date,
    this.performedBy,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'previousQuantity': previousQuantity,
    'newQuantity': newQuantity,
    'adjustment': adjustment,
    'reason': reason,
    'referenceId': referenceId,
    'date': date.toIso8601String(),
    'performedBy': performedBy,
  };

  factory StockAdjustment.fromJson(Map<String, dynamic> json) => StockAdjustment(
    id: json['id'],
    productId: json['productId'],
    productName: json['productName'],
    previousQuantity: (json['previousQuantity'] as num).toDouble(),
    newQuantity: (json['newQuantity'] as num).toDouble(),
    adjustment: (json['adjustment'] as num).toDouble(),
    reason: json['reason'],
    referenceId: json['referenceId'],
    date: DateTime.parse(json['date']),
    performedBy: json['performedBy'],
  );
}