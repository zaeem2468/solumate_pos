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
  final double price;
  final String category;
  final Color color;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.color,
  });

  // Convert to JSON for database storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'category': category,
    'color': color.value,
  };

  // Create from JSON when loading from database
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    price: json['price'],
    category: json['category'],
    color: Color(json['color']),
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
  final List<CartItem> items;
  final bool includesVat;

  OrderTransaction({
    required this.id,
    required this.date,
    required this.total,
    required this.items,
    this.includesVat = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'total': total,
    'items': items.map((i) => i.toJson()).toList(),
    'includesVat': includesVat,
  };

  factory OrderTransaction.fromJson(Map<String, dynamic> json) => OrderTransaction(
    id: json['id'],
    date: DateTime.parse(json['date']),
    total: json['total'],
    items: (json['items'] as List).map((i) => CartItem.fromJson(i)).toList(),
    includesVat: json['includesVat'] ?? true,
  );
}

// --- MOCK INVENTORY ---

final List<Product> inventory = [
  // Thinners
  Product(id: 'LCQ-750', name: '"A" Grade Lacquer (750ml)', price: 20.50, category: 'Thinners', color: Colors.blueGrey),
  Product(id: 'LCQ-750-C', name: '"A" Grade Lacquer (750ml) - Case of 25', price: 512.50, category: 'Thinners', color: Colors.blueGrey),
  Product(id: 'LCQ-005', name: '"A" Grade Lacquer (5L)', price: 119.00, category: 'Thinners', color: Colors.blueGrey),
  
  Product(id: 'ENM-750', name: 'QD Enamel Thinner (750ml)', price: 22.00, category: 'Thinners', color: Colors.indigo),
  Product(id: 'ENM-750-C', name: 'QD Enamel Thinner (750ml) - Case of 25', price: 550.00, category: 'Thinners', color: Colors.indigo),
  Product(id: 'ENM-005', name: 'QD Enamel Thinner (5L)', price: 120.00, category: 'Thinners', color: Colors.indigo),
  
  Product(id: 'TRP-750', name: 'Mineral Turpentine (750ml)', price: 25.00, category: 'Thinners', color: Colors.teal),
  Product(id: 'TRP-750-C', name: 'Mineral Turpentine (750ml) - Case of 25', price: 625.00, category: 'Thinners', color: Colors.teal),
  Product(id: 'TRP-005', name: 'Mineral Turpentine (5L)', price: 125.00, category: 'Thinners', color: Colors.teal),
  
  // Oils
  Product(id: 'LIN-OIL', name: 'Raw Linseed Oil (750ml)', price: 46.00, category: 'Oils', color: Colors.amber.shade700),
  Product(id: 'LIN-OIL-C', name: 'Raw Linseed Oil (750ml) - Case of 25', price: 1150.00, category: 'Oils', color: Colors.amber.shade700),
  
  // Spirits
  Product(id: 'MET-750', name: 'Methylated Spirits (750ml)', price: 28.00, category: 'Spirits', color: Colors.purple.shade400),
  Product(id: 'MET-750-C', name: 'Methylated Spirits (750ml) - Case of 25', price: 700.00, category: 'Spirits', color: Colors.purple.shade400),
  Product(id: 'MET-330', name: 'Methylated Spirits (330ml)', price: 15.00, category: 'Spirits', color: Colors.purple.shade400),
];

// --- MAIN APP ---

