import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  double price; 
  final String category;
  final Color color;
  final IconData icon;

  Product({required this.id, required this.name, required this.price, required this.category, required this.color, required this.icon});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'category': category, 'color': color.value};
  
  // FIXED: Safely parse numbers to double so it doesn't crash on app restart
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'], 
    name: json['name'], 
    price: (json['price'] as num).toDouble(), 
    category: json['category'], 
    color: Color(json['color']), 
    icon: Icons.local_offer
  );
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toJson() => {'product': product.toJson(), 'quantity': quantity};
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(product: Product.fromJson(json['product']), quantity: json['quantity']);
}

class Customer {
  final String id;
  String name;
  String? businessName;
  String? phone;
  String? email;
  double totalSpent;
  double outstandingBalance;
  final DateTime createdAt;

  Customer({required this.id, required this.name, this.businessName, this.phone, this.email, this.totalSpent = 0.0, this.outstandingBalance = 0.0, required this.createdAt});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'businessName': businessName, 'phone': phone, 'email': email, 'totalSpent': totalSpent, 'outstandingBalance': outstandingBalance, 'createdAt': createdAt.toIso8601String()};
  
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'], 
    name: json['name'], 
    businessName: json['businessName'], 
    phone: json['phone'], 
    email: json['email'], 
    totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0, 
    outstandingBalance: (json['outstandingBalance'] as num?)?.toDouble() ?? 0.0, 
    createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()
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
  String? customerId; 
  String? customerName;
  String? businessName;

  OrderTransaction({
    required this.id, required this.date, required this.total, required this.subtotal, this.discount = 0.0, required this.vat, required this.items, this.includesVat = true, this.paymentStatus = 'Paid', this.customerId, this.customerName, this.businessName,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'total': total, 'subtotal': subtotal, 'discount': discount, 'vat': vat, 'items': items.map((i) => i.toJson()).toList(), 'includesVat': includesVat, 'paymentStatus': paymentStatus, 'customerId': customerId, 'customerName': customerName, 'businessName': businessName,
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
    customerId: json['customerId'], 
    customerName: json['customerName'], 
    businessName: json['businessName'],
  );
}