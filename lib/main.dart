import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SolumatePosApp());
}

// --- DATA MODELS ---

class Product {
  final String id;
  final String name;
  double price; // Made non-final so it can be edited
  final String category;
  final Color color;
  final IconData icon;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'color': color.value,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    category: json['category'],
    color: Color(json['color']),
    icon: Icons.water_drop, // Fallback, we'll re-map from ID below if needed
  );
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    product: Product.fromJson(json['product']),
    quantity: json['quantity'],
  );
}

class OrderTransaction {
  final String id;
  final DateTime date;
  final double total;
  final double subtotal;
  final double vat;
  final List<CartItem> items;
  final bool includesVat;
  String paymentStatus; // 'Paid' or 'Awaiting Payment'
  String? customerName;
  String? businessName;

  OrderTransaction({
    required this.id,
    required this.date,
    required this.total,
    required this.subtotal,
    required this.vat,
    required this.items,
    this.includesVat = true,
    this.paymentStatus = 'Paid',
    this.customerName,
    this.businessName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'total': total,
    'subtotal': subtotal,
    'vat': vat,
    'items': items.map((i) => i.toJson()).toList(),
    'includesVat': includesVat,
    'paymentStatus': paymentStatus,
    'customerName': customerName,
    'businessName': businessName,
  };

  factory OrderTransaction.fromJson(Map<String, dynamic> json) => OrderTransaction(
    id: json['id'],
    date: DateTime.parse(json['date']),
    total: json['total'],
    subtotal: json['subtotal'] ?? (json['total'] / 1.15), // Fallback for old data
    vat: json['vat'] ?? (json['total'] - (json['total'] / 1.15)),
    items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
    includesVat: json['includesVat'] ?? true,
    paymentStatus: json['paymentStatus'] ?? 'Paid',
    customerName: json['customerName'],
    businessName: json['businessName'],
  );
}

// --- MAIN APP ---

class SolumatePosApp extends StatelessWidget {
  const SolumatePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solumate Business OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF4F46E5), // Indigo 600
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        fontFamily: 'Roboto',
      ),
      home: const PosScreen(),
    );
  }
}