class SolumatePosApp extends StatelessWidget {
  const SolumatePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solumate POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFD32F2F), // Solumate Red
        scaffoldBackgroundColor: const Color(0xFFF4F6F8), // Light grey background
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFFD32F2F),
          secondary: const Color(0xFF1E1E2D),
        ),
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
  final List<OrderTransaction> _history = []; // History State
  
  String _selectedCategory = 'All';
  int _currentMenuIndex = 0; // Navigation State: 0=POS, 1=History, 2=Stock, 3=Settings
  bool _applyVat = true; // VAT Toggle State

  final List<String> _categories = ['All', 'Thinners', 'Oils', 'Spirits'];

  @override
  void initState() {
    super.initState();
    _loadHistoryFromDatabase(); // Load saved data when app starts
  }

  // Logic: Load from Local Database
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

  // Logic: Save to Local Database
  Future<void> _saveHistoryToDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_history.map((tx) => tx.toJson()).toList());
      await prefs.setString('solumate_tx_history', encoded);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  // Logic: Add item to cart
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

  // Logic: Adjust quantity
  void _updateQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) {
        _cart.remove(item);
      }
    });
  }

  // Logic: Clear Cart
  void _clearCart() {
    setState(() {
      _cart.clear();
      _applyVat = true; // Reset VAT toggle on clear
    });
  }

  // Logic: Financials
  double get _subTotal => _cart.fold(0, (total, item) => total + item.totalPrice);
  double get _vatAmount => _applyVat ? _subTotal * 0.15 : 0.0; // 15% VAT for South Africa
  double get _grandTotal => _subTotal + _vatAmount;

  // Logic: Real Printer Integration
  Future<void> _printReceipt(OrderTransaction tx) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Optimized for 80mm thermal receipt printers
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'SOLUMATE',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Center(child: pw.Text('Industrial Supplies')),
              pw.Center(child: pw.Text('Krugersdorp, South Africa')),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('Order: #${tx.id}'),
              pw.Text('Date: ${tx.date.day}/${tx.date.month}/${tx.date.year} ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}'),
              pw.Divider(),
              ...tx.items.map((item) => pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item.quantity}x ${item.product.name}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Text(
                    'R ${item.totalPrice.toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              )),
              pw.Divider(),
              if (tx.includesVat) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:'),
                    pw.Text('R ${(tx.total / 1.15).toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('VAT (15%):'),
                    pw.Text('R ${(tx.total - (tx.total / 1.15)).toStringAsFixed(2)}'),
                  ],
                ),
                pw.Divider(),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('R ${tx.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 10))),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    // This pops up the native print dialog allowing them to select their thermal printer
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_${tx.id}',
    );
  }

  // Logic: Checkout
  void _checkout() {
    if (_cart.isEmpty) return;

    // Save transaction to history
    final newTransaction = OrderTransaction(
      id: 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      date: DateTime.now(),
      total: _grandTotal,
      items: List.from(_cart), // Store a copy of the cart
      includesVat: _applyVat,
    );

    setState(() {
      _history.insert(0, newTransaction); // Add to the top of the history list
    });
    
    _saveHistoryToDatabase(); // Permanently save to hard drive

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 10),
            Text('Payment Successful'),
          ],
        ),
        content: Text(
          'Order #${newTransaction.id}\nTotal paid: R ${_grandTotal.toStringAsFixed(2)}\n${_applyVat ? 'Includes 15% VAT.' : 'Zero-rated (No VAT).'}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Print Receipt'),
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(newTransaction);
              _clearCart();
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _clearCart();
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Text('Start New Sale', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      // The AppBar is now shown on ALL devices to provide the hamburger menu button universally
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2D),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          ['Point of Sale', 'History', 'Stock', 'Settings'][_currentMenuIndex],
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      
      // The Drawer is now the universal navigation method
      drawer: Drawer(width: 100, child: _buildSidebar(isDrawer: true)),
      
      body: Row(
        children: [
          // 2. MAIN WORKSPACE (Switches based on menu selection)
          Expanded(
            child: _buildCurrentView(isDesktop),
          ),

          // 3. RIGHT PANEL (Cart / Ticket - Only shows on POS screen on Desktop)
          if (isDesktop && _currentMenuIndex == 0) _buildCartPanel(),
        ],
      ),
      // Mobile overlay cart floating button (only on POS screen on Mobile)
      floatingActionButton: (!isDesktop && _cart.isNotEmpty && _currentMenuIndex == 0)
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: _buildCartPanel()),
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

  // --- VIEW ROUTER ---
  Widget _buildCurrentView(bool isDesktop) {
    switch (_currentMenuIndex) {
      case 1:
        return _buildHistoryView();
      case 2:
        return _buildStockView();
      case 3:
        return _buildSettingsView();
      case 0:
      default:
        return _buildPosView(isDesktop);
    }
  }

  // --- SCREENS ---

  Widget _buildPosView(bool isDesktop) {
    List<Product> displayedProducts = _selectedCategory == 'All'
        ? inventory
        : inventory.where((p) => p.category == _selectedCategory).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Category Bar
        Container(
          padding: EdgeInsets.fromLTRB(24, isDesktop ? 24 : 16, 24, 16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                const Text(
                  'Point of Sale',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                ),
              if (isDesktop) const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    bool isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ChoiceChip(
                        label: Text(category),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey.shade800,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        selected: isSelected,
                        selectedColor: Theme.of(context).primaryColor,
                        backgroundColor: Colors.grey.shade200,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Product Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: displayedProducts.length,
            itemBuilder: (context, index) {
              final product = displayedProducts[index];
              return _buildProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: const Text('Transaction History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
        ),
        Expanded(
          child: _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('No past transactions found.', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final tx = _history[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: const Icon(Icons.check, color: Colors.green),
                        ),
                        title: Text('Order #${tx.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${tx.date.day}/${tx.date.month}/${tx.date.year} at ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('R ${tx.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.print, color: Colors.grey),
                              onPressed: () => _printReceipt(tx),
                              tooltip: 'Print Receipt',
                            ),
                          ],
                        ),
                        children: [
                          if (!tx.includesVat)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                              alignment: Alignment.centerLeft,
                              child: const Text('Note: This order was processed without VAT.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.red)),
                            ),
                          ...tx.items.map((item) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
                              title: Text(item.product.name, style: const TextStyle(fontSize: 14)),
                              trailing: Text('${item.quantity} x R ${item.product.price.toStringAsFixed(2)}'),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStockView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: const Text('Inventory Management', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: inventory.length,
            itemBuilder: (context, index) {
              final item = inventory[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: item.color.withOpacity(0.2),
                    child: Icon(Icons.water_drop, color: item.color),
                  ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ID: ${item.id}  •  Category: ${item.category}'),
                  trailing: Text('R ${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: const Text('System Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D))),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSettingsCard(Icons.store, 'Store Details', 'Solumate Industrial Supplies\nKrugersdorp, South Africa'),
              const SizedBox(height: 16),
              _buildSettingsCard(Icons.receipt_long, 'Tax Settings', 'Standard VAT rate: 15%'),
              const SizedBox(height: 16),
              _buildSettingsCard(Icons.print, 'Hardware', 'Receipt Printer: Ready\nCash Drawer: Not Connected'),
              const SizedBox(height: 16),
              _buildSettingsCard(Icons.storage, 'Database', 'Local Persistent Storage: Active\nTransactions are saved securely.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 14, height: 1.5)),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSidebar({bool isDrawer = false}) {
    return Container(
      width: 100,
      color: const Color(0xFF1E1E2D),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Solumate "S" Logo placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('S', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
            _buildSidebarIcon(Icons.point_of_sale, "POS", 0, isDrawer: isDrawer),
            _buildSidebarIcon(Icons.history, "History", 1, isDrawer: isDrawer),
            _buildSidebarIcon(Icons.inventory_2_outlined, "Stock", 2, isDrawer: isDrawer),
            const Spacer(),
            _buildSidebarIcon(Icons.settings_outlined, "Settings", 3, isDrawer: isDrawer),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarIcon(IconData icon, String label, int index, {bool isDrawer = false}) {
    bool isActive = _currentMenuIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentMenuIndex = index;
        });
        if (isDrawer) {
          Navigator.pop(context); // Close the drawer after selecting
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade500, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade500,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _addToCart(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Color bar representing the product category
            Expanded(
              flex: 3,
              child: Container(
                color: product.color.withOpacity(0.1),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(product.name.contains("Case") ? Icons.view_in_ar : Icons.water_drop, size: 48, color: product.color),
                      if (product.name.contains("Case"))
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: product.color, borderRadius: BorderRadius.circular(4)),
                          child: const Text("CASE OF 25", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ),
              ),
            ),
            // Product Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R ${product.price.toStringAsFixed(2)}',
                      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      width: 400,
      color: Colors.white,
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: _clearCart,
                    tooltip: 'Clear Cart',
                  ),
              ],
            ),
          ),

          // Cart Items
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No items added yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
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
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('R ${item.product.price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          // Quantity Controls
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () => _updateQuantity(item, -1),
                                  child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.remove, size: 16)),
                                ),
                                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                InkWell(
                                  onTap: () => _updateQuantity(item, 1),
                                  child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.add, size: 16)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Line Total
                          SizedBox(
                            width: 70,
                            child: Text(
                              'R ${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Financial Summary & Checkout
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Include 15% VAT', style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _applyVat,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _applyVat = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSummaryRow('Subtotal', _subTotal),
                if (_applyVat) const SizedBox(height: 8),
                if (_applyVat) _buildSummaryRow('VAT (15%)', _vatAmount),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'R ${_grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _cart.isEmpty ? null : _checkout,
                    child: const Text('Charge', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        Text('R ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}