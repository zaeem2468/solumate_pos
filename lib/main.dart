import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'pdf_generator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(const SolumatePosApp());
}

class SolumatePosApp extends StatelessWidget {
  const SolumatePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solumate Business OS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF4F46E5), 
        scaffoldBackgroundColor: const Color(0xFFF4F7FA), 
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        fontFamily: 'Roboto', 
      ),
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// SPLASH SCREEN
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    
    _animationController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const PosScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))
                  ],
                ),
                child: const Center(
                  child: Text('S', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w900, fontSize: 80)),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Solumate.',
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              ),
              const SizedBox(height: 8),
              const Text(
                'BUSINESS OS',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 6),
              ),
              const SizedBox(height: 64),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CORE STATE & UI (POS SCREEN)
// ==========================================
class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // --- State Variables ---
  final List<CartItem> _cart = [];
  final List<OrderTransaction> _history = [];
  final List<Customer> _customers = [];
  final List<Expense> _expenses = [];
  List<Product> _inventory = [];
  
  String _selectedCategory = 'All';
  int _currentMenuIndex = 1; 
  bool _applyVat = true;
  double _discountAmount = 0.0; 
  
  // Settings
  String _storeName = 'SOLUMATE';
  String _storeAddress = 'Krugersdorp, Gauteng';
  String _storePhone = '074 299 7866';
  String _storeEmail = 'Ziemie786@gmail.com';
  double _globalVatRate = 0.15; 
  
  final TextEditingController _searchController = TextEditingController(); 
  StateSetter? _cartSheetSetState; 

  final List<String> _categories = ['All', 'Thinners', 'Oils', 'Spirits', 'Other'];
  final List<String> _expenseCategories = ['Inventory / Stock', 'Rent', 'Utilities', 'Wages', 'Marketing', 'Maintenance', 'Other'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  // --- DATABASE LOGIC ---
  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    
    _storeName = prefs.getString('solumate_store_name') ?? 'SOLUMATE';
    _storeAddress = prefs.getString('solumate_store_address') ?? 'Krugersdorp, Gauteng';
    _storePhone = prefs.getString('solumate_store_phone') ?? '074 299 7866';
    _storeEmail = prefs.getString('solumate_store_email') ?? 'Ziemie786@gmail.com';
    _globalVatRate = prefs.getDouble('solumate_vat_rate') ?? 0.15;

    final String? invData = prefs.getString('solumate_inventory');
    if (invData != null) _inventory = (jsonDecode(invData) as List).map((item) => Product.fromJson(item)).toList();
    if (_inventory.isEmpty) { _loadDefaultInventory(); _saveInventoryToDatabase(); }

    final String? histData = prefs.getString('solumate_tx_history');
    if (histData != null) _history.addAll((jsonDecode(histData) as List).map((item) => OrderTransaction.fromJson(item)).toList());

    final String? custData = prefs.getString('solumate_customers');
    if (custData != null) _customers.addAll((jsonDecode(custData) as List).map((item) => Customer.fromJson(item)).toList());

    final String? expData = prefs.getString('solumate_expenses');
    if (expData != null) _expenses.addAll((jsonDecode(expData) as List).map((item) => Expense.fromJson(item)).toList());

    setState(() {}); 
  }

  void _loadDefaultInventory() {
    _inventory = [
      Product(id: 'LCQ-750', name: '"A" Grade Lacquer (750ml)', price: 20.50, category: 'Thinners', color: Colors.blueGrey, icon: Icons.water_drop),
      Product(id: 'LCQ-750-C', name: 'Lacquer (750ml) - Case', price: 512.50, category: 'Thinners', color: Colors.indigo, icon: Icons.inventory_2),
      Product(id: 'LCQ-005', name: '"A" Grade Lacquer (5L)', price: 119.00, category: 'Thinners', color: Colors.blueGrey, icon: Icons.science),
      Product(id: 'ENM-750', name: 'QD Enamel Thinner (750ml)', price: 22.00, category: 'Thinners', color: Colors.teal, icon: Icons.water_drop),
      Product(id: 'ENM-750-C', name: 'Enamel (750ml) - Case', price: 550.00, category: 'Thinners', color: Colors.teal.shade700, icon: Icons.inventory_2),
      Product(id: 'ENM-005', name: 'QD Enamel (5L)', price: 120.00, category: 'Thinners', color: Colors.teal.shade900, icon: Icons.format_paint),
      Product(id: 'TRP-750', name: 'Mineral Turpentine (750ml)', price: 25.00, category: 'Thinners', color: Colors.cyan, icon: Icons.water_drop),
      Product(id: 'TRP-750-C', name: 'Turpentine (750ml) - Case', price: 625.00, category: 'Thinners', color: Colors.cyan.shade700, icon: Icons.inventory_2),
      Product(id: 'LIN-OIL', name: 'Raw Linseed Oil (750ml)', price: 46.00, category: 'Oils', color: Colors.amber.shade700, icon: Icons.water_drop),
      Product(id: 'LIN-OIL-C', name: 'Linseed Oil (750ml) - Case', price: 1150.00, category: 'Oils', color: Colors.amber.shade900, icon: Icons.inventory_2),
      Product(id: 'MET-750', name: 'Methylated Spirits (750ml)', price: 28.00, category: 'Spirits', color: Colors.purple.shade400, icon: Icons.science),
      Product(id: 'MET-750-C', name: 'Meths (750ml) - Case', price: 700.00, category: 'Spirits', color: Colors.purple.shade700, icon: Icons.inventory_2),
    ];
  }

  Future<void> _saveInventoryToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_inventory', jsonEncode(_inventory.map((p) => p.toJson()).toList()));
  }

  Future<void> _saveHistoryToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_tx_history', jsonEncode(_history.map((tx) => tx.toJson()).toList()));
  }

  Future<void> _saveCustomersToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_customers', jsonEncode(_customers.map((c) => c.toJson()).toList()));
  }

  Future<void> _saveExpensesToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_expenses', jsonEncode(_expenses.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_store_name', _storeName);
    await prefs.setString('solumate_store_address', _storeAddress);
    await prefs.setString('solumate_store_phone', _storePhone);
    await prefs.setString('solumate_store_email', _storeEmail);
    await prefs.setDouble('solumate_vat_rate', _globalVatRate);
  }

  Future<void> _factoryReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _history.clear();
      _customers.clear();
      _expenses.clear();
      _inventory.clear();
      _loadDefaultInventory();
    });
    await _saveInventoryToDatabase();
  }

  // --- CORE STATE UPDATER ---
  void _updateState(VoidCallback fn) {
    setState(fn);
    _cartSheetSetState?.call(fn);
  }

  // ==========================================
  // POS & CART LOGIC
  // ==========================================

  void _addToCart(Product product) {
    _updateState(() {
      var existingItem = _cart.where((item) => item.product.id == product.id).firstOrNull;
      if (existingItem != null) existingItem.quantity++;
      else _cart.add(CartItem(product: product));
    });
  }

  void _updateQuantity(CartItem item, int delta) {
    _updateState(() {
      item.quantity += delta;
      if (item.quantity <= 0) _cart.remove(item);
    });
  }

  Future<void> _addMiscItemDialog() async {
    TextEditingController nameCtrl = TextEditingController(text: 'Misc Item');
    TextEditingController priceCtrl = TextEditingController();
    bool saveToInventory = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Add Custom Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Item Description', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Price (R)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixText: 'R '), autofocus: true),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Save to Inventory', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: saveToInventory, activeColor: Theme.of(context).primaryColor, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) => setDialogState(() => saveToInventory = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                double? price = double.tryParse(priceCtrl.text);
                if (price != null && price >= 0) {
                  Product miscProduct = Product(id: 'MISC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}', name: nameCtrl.text.isEmpty ? 'Misc Item' : nameCtrl.text, price: price, category: 'Other', color: Colors.indigo, icon: Icons.star_border);
                  _updateState(() { if (saveToInventory) _inventory.insert(0, miscProduct); _addToCart(miscProduct); });
                  if (saveToInventory) _saveInventoryToDatabase();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editQuantityDialog(CartItem item) async {
    TextEditingController controller = TextEditingController(text: item.quantity.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Quantity'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Quantity'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              int? newQty = int.tryParse(controller.text);
              _updateState(() {
                if (newQty != null && newQty > 0) item.quantity = newQty;
                else if (newQty != null && newQty <= 0) _cart.remove(item);
              });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              double? newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                _updateState(() {
                  product.price = newPrice;
                  for (var item in _cart) {
                    if (item.product.id == product.id) item.product.price = newPrice;
                  }
                });
                _saveInventoryToDatabase();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNewProductDialog() async {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController priceCtrl = TextEditingController();
    String newCategory = 'Other';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Add New Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2_outlined))),
                  const SizedBox(height: 16),
                  TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (Excl. VAT)', border: OutlineInputBorder(), prefixText: 'R ', prefixIcon: Icon(Icons.payments_outlined))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: newCategory,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) { if (val != null) setDialogState(() => newCategory = val); },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                onPressed: () {
                  if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                  Product newProd = Product(
                    id: 'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    name: nameCtrl.text.trim(), price: double.tryParse(priceCtrl.text) ?? 0.0, category: newCategory, color: Colors.blueGrey.shade700, icon: Icons.local_offer,
                  );
                  _updateState(() { _inventory.insert(0, newProd); });
                  _saveInventoryToDatabase();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added successfully!'), backgroundColor: Colors.green));
                },
                child: const Text('Save Item'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _addDiscountDialog() async {
    TextEditingController controller = TextEditingController(text: _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Discount (ZAR)'),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Discount Amount (R)', prefixText: 'R '), autofocus: true),
        actions: [
          TextButton(onPressed: () { _updateState(() => _discountAmount = 0.0); Navigator.pop(context); }, child: const Text('Remove Discount', style: TextStyle(color: Colors.red))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              double? val = double.tryParse(controller.text);
              _updateState(() => _discountAmount = val ?? 0.0);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    _updateState(() { _cart.clear(); _applyVat = true; _discountAmount = 0.0; });
  }

  double get _subTotal => _cart.fold(0, (total, item) => total + item.totalPrice);
  double get _discountedSubtotal => (_subTotal - _discountAmount) > 0 ? (_subTotal - _discountAmount) : 0.0;
  double get _vatAmount => _applyVat ? _discountedSubtotal * _globalVatRate : 0.0;
  double get _grandTotal => _discountedSubtotal + _vatAmount;

  // ==========================================
  // CHECKOUT & TRANSACTIONS
  // ==========================================

  Future<void> _showCheckoutDialog() async {
    if (_cart.isEmpty) return;

    Customer? selectedCustomer;
    TextEditingController customerNameCtrl = TextEditingController();
    TextEditingController businessNameCtrl = TextEditingController();
    TextEditingController amountTenderedCtrl = TextEditingController();
    double amountTendered = 0.0;
    bool isNewCustomer = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder( 
        builder: (context, setCheckoutState) {
          double changeDue = amountTendered - _grandTotal;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (_customers.isNotEmpty)
                    DropdownButtonFormField<Customer?>(
                      value: selectedCustomer,
                      isExpanded: true,
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.group)),
                      hint: const Text('Existing Customer (Optional)'),
                      items: [
                        const DropdownMenuItem<Customer?>(value: null, child: Text('Walk-in / New')),
                        ..._customers.map((c) => DropdownMenuItem(value: c, child: Text('${c.name} ${c.businessName != null ? '(${c.businessName})' : ''}', overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (val) {
                        setCheckoutState(() {
                          selectedCustomer = val;
                          if (val != null) {
                            customerNameCtrl.text = val.name;
                            businessNameCtrl.text = val.businessName ?? '';
                            isNewCustomer = false;
                          } else {
                            customerNameCtrl.clear();
                            businessNameCtrl.clear();
                            isNewCustomer = true;
                          }
                        });
                      },
                    ),
                  if (_customers.isNotEmpty) const SizedBox(height: 12),

                  TextField(controller: customerNameCtrl, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.person_outline)), onChanged: (v) => isNewCustomer = selectedCustomer == null),
                  const SizedBox(height: 12),
                  TextField(controller: businessNameCtrl, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Business Name (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.business)), onChanged: (v) => isNewCustomer = selectedCustomer == null),
                  
                  if (isNewCustomer && customerNameCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('This will create a new customer profile.', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontStyle: FontStyle.italic)),
                    ),

                  const SizedBox(height: 24),
                  const Text('Payment', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountTenderedCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                    decoration: InputDecoration(labelText: 'Amount Tendered (Cash)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixText: 'R '),
                    onChanged: (val) { setCheckoutState(() { amountTendered = double.tryParse(val) ?? 0.0; }); },
                  ),
                  if (amountTendered > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: changeDue >= 0 ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: changeDue >= 0 ? Colors.green.shade200 : Colors.red.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(changeDue >= 0 ? 'Change Due:' : 'Short By:', style: TextStyle(color: changeDue >= 0 ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('R ${changeDue.abs().toStringAsFixed(2)}', style: TextStyle(color: changeDue >= 0 ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo.shade50, Colors.indigo.shade100]), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount Due:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('R ${_grandTotal.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finalizeOrder('Awaiting Payment', customerNameCtrl.text, businessNameCtrl.text, selectedCustomer);
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700, side: BorderSide(color: Colors.orange.shade300)),
                child: const Text('Awaiting Payment'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finalizeOrder('Paid', customerNameCtrl.text, businessNameCtrl.text, selectedCustomer);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, elevation: 2),
                child: const Text('Mark as Paid'),
              ),
            ],
          );
        }
      )
    );
  }

  void _finalizeOrder(String status, String custName, String bizName, Customer? existingCustomer) {
    Customer? targetCustomer = existingCustomer;

    if (targetCustomer == null && custName.trim().isNotEmpty) {
      targetCustomer = Customer(
        id: 'CST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        name: custName.trim(),
        businessName: bizName.trim().isNotEmpty ? bizName.trim() : null,
        createdAt: DateTime.now(),
      );
      _customers.add(targetCustomer);
    }

    if (targetCustomer != null) {
      targetCustomer.totalSpent += _grandTotal;
      if (status == 'Awaiting Payment') targetCustomer.outstandingBalance += _grandTotal;
      _saveCustomersToDatabase();
    }

    final newTransaction = OrderTransaction(
      id: 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      date: DateTime.now(),
      subtotal: _subTotal, discount: _discountAmount, vat: _vatAmount, total: _grandTotal,
      items: List.from(_cart),
      includesVat: _applyVat,
      paymentStatus: status,
      customerId: targetCustomer?.id,
      customerName: targetCustomer?.name ?? (custName.trim().isNotEmpty ? custName.trim() : null),
      businessName: targetCustomer?.businessName ?? (bizName.trim().isNotEmpty ? bizName.trim() : null),
    );

    _updateState(() { _history.insert(0, newTransaction); });
    _saveHistoryToDatabase();
    _showSuccessDialog(newTransaction);
  }

  void _showSuccessDialog(OrderTransaction tx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(tx.paymentStatus == 'Paid' ? Icons.check_circle : Icons.schedule, color: tx.paymentStatus == 'Paid' ? Colors.green : Colors.orange, size: 32),
            const SizedBox(width: 10),
            Expanded(child: Text(tx.paymentStatus == 'Paid' ? 'Payment Successful' : 'Order Saved', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text('Order #${tx.id}\nStatus: ${tx.paymentStatus}\nTotal: R ${tx.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); PdfGenerator.printReceipt(tx, _storeName, _globalVatRate); _clearCart(); }, child: const Text('Receipt')),
          TextButton(onPressed: () { Navigator.pop(context); PdfGenerator.printInvoice(tx, _storeName, _storeAddress, _storePhone, _storeEmail, _globalVatRate); _clearCart(); }, child: const Text('Invoice')),
          TextButton(onPressed: () { Navigator.pop(context); PdfGenerator.printBusinessCopy(tx, _storeName); _clearCart(); }, child: const Text('Waybill')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white), onPressed: () { Navigator.pop(context); _clearCart(); }, child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(OrderTransaction tx) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction'),
        content: Text('Are you sure you want to permanently delete order #${tx.id}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() { _history.removeWhere((item) => item.id == tx.id); });
      
      if (tx.paymentStatus == 'Awaiting Payment' && tx.customerId != null) {
        Customer? c = _customers.where((cust) => cust.id == tx.customerId).firstOrNull;
        if (c != null) {
          c.outstandingBalance -= tx.total;
          c.totalSpent -= tx.total;
          if (c.outstandingBalance < 0) c.outstandingBalance = 0;
          if (c.totalSpent < 0) c.totalSpent = 0;
          _saveCustomersToDatabase();
        }
      }
      _saveHistoryToDatabase();
    }
  }

  // ==========================================
  // CUSTOMER (CRM) LOGIC
  // ==========================================

  Future<void> _addOrEditCustomerDialog([Customer? existing]) async {
    TextEditingController nameCtrl = TextEditingController(text: existing?.name);
    TextEditingController bizCtrl = TextEditingController(text: existing?.businessName);
    TextEditingController phoneCtrl = TextEditingController(text: existing?.phone);
    TextEditingController emailCtrl = TextEditingController(text: existing?.email);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 12),
              TextField(controller: bizCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Business Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() {
                if (existing != null) {
                  existing.name = nameCtrl.text.trim();
                  existing.businessName = bizCtrl.text.trim().isEmpty ? null : bizCtrl.text.trim();
                  existing.phone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();
                  existing.email = emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim();
                } else {
                  _customers.add(Customer(
                    id: 'CST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    name: nameCtrl.text.trim(),
                    businessName: bizCtrl.text.trim().isEmpty ? null : bizCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    createdAt: DateTime.now(),
                  ));
                }
              });
              _saveCustomersToDatabase();
              Navigator.pop(context);
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _settleCustomerAccount(Customer customer) async {
    if (customer.outstandingBalance <= 0) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settle Account'),
        content: Text('Mark ${customer.name}\'s outstanding balance of R ${customer.outstandingBalance.toStringAsFixed(2)} as Paid?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('Mark Fully Paid')),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        customer.outstandingBalance = 0;
        for (var tx in _history) {
          if (tx.customerId == customer.id && tx.paymentStatus == 'Awaiting Payment') {
            tx.paymentStatus = 'Paid';
          }
        }
      });
      _saveCustomersToDatabase();
      _saveHistoryToDatabase();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account settled successfully!'), backgroundColor: Colors.green));
    }
  }

  // ==========================================
  // EXPENSE LOGIC
  // ==========================================

  Future<void> _addExpenseDialog() async {
    TextEditingController descCtrl = TextEditingController();
    TextEditingController amountCtrl = TextEditingController();
    String selectedCat = _expenseCategories.first;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Record Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: descCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt))),
              const SizedBox(height: 12),
              TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (R)', border: OutlineInputBorder(), prefixText: 'R ')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCat,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category', prefixIcon: Icon(Icons.category)),
                items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) { if (val != null) setDialogState(() => selectedCat = val); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
              onPressed: () {
                double? amt = double.tryParse(amountCtrl.text);
                if (amt != null && amt > 0 && descCtrl.text.isNotEmpty) {
                  setState(() {
                    _expenses.insert(0, Expense(
                      id: 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                      description: descCtrl.text.trim(),
                      amount: amt,
                      category: selectedCat,
                      date: DateTime.now(),
                    ));
                  });
                  _saveExpensesToDatabase();
                  Navigator.pop(context);
                }
              },
              child: const Text('Record Expense'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(Expense exp) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to remove this R ${exp.amount.toStringAsFixed(2)} expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() { _expenses.remove(exp); });
      _saveExpensesToDatabase();
    }
  }

  // ==========================================
  // MAIN APP LAYOUT
  // ==========================================
  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 850;

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop ? Drawer(
        child: Container(
          color: const Color(0xFF0F172A),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Text('Solumate.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 30),
                _buildSidebarItem(Icons.people, 'Customers (CRM)', 4),
                _buildSidebarItem(Icons.account_balance_wallet, 'Expenses', 5),
                _buildSidebarItem(Icons.analytics, 'Reports', 6),
                const Divider(color: Colors.white24, indent: 20, endIndent: 20),
                _buildSidebarItem(Icons.settings, 'Settings', 7),
              ],
            ),
          ),
        ),
      ) : null,
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (isDesktop) _buildSidebar(),
            
            // --- NEW: SMOOTH ANIMATED TAB TRANSITIONS ---
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey<int>(_currentMenuIndex),
                  child: _buildCurrentView(isDesktop),
                ),
              ),
            ),
            
            // --- NEW: SMOOTH CART SLIDE TRANSITION (DESKTOP) ---
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: (isDesktop && _currentMenuIndex == 1) 
                    ? _buildCartPanel() 
                    : const SizedBox.shrink(key: ValueKey('empty_cart')),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: !isDesktop
          ? NavigationBar(
              selectedIndex: _currentMenuIndex > 3 ? 3 : _currentMenuIndex, 
              onDestinationSelected: (index) {
                if (index == 3) {
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  setState(() => _currentMenuIndex = index);
                }
              },
              backgroundColor: Colors.white,
              elevation: 20,
              indicatorColor: const Color(0xFFEEF2FF),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF4F46E5)), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale, color: Color(0xFF4F46E5)), label: 'POS'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF4F46E5)), label: 'Ledger'),
                NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
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
                  builder: (context) => StatefulBuilder( 
                    builder: (BuildContext context, StateSetter setModalState) {
                      _cartSheetSetState = setModalState; 
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.85,
                        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                        child: Column(
                          children: [
                            Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                            Expanded(child: _buildCartPanel()),
                          ],
                        )
                      );
                    }
                  )
                ).whenComplete(() => _cartSheetSetState = null); 
              },
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 6,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text('R ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // ==========================================
  // VIEWS ROUTER
  // ==========================================
  Widget _buildCurrentView(bool isDesktop) {
    switch (_currentMenuIndex) {
      case 0: return _buildDashboardView(isDesktop);
      case 1: return _buildPosView(isDesktop);
      case 2: return _buildLedgerView(isDesktop); 
      case 3: return _buildInventoryView(isDesktop);
      case 4: return _buildCustomersView(isDesktop);
      case 5: return _buildExpensesView(isDesktop);
      case 6: return _buildReportsView(isDesktop);
      case 7: return _buildSettingsView(isDesktop);
      default: return _buildPosView(isDesktop);
    }
  }

  // ==========================================
  // DASHBOARD VIEW
  // ==========================================
  Widget _buildDashboardView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;
    
    double totalRev = _history.fold(0, (sum, tx) => sum + tx.subtotal); 
    double totalExp = _expenses.fold(0, (sum, e) => sum + e.amount);
    double netProfit = totalRev - totalExp;

    Map<String, double> revByDay = {};
    Map<String, double> revByCategory = {'Thinners': 0, 'Oils': 0, 'Spirits': 0, 'Other': 0};
    
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime d = now.subtract(Duration(days: i));
      String dayLabel = '${d.day}/${d.month}';
      revByDay[dayLabel] = 0;
    }

    for (var tx in _history) {
      String dayLabel = '${tx.date.day}/${tx.date.month}';
      if (revByDay.containsKey(dayLabel)) {
        revByDay[dayLabel] = revByDay[dayLabel]! + tx.subtotal;
      }
      for (var item in tx.items) {
        String cat = item.product.category;
        if (revByCategory.containsKey(cat)) {
          revByCategory[cat] = revByCategory[cat]! + (item.product.price * item.quantity);
        } else {
          revByCategory['Other'] = (revByCategory['Other'] ?? 0) + (item.product.price * item.quantity);
        }
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: EdgeInsets.all(screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
            const SizedBox(height: 8),
            Text('Financial overview and analytics.', style: TextStyle(color: Colors.grey.shade600, fontSize: isDesktop ? 16 : 14)),
            const SizedBox(height: 24),
            
            if (isDesktop)
              Row(
                children: [
                  Expanded(child: _buildGradientKpiCard('Gross Revenue', 'R ${totalRev.toStringAsFixed(2)}', Icons.payments, Colors.teal)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildGradientKpiCard('Net Profit', 'R ${netProfit.toStringAsFixed(2)}', Icons.account_balance, netProfit >= 0 ? Colors.green : Colors.red)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildGradientKpiCard('Total Orders', '${_history.length}', Icons.shopping_cart, Colors.indigo)),
                ],
              )
            else
              Column(
                children: [
                  _buildGradientKpiCard('Gross Revenue', 'R ${totalRev.toStringAsFixed(2)}', Icons.payments, Colors.teal),
                  const SizedBox(height: 12),
                  _buildGradientKpiCard('Net Profit', 'R ${netProfit.toStringAsFixed(2)}', Icons.account_balance, netProfit >= 0 ? Colors.green : Colors.red),
                  const SizedBox(height: 12),
                  _buildGradientKpiCard('Total Orders', '${_history.length}', Icons.shopping_cart, Colors.indigo),
                ],
              ),
            
            const SizedBox(height: 24),
            
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildRevenueBarChart(revByDay, isDesktop)),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: _buildCategorySalesChart(revByCategory, totalRev, isDesktop)),
                ],
              )
            else
              Column(
                children: [
                  _buildRevenueBarChart(revByDay, isDesktop),
                  const SizedBox(height: 16),
                  _buildCategorySalesChart(revByCategory, totalRev, isDesktop),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientKpiCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.shade400, color.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBarChart(Map<String, double> revByDay, bool isDesktop) {
    double maxRev = revByDay.values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxRev == 0) maxRev = 1; 

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Trend (7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          SizedBox(
            height: isDesktop ? 220 : 160,
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
                      width: isDesktop ? 32 : 20,
                      height: (isDesktop ? 160 : 100) * heightPct,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF4F46E5)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(e.key, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySalesChart(Map<String, double> catData, double totalRev, bool isDesktop) {
    if (totalRev == 0) totalRev = 1; 
    
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 24),
          ...catData.entries.where((e) => e.value > 0).map((e) {
            double pct = e.value / totalRev;
            Color barColor = e.key == 'Thinners' ? Colors.teal : (e.key == 'Oils' ? Colors.amber.shade500 : (e.key == 'Spirits' ? Colors.purple.shade400 : Colors.blueGrey));
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                      color: barColor, 
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==========================================
  // POS VIEW
  // ==========================================
  Widget _buildPosView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;

    List<Product> displayedProducts = _inventory.where((p) {
      bool matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      bool matchesSearch = p.name.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(screenPadding, screenPadding, screenPadding, 16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Point of Sale', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
                  if (isDesktop) SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search inventory...',
                        prefixIcon: const Icon(Icons.search, size: 22, color: Colors.grey),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (val) => setState((){}),
                    ),
                  )
                ],
              ),
              if (!isDesktop) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search inventory...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                    isDense: true,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState((){}),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _categories.map((category) {
                          bool isSelected = _selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(category, style: TextStyle(fontSize: isDesktop ? 14 : 12)),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0F172A),
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600),
                              backgroundColor: Colors.grey.shade100,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.transparent)),
                              onSelected: (_) => setState(() => _selectedCategory = category),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (isDesktop)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: _addMiscItemDialog, 
                        icon: const Icon(Icons.add_circle_outline, size: 20), 
                        label: const Text('Misc Item'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade50, foregroundColor: Colors.indigo.shade700, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                ],
              ),
              if (!isDesktop)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addMiscItemDialog, 
                      icon: const Icon(Icons.add_circle_outline, size: 18), 
                      label: const Text('Add Custom Item', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.indigo.shade700, side: BorderSide(color: Colors.indigo.shade100), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(screenPadding),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: isDesktop ? 0.85 : 0.72,
              crossAxisSpacing: isDesktop ? 20 : 12,
              mainAxisSpacing: isDesktop ? 20 : 12,
            ),
            itemCount: displayedProducts.length,
            itemBuilder: (context, index) {
              final product = displayedProducts[index];
              return InkWell(
                onTap: () => _addToCart(product),
                borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
                    border: Border.all(color: Colors.grey.shade100, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 6))],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 20.0 : 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isDesktop ? 14 : 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [product.color.withOpacity(0.15), product.color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                            border: Border.all(color: product.color.withOpacity(0.1))
                          ),
                          child: Icon(product.icon, color: product.color, size: isDesktop ? 32 : 24),
                        ),
                        const Spacer(),
                        Text(product.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: isDesktop ? 15 : 13, height: 1.2, color: const Color(0xFF0F172A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                        SizedBox(height: isDesktop ? 10 : 6),
                        Text('R ${product.price.toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w900, fontSize: isDesktop ? 18 : 15)),
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

  // ==========================================
  // INVENTORY VIEW
  // ==========================================
  Widget _buildInventoryView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenPadding),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventory', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text('Manage product catalogue.', style: TextStyle(color: Colors.grey.shade600, fontSize: isDesktop ? 16 : 14)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addNewProductDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: isDesktop ? const Text('Add Item') : const Text('Add'),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, elevation: 2, padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: isDesktop ? 16 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: screenPadding, vertical: 8),
              physics: const BouncingScrollPhysics(),
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final p = _inventory[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                    boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16, vertical: 8),
                    leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: p.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(p.icon, color: p.color, size: 24)),
                    title: Text(p.name, style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: isDesktop ? 16 : 14)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('ID: ${p.id}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('R ${p.price.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isDesktop ? 18 : 16, color: const Color(0xFF0F172A))),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            icon: Icon(Icons.edit, color: Colors.grey.shade600, size: 20),
                            onPressed: () => _editPriceDialog(p),
                            tooltip: 'Edit Price',
                          ),
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

  // ==========================================
  // LEDGER VIEW
  // ==========================================
  Widget _buildLedgerView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenPadding),
            width: double.infinity,
            child: Text('Ledger', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
          ),
          Expanded(
            child: _history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text('No transactions recorded yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: screenPadding, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 450,
                      childAspectRatio: isDesktop ? 1.1 : 0.95, 
                      crossAxisSpacing: isDesktop ? 20 : 12,
                      mainAxisSpacing: isDesktop ? 20 : 12,
                    ),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final tx = _history[index];
                      int itemCount = tx.items.fold(0, (sum, item) => sum + item.quantity);
                      MaterialColor statusColor = tx.paymentStatus == 'Paid' ? Colors.green : Colors.orange;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isDesktop ? 24 : 16),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, 6))],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Row(
                          children: [
                            Container(width: 6, height: double.infinity, color: statusColor),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                                                child: Text(tx.id, style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w800, fontSize: 10)),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                                child: Text(
                                                  tx.paymentStatus.toUpperCase(), 
                                                  style: TextStyle(color: statusColor.shade700, fontWeight: FontWeight.w800, fontSize: 9)
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton( 
                                          icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                                          onPressed: () => _deleteTransaction(tx),
                                          iconSize: 20,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text('R ${tx.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isDesktop ? 20 : 18, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    Text('${tx.date.day}/${tx.date.month}/${tx.date.year} at ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                                    
                                    if (tx.customerName != null || tx.businessName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text('${tx.customerName ?? ''} ${tx.businessName != null ? '(${tx.businessName})' : ''}', style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),

                                    const SizedBox(height: 4),
                                    Text('$itemCount items', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        if (tx.paymentStatus == 'Awaiting Payment')
                                          Expanded(
                                            flex: 3,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.check, size: 16),
                                              label: const Text('Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade50, foregroundColor: Colors.green.shade700, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                              onPressed: () {
                                                setState(() { tx.paymentStatus = 'Paid'; });
                                                if (tx.customerId != null) {
                                                  Customer? c = _customers.where((cust) => cust.id == tx.customerId).firstOrNull;
                                                  if (c != null && c.outstandingBalance >= tx.total) {
                                                    c.outstandingBalance -= tx.total;
                                                    _saveCustomersToDatabase();
                                                  }
                                                }
                                                _saveHistoryToDatabase();
                                              },
                                            ),
                                          ),
                                        if (tx.paymentStatus == 'Awaiting Payment') const SizedBox(width: 8),
                                        Expanded(
                                          flex: 4,
                                          child: PopupMenuButton<String>(
                                            offset: const Offset(0, 40),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.download, size: 16, color: Color(0xFF4F46E5)),
                                                  SizedBox(width: 4),
                                                  Text('Docs', style: TextStyle(color: Color(0xFF4F46E5), fontSize: 12, fontWeight: FontWeight.bold))
                                                ],
                                              ),
                                            ),
                                            onSelected: (val) {
                                              if (val == 'receipt') PdfGenerator.printReceipt(tx, _storeName, _globalVatRate);
                                              if (val == 'invoice') PdfGenerator.printInvoice(tx, _storeName, _storeAddress, _storePhone, _storeEmail, _globalVatRate);
                                              if (val == 'business') PdfGenerator.printBusinessCopy(tx, _storeName);
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(value: 'receipt', child: Text('Thermal Receipt')),
                                              const PopupMenuItem(value: 'invoice', child: Text('Customer Invoice (A4)')),
                                              const PopupMenuItem(value: 'business', child: Text('Business Copy / Waybill')),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CUSTOMERS (CRM) VIEW
  // ==========================================
  Widget _buildCustomersView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenPadding),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customers', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text('Manage accounts & debt.', style: TextStyle(color: Colors.grey.shade600, fontSize: isDesktop ? 16 : 14)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _addOrEditCustomerDialog(),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: isDesktop ? const Text('Add Customer') : const Text('Add'),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, elevation: 2, padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: isDesktop ? 16 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )
              ],
            ),
          ),
          Expanded(
            child: _customers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text('No customers added yet.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: screenPadding, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _customers.length,
                    itemBuilder: (context, index) {
                      final c = _customers[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          tilePadding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 8),
                          leading: CircleAvatar(backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1), radius: 20, child: Text(c.name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                          title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: isDesktop ? 16 : 14)),
                          subtitle: Text(c.businessName ?? 'Individual Client', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Spent: R ${c.totalSpent.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
                              if (c.outstandingBalance > 0)
                                Text('Owes: R ${c.outstandingBalance.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 12)),
                            ],
                          ),
                          children: [
                            Container(
                              padding: EdgeInsets.all(isDesktop ? 24 : 16),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Text('📞 ${c.phone ?? "N/A"}', style: const TextStyle(fontSize: 13)),
                                  Text('✉️ ${c.email ?? "N/A"}', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _addOrEditCustomerDialog(c),
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      if (c.outstandingBalance > 0) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _settleCustomerAccount(c),
                                            icon: const Icon(Icons.payment, size: 16),
                                            label: const Text('Settle', style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EXPENSES VIEW
  // ==========================================
  Widget _buildExpensesView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;
    double totalExpenses = _expenses.fold(0, (sum, exp) => sum + exp.amount);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenPadding),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expenses', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
                      const SizedBox(height: 4),
                      Text('Recorded: R ${totalExpenses.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addExpenseDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: isDesktop ? const Text('Record Expense') : const Text('Add'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white, elevation: 2, padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: isDesktop ? 16 : 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )
              ],
            ),
          ),
          Expanded(
            child: _expenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 20),
                        Text('No expenses recorded.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: screenPadding, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final exp = _expenses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16, vertical: 8),
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.money_off, color: Colors.red.shade400, size: 24)),
                          title: Text(exp.description, style: TextStyle(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: isDesktop ? 16 : 14)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('${exp.category}  •  ${exp.date.day}/${exp.date.month}/${exp.date.year}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('- R ${exp.amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isDesktop ? 18 : 16, color: Colors.red.shade600)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: Colors.grey.shade400, size: 20),
                                onPressed: () => _deleteExpense(exp),
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

  // ==========================================
  // REPORTS VIEW
  // ==========================================
  Widget _buildReportsView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenPadding),
            width: double.infinity,
            child: Text('Reports & Analytics', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenPadding),
              child: isDesktop 
                ? Row(
                    children: [
                      Expanded(
                        child: _buildReportGeneratorCard(
                          'Daily Cash-Up',
                          'End-of-day report detailing all sales and expenses.',
                          Icons.today,
                          () => PdfGenerator.generateFinancialReportPdf('End of Day Report (Today)', _history, _expenses, _storeName),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildReportGeneratorCard(
                          'Monthly Summary',
                          'Generate a full P&L statement for the month.',
                          Icons.calendar_month,
                          () => PdfGenerator.generateFinancialReportPdf('Monthly Profit & Loss Statement', _history, _expenses, _storeName),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildReportGeneratorCard(
                        'Daily Cash-Up',
                        'End-of-day report detailing all sales and expenses.',
                        Icons.today,
                        () => PdfGenerator.generateFinancialReportPdf('End of Day Report (Today)', _history, _expenses, _storeName),
                      ),
                      const SizedBox(height: 16),
                      _buildReportGeneratorCard(
                        'Monthly Summary',
                        'Generate a full P&L statement for the month.',
                        Icons.calendar_month,
                        () => PdfGenerator.generateFinancialReportPdf('Monthly Profit & Loss Statement', _history, _expenses, _storeName),
                      ),
                    ],
                  )
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportGeneratorCard(String title, String desc, IconData icon, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF4F46E5), size: 32)),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(color: Colors.grey.shade600, height: 1.4, fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Generate PDF', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // SETTINGS VIEW
  // ==========================================
  Widget _buildSettingsView(bool isDesktop) {
    double screenPadding = isDesktop ? 24.0 : 16.0;
    double titleSize = isDesktop ? 32.0 : 24.0;
    
    TextEditingController storeNameCtrl = TextEditingController(text: _storeName);
    TextEditingController vatCtrl = TextEditingController(text: (_globalVatRate * 100).toStringAsFixed(0));
    TextEditingController phoneCtrl = TextEditingController(text: _storePhone);
    TextEditingController addressCtrl = TextEditingController(text: _storeAddress);
    TextEditingController emailCtrl = TextEditingController(text: _storeEmail);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(screenPadding),
            width: double.infinity,
            child: Text('Settings', style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: -1)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenPadding),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 20),
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(child: TextField(controller: storeNameCtrl, decoration: InputDecoration(labelText: 'Store Name (Prints on Receipts)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.storefront)))),
                              const SizedBox(width: 16),
                              Expanded(child: TextField(controller: vatCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'VAT Rate Percentage', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.percent), suffixText: '%'))),
                            ],
                          )
                        else
                          Column(
                            children: [
                              TextField(controller: storeNameCtrl, decoration: InputDecoration(labelText: 'Store Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.storefront))),
                              const SizedBox(height: 16),
                              TextField(controller: vatCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'VAT Rate Percentage', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.percent), suffixText: '%')),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isDesktop)
                          Row(
                            children: [
                              Expanded(child: TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone)))),
                              const SizedBox(width: 16),
                              Expanded(child: TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.email)))),
                            ],
                          )
                        else
                          Column(
                            children: [
                              TextField(controller: phoneCtrl, decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.phone))),
                              const SizedBox(height: 16),
                              TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.email))),
                            ],
                          ),
                        const SizedBox(height: 16),
                        TextField(controller: addressCtrl, decoration: InputDecoration(labelText: 'Physical Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.location_on))),
                        
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () {
                              setState(() {
                                _storeName = storeNameCtrl.text.isEmpty ? 'SOLUMATE' : storeNameCtrl.text;
                                _storePhone = phoneCtrl.text;
                                _storeEmail = emailCtrl.text;
                                _storeAddress = addressCtrl.text;
                                double? newVat = double.tryParse(vatCtrl.text);
                                if (newVat != null && newVat >= 0) _globalVatRate = newVat / 100;
                              });
                              _saveSettings();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green));
                            },
                            child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade100), boxShadow: [BoxShadow(color: Colors.grey.shade200.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Danger Zone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 8),
                        Text('Permanently wipe all databases, transactions, customers, and expenses. This cannot be undone.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              bool? confirm = await showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('WIPE ALL DATA?'),
                                  content: const Text('Are you 100% sure? All transactions and customers will be permanently deleted.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(c, true), child: const Text('Yes, Wipe Everything', style: TextStyle(color: Colors.white))),
                                  ],
                                )
                              );
                              if (confirm == true) {
                                _factoryReset();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('System Reset Complete.')));
                              }
                            },
                            icon: const Icon(Icons.warning, size: 18),
                            label: const Text('Factory Reset System', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      )
    );
  }

  // --- SIDEBAR & PANELS ---
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(4, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight), 
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  ),
                  child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22))),
                ),
                const SizedBox(width: 16),
                const Text('Solumate.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('MAIN', style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                  const SizedBox(height: 8),
                  _buildSidebarItem(Icons.bar_chart, 'Dashboard', 0),
                  _buildSidebarItem(Icons.point_of_sale, 'Point of Sale', 1),
                  _buildSidebarItem(Icons.receipt_long, 'Ledger', 2),
                  
                  const SizedBox(height: 24),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('MANAGEMENT', style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                  const SizedBox(height: 8),
                  _buildSidebarItem(Icons.inventory_2, 'Inventory', 3),
                  _buildSidebarItem(Icons.people, 'Customers', 4),
                  _buildSidebarItem(Icons.account_balance_wallet, 'Expenses', 5),
                  
                  const SizedBox(height: 24),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('SYSTEM', style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                  const SizedBox(height: 8),
                  _buildSidebarItem(Icons.analytics, 'Reports', 6),
                  _buildSidebarItem(Icons.settings, 'Settings', 7),
                ],
              ),
            ),
          ),
          
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF4F46E5), radius: 18, child: const Text('MW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('M. Wajah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    Text('Admin', style: TextStyle(fontSize: 12, color: Colors.indigo.shade200)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int index) {
    bool isActive = _currentMenuIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() => _currentMenuIndex = index);
          if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF4F46E5).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? const Color(0xFF818CF8) : Colors.white54, size: 22),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, fontSize: 15)),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                if (_cart.isNotEmpty)
                  InkWell(
                    onTap: _clearCart, 
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text('Clear All', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold, fontSize: 12)))
                  ),
              ],
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle), child: Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey.shade300)),
                        const SizedBox(height: 16),
                        Text('Your cart is empty', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Text('R ${item.product.price.toStringAsFixed(2)} each', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                              children: [
                                InkWell(onTap: () => _updateQuantity(item, -1), borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), child: Icon(Icons.remove, size: 18, color: Colors.black87))),
                                InkWell(
                                  onTap: () => _editQuantityDialog(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  ),
                                ),
                                InkWell(onTap: () => _updateQuantity(item, 1), borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), child: Icon(Icons.add, size: 18, color: Colors.black87))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 75,
                            child: Text('R ${item.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A)), textAlign: TextAlign.right),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, -4))]),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Apply VAT (${(_globalVatRate*100).toInt()}%)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700, fontSize: 15)),
                    Switch(
                      value: _applyVat,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (val) => _updateState(() => _applyVat = val), 
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _addDiscountDialog,
                      icon: const Icon(Icons.discount, size: 18),
                      label: const Text('Add Discount', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, foregroundColor: Colors.indigo.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Subtotal', style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500)), Text('R ${_subTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                if (_discountAmount > 0) const SizedBox(height: 8),
                if (_discountAmount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount', style: TextStyle(color: Colors.red.shade400, fontSize: 15, fontWeight: FontWeight.w500)), Text('-R ${_discountAmount.toStringAsFixed(2)}', style: TextStyle(color: Colors.red.shade500, fontWeight: FontWeight.bold, fontSize: 15))]),
                if (_applyVat) const SizedBox(height: 8),
                if (_applyVat) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('VAT', style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500)), Text('R ${_vatAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Text('R ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5), letterSpacing: -1)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                    ),
                    onPressed: _cart.isEmpty ? null : _showCheckoutDialog,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: _cart.isEmpty ? null : const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF4F46E5)]),
                        color: _cart.isEmpty ? Colors.grey.shade300 : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Text('Checkout', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ),
                    ),
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