// --- POS SCREEN (UI & LOGIC) ---

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<CartItem> _cart = [];
  final List<OrderTransaction> _history = [];
  
  String _selectedCategory = 'All';
  int _currentMenuIndex = 1; // Default to POS tab
  bool _applyVat = true;

  final List<String> _categories = ['All', 'Thinners', 'Oils', 'Spirits'];

  // Master Inventory
  late List<Product> _inventory;

  @override
  void initState() {
    super.initState();
    _initializeInventory();
    _loadHistoryFromDatabase();
  }

  void _initializeInventory() {
    _inventory = [
      Product(id: 'LCQ-750', name: '"A" Grade Lacquer (750ml)', price: 20.50, category: 'Thinners', color: Colors.blueGrey, icon: Icons.water_drop),
      Product(id: 'LCQ-750-C', name: 'Lacquer (750ml) - Case', price: 512.50, category: 'Thinners', color: Colors.indigo, icon: Icons.inventory_2),
      Product(id: 'LCQ-005', name: '"A" Grade Lacquer (5L)', price: 119.00, category: 'Thinners', color: Colors.blueGrey, icon: Icons.science),
      Product(id: 'ENM-750', name: 'QD Enamel Thinner (750ml)', price: 22.00, category: 'Thinners', color: Colors.teal, icon: Icons.water_drop),
      Product(id: 'ENM-750-C', name: 'Enamel (750ml) - Case', price: 550.00, category: 'Thinners', color: Colors.teal.shade700, icon: Icons.inventory_2),
      Product(id: 'TRP-750', name: 'Mineral Turpentine (750ml)', price: 25.00, category: 'Thinners', color: Colors.cyan, icon: Icons.water_drop),
      Product(id: 'TRP-750-C', name: 'Turpentine (750ml) - Case', price: 625.00, category: 'Thinners', color: Colors.cyan.shade700, icon: Icons.inventory_2),
      Product(id: 'LIN-OIL', name: 'Raw Linseed Oil (750ml)', price: 46.00, category: 'Oils', color: Colors.amber.shade700, icon: Icons.water_drop),
      Product(id: 'LIN-OIL-C', name: 'Linseed Oil (750ml) - Case', price: 1150.00, category: 'Oils', color: Colors.amber.shade900, icon: Icons.inventory_2),
      Product(id: 'MET-750', name: 'Methylated Spirits (750ml)', price: 28.00, category: 'Spirits', color: Colors.purple.shade400, icon: Icons.science),
      Product(id: 'MET-750-C', name: 'Meths (750ml) - Case', price: 700.00, category: 'Spirits', color: Colors.purple.shade700, icon: Icons.inventory_2),
    ];
  }

  // --- DATABASE LOGIC ---
  Future<void> _loadHistoryFromDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyData = prefs.getString('solumate_tx_history');
      if (historyData != null) {
        final List<dynamic> decoded = jsonDecode(historyData);
        setState(() {
          _history.clear();
          _history.addAll(decoded.map((item) => OrderTransaction.fromJson(item)).toList());
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _saveHistoryToDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_history.map((tx) => tx.toJson()).toList());
      await prefs.setString('solumate_tx_history', encoded);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  // --- POS LOGIC ---
  void _addToCart(Product product) {
    setState(() {
      var existingItem = _cart.where((item) => item.product.id == product.id).firstOrNull;
      if (existingItem != null) {
        existingItem.quantity++;
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  void _updateQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) {
        _cart.remove(item);
      }
    });
  }

  Future<void> _editQuantityDialog(CartItem item) async {
    TextEditingController controller = TextEditingController(text: item.quantity.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Quantity'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              int? newQty = int.tryParse(controller.text);
              if (newQty != null && newQty > 0) {
                setState(() { item.quantity = newQty; });
              } else if (newQty != null && newQty <= 0) {
                setState(() { _cart.remove(item); });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPriceDialog(Product product) async {
    TextEditingController controller = TextEditingController(text: product.price.toStringAsFixed(2));
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price: ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'New Price (R)', prefixText: 'R '),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              double? newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                setState(() {
                  product.price = newPrice;
                  for (var item in _cart) {
                    if (item.product.id == product.id) {
                      item.product.price = newPrice;
                    }
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _applyVat = true;
    });
  }

  double get _subTotal => _cart.fold(0, (total, item) => total + item.totalPrice);
  double get _vatAmount => _applyVat ? _subTotal * 0.15 : 0.0;
  double get _grandTotal => _subTotal + _vatAmount;

  Future<void> _showCheckoutDialog() async {
    if (_cart.isEmpty) return;

    TextEditingController customerNameCtrl = TextEditingController();
    TextEditingController businessNameCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Checkout Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: customerNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Customer Name (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: businessNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Business Name (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount Due:', style: TextStyle(fontSize: 16)),
                    Text('R ${_grandTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizeOrder('Awaiting Payment', customerNameCtrl.text, businessNameCtrl.text);
            },
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700, side: BorderSide(color: Colors.orange.shade300)),
            child: const Text('Awaiting Payment'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalizeOrder('Paid', customerNameCtrl.text, businessNameCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            child: const Text('Mark as Paid'),
          ),
        ],
      )
    );
  }

  void _finalizeOrder(String status, String custName, String bizName) {
    final newTransaction = OrderTransaction(
      id: 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      date: DateTime.now(),
      subtotal: _subTotal,
      vat: _vatAmount,
      total: _grandTotal,
      items: List.from(_cart),
      includesVat: _applyVat,
      paymentStatus: status,
      customerName: custName.trim().isNotEmpty ? custName.trim() : null,
      businessName: bizName.trim().isNotEmpty ? bizName.trim() : null,
    );

    setState(() {
      _history.insert(0, newTransaction);
    });
    _saveHistoryToDatabase();

    _showSuccessDialog(newTransaction);
  }

  void _showSuccessDialog(OrderTransaction tx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              tx.paymentStatus == 'Paid' ? Icons.check_circle : Icons.schedule, 
              color: tx.paymentStatus == 'Paid' ? Colors.green : Colors.orange, 
              size: 32
            ),
            const SizedBox(width: 10),
            Text(tx.paymentStatus == 'Paid' ? 'Payment Successful' : 'Order Saved'),
          ],
        ),
        content: Text(
          'Order #${tx.id}\nStatus: ${tx.paymentStatus}\nTotal: R ${tx.total.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(tx);
              _clearCart();
            },
            child: const Text('Thermal Receipt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _printInvoice(tx);
              _clearCart();
            },
            child: const Text('A4 Invoice'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _clearCart();
            },
            child: const Text('New Sale', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(OrderTransaction tx) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to permanently delete order #${tx.id}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _history.removeWhere((item) => item.id == tx.id);
      });
      _saveHistoryToDatabase();
    }
  }

  // --- PRINTING LOGIC ---
  Future<void> _printReceipt(OrderTransaction tx) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('SOLUMATE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('Industrial Supplies')),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('Order: #${tx.id}'),
              pw.Text('Date: ${tx.date.day}/${tx.date.month}/${tx.date.year} ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}'),
              if (tx.customerName != null) pw.Text('Customer: ${tx.customerName}'),
              if (tx.businessName != null) pw.Text('Business: ${tx.businessName}'),
              pw.Divider(),
              ...tx.items.map((item) => pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Text('${item.quantity}x ${item.product.name}', style: const pw.TextStyle(fontSize: 10))),
                  pw.Text('R ${item.totalPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                ],
              )),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:'), pw.Text('R ${tx.subtotal.toStringAsFixed(2)}')]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VAT (${tx.includesVat ? "15%" : "Exempt"}):'), pw.Text('R ${tx.vat.toStringAsFixed(2)}')]),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('R ${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('STATUS', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(tx.paymentStatus.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('*** CUSTOMER COPY ***', style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Receipt_${tx.id}');
  }

  Future<void> _printInvoice(OrderTransaction tx) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SOLUMATE', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: const PdfColor(0.2, 0.2, 0.6))),
                        pw.Text('Industrial Supplies', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                        pw.Text('Krugersdorp, Gauteng', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey400)),
                        pw.SizedBox(height: 8),
                        pw.Text('Invoice #: ${tx.id}', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Date: ${tx.date.day}/${tx.date.month}/${tx.date.year}', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Status: ${tx.paymentStatus}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tx.paymentStatus == 'Paid' ? PdfColors.green700 : PdfColors.orange700)),
                      ]
                    )
                  ]
                ),
                pw.SizedBox(height: 40),
                
                // Billed To Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILLED TO:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(tx.customerName ?? 'Cash Customer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (tx.businessName != null) pw.Text(tx.businessName!, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      if (tx.businessName == null && tx.customerName == null) pw.Text('Walk-in Client', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  )
                ),
                pw.SizedBox(height: 20),

                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Unit Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ]
                  )
                ),
                pw.SizedBox(height: 8),
                // Items
                ...tx.items.map((item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item.product.name)),
                      pw.Expanded(flex: 1, child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: pw.Text('R ${item.product.price.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 2, child: pw.Text('R ${item.totalPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
                    ]
                  )
                )),
                pw.SizedBox(height: 20),
                // Totals Area
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 250,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                      child: pw.Column(
                        children: [
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:'), pw.Text('R ${tx.subtotal.toStringAsFixed(2)}')]),
                          pw.SizedBox(height: 4),
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VAT (${tx.includesVat ? "15%" : "Exempt"}):'), pw.Text('R ${tx.vat.toStringAsFixed(2)}')]),
                          pw.Divider(color: PdfColors.grey400),
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text('Grand Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)), 
                            pw.Text('R ${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: const PdfColor(0.2, 0.2, 0.6)))
                          ]),
                        ]
                      )
                    )
                  ]
                )
              ]
            )
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Invoice_${tx.id}');
  }

  // --- MAIN LAYOUT ---
  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(child: _buildCurrentView(isDesktop)),
          if (isDesktop && _currentMenuIndex == 1) _buildCartPanel(), // Cart on right for POS
        ],
      ),
      bottomNavigationBar: !isDesktop
          ? BottomNavigationBar(
              currentIndex: _currentMenuIndex,
              onTap: (index) => setState(() => _currentMenuIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).primaryColor,
              unselectedItemColor: Colors.grey.shade500,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'POS'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Inventory'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Ledger'),
              ],
            )
          : null,
      floatingActionButton: (!isDesktop && _cart.isNotEmpty && _currentMenuIndex == 1)
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    child: _buildCartPanel()
                  ),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text('R ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // --- VIEWS ---
  Widget _buildCurrentView(bool isDesktop) {
    switch (_currentMenuIndex) {
      case 0: return _buildDashboardView(isDesktop);
      case 2: return _buildInventoryView();
      case 3: return _buildLedgerView();
      case 1:
      default: return _buildPosView(isDesktop);
    }
  }

  Widget _buildDashboardView(bool isDesktop) {
    double totalRev = _history.fold(0, (sum, tx) => sum + tx.subtotal); // Dashboard usually shows Excl VAT
    double aov = _history.isEmpty ? 0 : totalRev / _history.length;

    // --- Data Aggregation for Custom Charts ---
    Map<String, double> revByDay = {};
    Map<String, double> revByCategory = {'Thinners': 0, 'Oils': 0, 'Spirits': 0};
    
    // Seed last 7 days to ensure empty days show up
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime d = now.subtract(Duration(days: i));
      String dayLabel = '${d.day}/${d.month}';
      revByDay[dayLabel] = 0;
    }

    for (var tx in _history) {
      // Day aggregation
      String dayLabel = '${tx.date.day}/${tx.date.month}';
      if (revByDay.containsKey(dayLabel)) {
        revByDay[dayLabel] = revByDay[dayLabel]! + tx.subtotal;
      }
      // Category aggregation
      for (var item in tx.items) {
        String cat = item.product.category;
        if (revByCategory.containsKey(cat)) {
          revByCategory[cat] = revByCategory[cat]! + (item.product.price * item.quantity);
        }
      }
    }

    return SingleChildScrollView(
      child: Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('High-level overview and custom visual analytics.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            
            // Responsive KPI Cards
            if (isDesktop)
              Row(
                children: [
                  Expanded(child: _buildKpiCard('Total Revenue (Ex VAT)', 'R ${totalRev.toStringAsFixed(2)}', Icons.payments, Colors.teal)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('Total Orders', '${_history.length}', Icons.shopping_cart, Colors.indigo)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('Average Order Value', 'R ${aov.toStringAsFixed(2)}', Icons.trending_up, Colors.amber)),
                ],
              )
            else
              Column(
                children: [
                  _buildKpiCard('Total Revenue (Ex VAT)', 'R ${totalRev.toStringAsFixed(2)}', Icons.payments, Colors.teal),
                  const SizedBox(height: 12),
                  _buildKpiCard('Total Orders', '${_history.length}', Icons.shopping_cart, Colors.indigo),
                  const SizedBox(height: 12),
                  _buildKpiCard('Average Order Value', 'R ${aov.toStringAsFixed(2)}', Icons.trending_up, Colors.amber),
                ],
              ),
            
            const SizedBox(height: 32),
            
            // Responsive Detailed Custom Charts
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildRevenueBarChart(revByDay)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildCategorySalesChart(revByCategory, totalRev)),
                ],
              )
            else
              Column(
                children: [
                  _buildRevenueBarChart(revByDay),
                  const SizedBox(height: 24),
                  _buildCategorySalesChart(revByCategory, totalRev),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Custom Bar Chart built with native Flutter widgets
  Widget _buildRevenueBarChart(Map<String, double> revByDay) {
    double maxRev = revByDay.values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxRev == 0) maxRev = 1; // Prevent division by zero

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Trend (Last 7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: revByDay.entries.map((e) {
                double heightPct = e.value / maxRev;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (e.value > 0) 
                      Text(e.value >= 1000 ? '${(e.value/1000).toStringAsFixed(1)}k' : e.value.toStringAsFixed(0), 
                           style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      width: 28,
                      height: 150 * heightPct,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(e.key, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Custom Progress Bar Distribution built with native Flutter widgets
  Widget _buildCategorySalesChart(Map<String, double> catData, double totalRev) {
    if (totalRev == 0) totalRev = 1; // Prevent division by zero
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 24),
          ...catData.entries.map((e) {
            double pct = e.value / totalRev;
            Color barColor = e.key == 'Thinners' ? Colors.teal : (e.key == 'Oils' ? Colors.amber.shade500 : Colors.purple.shade400);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('R ${e.value.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, MaterialColor color) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color.shade600, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosView(bool isDesktop) {
    List<Product> displayedProducts = _selectedCategory == 'All' ? _inventory : _inventory.where((p) => p.category == _selectedCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Point of Sale', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    bool isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: isSelected,
                        selectedColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
                        onSelected: (_) => setState(() => _selectedCategory = category),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              childAspectRatio: isDesktop ? 0.9 : 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: displayedProducts.length,
            itemBuilder: (context, index) {
              final product = displayedProducts[index];
              return InkWell(
                onTap: () => _addToCart(product),
                borderRadius: BorderRadius.circular(16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: product.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(product.icon, color: product.color, size: 32),
                        ),
                        const Spacer(),
                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Text('R ${product.price.toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryView() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inventory Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                Text('Tap the edit icon next to any price to update it.', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final p = _inventory[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(backgroundColor: p.color.withOpacity(0.1), child: Icon(p.icon, color: p.color)),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${p.id}  •  ${p.category}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('R ${p.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.grey.shade400, size: 20),
                          onPressed: () => _editPriceDialog(p),
                          tooltip: 'Edit Price',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerView() {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            child: const Text('Transaction Ledger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ),
          Expanded(
            child: _history.isEmpty
                ? Center(child: Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 1.35,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final tx = _history[index];
                      int itemCount = tx.items.fold(0, (sum, item) => sum + item.quantity);
                      
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                                        child: Text(tx.id, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: tx.paymentStatus == 'Paid' ? Colors.green.shade50 : Colors.orange.shade50, 
                                          borderRadius: BorderRadius.circular(6)
                                        ),
                                        child: Text(
                                          tx.paymentStatus.toUpperCase(), 
                                          style: TextStyle(color: tx.paymentStatus == 'Paid' ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 10)
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('R ${tx.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                                        onPressed: () => _deleteTransaction(tx),
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete Transaction',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('${tx.date.day}/${tx.date.month}/${tx.date.year} at ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              
                              if (tx.customerName != null || tx.businessName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('${tx.customerName ?? ''} ${tx.businessName != null ? '(${tx.businessName})' : ''}', style: TextStyle(color: Colors.indigo.shade400, fontSize: 13, fontWeight: FontWeight.w500)),
                                ),

                              const SizedBox(height: 4),
                              Text('$itemCount items • VAT: ${tx.includesVat ? "Included" : "Exempt"}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              const Spacer(),
                              Row(
                                children: [
                                  if (tx.paymentStatus == 'Awaiting Payment')
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check, size: 16),
                                          label: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade700, elevation: 0),
                                          onPressed: () {
                                            setState(() { tx.paymentStatus = 'Paid'; });
                                            _saveHistoryToDatabase();
                                          },
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    flex: 1,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, side: BorderSide(color: Colors.grey.shade300), padding: EdgeInsets.zero),
                                      onPressed: () => _printReceipt(tx),
                                      child: const Icon(Icons.receipt_long, size: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.print, size: 16),
                                      label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEEF2FF), foregroundColor: const Color(0xFF4F46E5), elevation: 0),
                                      onPressed: () => _printInvoice(tx),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE COMPONENTS ---
  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                const Text('Solumate.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSidebarItem(Icons.bar_chart, 'Dashboard', 0),
          _buildSidebarItem(Icons.point_of_sale, 'Point of Sale', 1),
          _buildSidebarItem(Icons.inventory_2, 'Inventory', 2),
          _buildSidebarItem(Icons.receipt_long, 'Transaction Ledger', 3),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey.shade200, child: Text('MW', style: TextStyle(color: Colors.grey.shade700))),
            title: const Text('M. Wajah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Administrator', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int index) {
    bool isActive = _currentMenuIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _currentMenuIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEEF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade500, size: 24),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(color: isActive ? const Color(0xFF4F46E5) : Colors.grey.shade600, fontWeight: isActive ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100)), color: const Color(0xFFF8FAFC)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Order', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                if (_cart.isNotEmpty)
                  TextButton(onPressed: _clearCart, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Clear')),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No items added yet', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                                const SizedBox(height: 4),
                                Text('R ${item.product.price.toStringAsFixed(2)} each', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: const Color(0xFFF8FAFC)),
                            child: Row(
                              children: [
                                InkWell(onTap: () => _updateQuantity(item, -1), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.remove, size: 16))),
                                InkWell(
                                  onTap: () => _editQuantityDialog(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                                InkWell(onTap: () => _updateQuantity(item, 1), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.add, size: 16))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
                            child: Text('R ${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.right),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200)), color: const Color(0xFFF8FAFC)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Apply VAT (15%)', style: TextStyle(fontWeight: FontWeight.w500)),
                    Switch(
                      value: _applyVat,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (val) => setState(() => _applyVat = val),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Subtotal', style: TextStyle(color: Colors.grey.shade600)), Text('R ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                if (_applyVat) const SizedBox(height: 8),
                if (_applyVat) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('VAT', style: TextStyle(color: Colors.grey.shade600)), Text('R ${_vatAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(height: 1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    Text('R ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5))),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _cart.isEmpty ? null : _showCheckoutDialog,
                    child: const Text('Checkout', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}