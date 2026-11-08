import 'dart:convert';
import 'flashy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'catalog.dart';
import 'departments.dart';
import 'models.dart';
import 'pdf_generator.dart';
import 'theme.dart';

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
      theme: buildAppTheme(),
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)));
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic)));
    
    _animationController.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const PosScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
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
      backgroundColor: AppColors.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, _) => CustomPaint(painter: SunburstPainter(_animationController.value)),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(scale: _scaleAnimation, child: const SolumateLogo(size: 176)),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Column(
                      children: [
                        GoldText('Solumate', style: AppText.display(68)),
                        const SizedBox(height: 10),
                        const Text('Paint, thinners and hardware', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
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
  final List<Supplier> _suppliers = [];
  final List<Refund> _refunds = [];
  final List<Quote> _quotes = [];
  final List<User> _users = [];
  final List<StockAdjustment> _stockAdjustments = [];
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
  final TextEditingController _ledgerSearchController = TextEditingController();
  final TextEditingController _inventorySearchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  StateSetter? _cartSheetSetState;

  String _inventoryCategory = 'All';
  bool _inventoryLowOnly = false;
  Quote? _loadedQuote;

  final List<String> _expenseCategories = ['Inventory / Stock', 'Rent', 'Utilities', 'Wages', 'Marketing', 'Maintenance', 'Other'];

  @override
  void dispose() {
    _searchController.dispose();
    _ledgerSearchController.dispose();
    _inventorySearchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

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
    if (_inventory.isEmpty) {
      _loadDefaultInventory();
      _saveInventoryToDatabase();
    } else if (prefs.getBool(_hardwareCatalogKey) == true) {
      // Clears the sample hardware range that an earlier version added.
      _inventory.removeWhere((p) => sampleHardwareIds.contains(p.id));
      _saveInventoryToDatabase();
      await prefs.remove(_hardwareCatalogKey);
    }

    final String? histData = prefs.getString('solumate_tx_history');
    if (histData != null) _history.addAll((jsonDecode(histData) as List).map((item) => OrderTransaction.fromJson(item)).toList());

    final String? custData = prefs.getString('solumate_customers');
    if (custData != null) _customers.addAll((jsonDecode(custData) as List).map((item) => Customer.fromJson(item)).toList());

    final String? expData = prefs.getString('solumate_expenses');
    if (expData != null) _expenses.addAll((jsonDecode(expData) as List).map((item) => Expense.fromJson(item)).toList());

    final String? suppData = prefs.getString('solumate_suppliers');
    if (suppData != null) _suppliers.addAll((jsonDecode(suppData) as List).map((item) => Supplier.fromJson(item)).toList());

    final String? refundData = prefs.getString('solumate_refunds');
    if (refundData != null) _refunds.addAll((jsonDecode(refundData) as List).map((item) => Refund.fromJson(item)).toList());

    final String? quoteData = prefs.getString('solumate_quotes');
    if (quoteData != null) _quotes.addAll((jsonDecode(quoteData) as List).map((item) => Quote.fromJson(item)).toList());

    final String? userData = prefs.getString('solumate_users');
    if (userData != null) _users.addAll((jsonDecode(userData) as List).map((item) => User.fromJson(item)).toList());
    if (_users.isEmpty) { _loadDefaultUsers(); _saveUsersToDatabase(); }

    final String? stockAdjData = prefs.getString('solumate_stock_adjustments');
    if (stockAdjData != null) _stockAdjustments.addAll((jsonDecode(stockAdjData) as List).map((item) => StockAdjustment.fromJson(item)).toList());

    setState(() {});
  }

  static const String _hardwareCatalogKey = 'solumate_hardware_catalog_v1';

  void _loadDefaultInventory() {
    _inventory = paintStarterProducts();
  }

  void _loadDefaultUsers() {
    _users.addAll([
      User(
        id: 'USR-ADMIN',
        username: 'admin',
        fullName: 'System Administrator',
        role: 'Admin',
        email: 'admin@solumate.com',
        createdAt: DateTime.now(),
      ),
      User(
        id: 'USR-MANAGER',
        username: 'manager',
        fullName: 'Store Manager',
        role: 'Manager',
        email: 'manager@solumate.com',
        createdAt: DateTime.now(),
      ),
    ]);
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

  Future<void> _saveUsersToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_users', jsonEncode(_users.map((u) => u.toJson()).toList()));
  }

  Future<void> _saveSuppliersToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_suppliers', jsonEncode(_suppliers.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveRefundsToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_refunds', jsonEncode(_refunds.map((r) => r.toJson()).toList()));
  }

  Future<void> _saveQuotesToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_quotes', jsonEncode(_quotes.map((q) => q.toJson()).toList()));
  }

  Future<void> _saveStockAdjustmentsToDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('solumate_stock_adjustments', jsonEncode(_stockAdjustments.map((sa) => sa.toJson()).toList()));
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
      _quotes.clear();
      _stockAdjustments.clear();
      _cart.clear();
      _loadedQuote = null;
      _inventory.clear();
      _loadDefaultInventory();
    });
    await _saveInventoryToDatabase();
  }

  // --- CORE STATE UPDATER ---
  void _updateState(VoidCallback fn) {
    setState(fn);
    _cartSheetSetState?.call(() {});
  }

  // ==========================================
  // POS & CART LOGIC
  // ==========================================

  void _addToCart(Product product) {
    if (product.sellsByMeasure) {
      _measuredQuantityDialog(product);
    } else {
      _addQuantity(product, 1);
    }
  }

  void _addQuantity(Product product, double quantity) {
    _updateState(() {
      final existingItem = _cart.where((item) => item.product.id == product.id).firstOrNull;
      if (existingItem != null) {
        existingItem.quantity += quantity;
      } else {
        _cart.add(CartItem(product: product, quantity: quantity));
      }
    });
  }

  void _updateQuantity(CartItem item, double delta) {
    _updateState(() {
      item.quantity += delta;
      if (item.quantity <= 0) _cart.remove(item);
    });
  }

  /// Asks how much to sell for products priced per metre, kilogram or litre.
  Future<void> _measuredQuantityDialog(Product product) async {
    final controller = TextEditingController();
    final presets = switch (product.unit) {
      'm' => const <double>[1, 2, 5, 10, 25, 50],
      'kg' => const <double>[0.25, 0.5, 1, 2, 5, 10],
      _ => const <double>[0.5, 1, 2, 5, 10, 20],
    };

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final quantity = parseNumber(controller.text) ?? 0;
          void submit() {
            if (quantity <= 0) return;
            Navigator.pop(dialogContext);
            _addQuantity(product, quantity);
          }

          return AlertDialog(
            title: Text(product.name),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${product.priceLabel}, ${product.stockLabel} in stock', style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Quantity', suffixText: product.unit),
                    onChanged: (_) => setDialogState(() {}),
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: presets.map((preset) => ActionChip(
                      label: Text('${formatQty(preset)} ${product.unit}'),
                      onPressed: () => setDialogState(() => controller.text = formatQty(preset)),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Line total', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(money(quantity * product.price), style: AppText.display(26)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(onPressed: quantity > 0 ? submit : null, child: const Text('Add to order')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addMiscItemDialog() async {
    TextEditingController nameCtrl = TextEditingController(text: 'Misc Item');
    TextEditingController priceCtrl = TextEditingController();
    bool saveToInventory = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  Product miscProduct = Product(id: 'MISC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}', name: nameCtrl.text.isEmpty ? 'Misc Item' : nameCtrl.text, price: price, category: 'Other');
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
    final controller = TextEditingController(text: formatQty(item.quantity));
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: item.product.sellsByMeasure),
          decoration: InputDecoration(labelText: 'Quantity', suffixText: item.product.unit),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newQty = parseNumber(controller.text);
              if (newQty == null || (!item.product.sellsByMeasure && newQty % 1 != 0)) return;
              _updateState(() {
                if (newQty > 0) {
                  item.quantity = newQty;
                } else {
                  _cart.remove(item);
                }
              });
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"? This will remove it from the inventory list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() { _inventory.remove(product); });
      _saveInventoryToDatabase();
    }
  }

  /// Adds a new product, or edits [existing] when one is passed.
  Future<void> _productDialog([Product? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    final skuCtrl = TextEditingController(text: existing?.id);
    final barcodeCtrl = TextEditingController(text: existing?.barcode);
    final priceCtrl = TextEditingController(text: existing?.price.toStringAsFixed(2));
    final stockCtrl = TextEditingController(text: '0');
    final reorderCtrl = TextEditingController(text: formatQty(existing?.reorderPoint ?? 5));
    String department = existing?.category ?? departments.first.name;
    String unit = existing?.unit ?? 'each';
    String? error;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void save() {
            final name = nameCtrl.text.trim();
            final price = parseNumber(priceCtrl.text);
            final sku = skuCtrl.text.trim();
            if (name.isEmpty || price == null || price < 0) {
              setDialogState(() => error = 'Enter a name and a valid price.');
              return;
            }
            if (existing == null && sku.isNotEmpty && _inventory.any((p) => p.id.toLowerCase() == sku.toLowerCase())) {
              setDialogState(() => error = 'SKU $sku is already used by another item.');
              return;
            }
            final barcode = barcodeCtrl.text.trim();
            final reorderPoint = parseNumber(reorderCtrl.text) ?? 5;
            _updateState(() {
              if (existing != null) {
                existing.name = name;
                existing.price = price;
                existing.category = department;
                existing.unit = unit;
                existing.barcode = barcode.isEmpty ? null : barcode;
                existing.reorderPoint = reorderPoint;
              } else {
                _inventory.insert(0, Product(
                  id: sku.isEmpty ? 'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}' : sku,
                  name: name,
                  price: price,
                  category: department,
                  unit: unit,
                  barcode: barcode.isEmpty ? null : barcode,
                  stockQuantity: parseNumber(stockCtrl.text) ?? 0,
                  reorderPoint: reorderPoint,
                ));
              }
            });
            _saveInventoryToDatabase();
            Navigator.pop(dialogContext);
          }

          return AlertDialog(
            title: Text(existing == null ? 'Add item' : 'Edit item'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Item name')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: department,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: departments.map((d) => DropdownMenuItem(value: d.name, child: Text(d.name))).toList(),
                      onChanged: (val) { if (val != null) setDialogState(() => department = val); },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price excl. VAT', prefixText: 'R '))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: const InputDecoration(labelText: 'Sold per'),
                            items: productUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) { if (val != null) setDialogState(() => unit = val); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: skuCtrl, enabled: existing == null, decoration: const InputDecoration(labelText: 'SKU', hintText: 'Created for you if blank'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'Barcode'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (existing == null) ...[
                          Expanded(child: TextField(controller: stockCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Opening stock'))),
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: TextField(controller: reorderCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Reorder at'))),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerLeft, child: Text(error!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600))),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(onPressed: save, child: Text(existing == null ? 'Add item' : 'Save changes')),
            ],
          );
        },
      ),
    );
  }

  /// Receives or writes off stock and records why.
  Future<void> _adjustStockDialog(Product product) async {
    final controller = TextEditingController();
    bool adding = true;
    String reason = 'Restock';
    const addReasons = ['Restock', 'Return', 'Correction'];
    const removeReasons = ['Damage', 'Loss', 'Correction'];

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final amount = parseNumber(controller.text) ?? 0;
          final valid = amount > 0 && (product.sellsByMeasure || amount % 1 == 0);
          final newQuantity = product.stockQuantity + (adding ? amount : -amount);

          return AlertDialog(
            title: Text('Adjust stock: ${product.name}'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Add stock'), icon: Icon(Icons.add)),
                      ButtonSegment(value: false, label: Text('Remove stock'), icon: Icon(Icons.remove)),
                    ],
                    selected: {adding},
                    onSelectionChanged: (selection) => setDialogState(() {
                      adding = selection.first;
                      reason = adding ? addReasons.first : removeReasons.first;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.numberWithOptions(decimal: product.sellsByMeasure),
                    decoration: InputDecoration(labelText: 'Quantity', suffixText: product.unit),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: (adding ? addReasons : removeReasons).map((r) => ChoiceChip(
                      label: Text(r),
                      selected: reason == r,
                      onSelected: (_) => setDialogState(() => reason = r),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Stock will change from ${formatQty(product.stockQuantity)} to ${formatQty(newQuantity)} ${product.unit}.', style: const TextStyle(color: AppColors.muted)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: !valid ? null : () {
                  final now = DateTime.now();
                  _updateState(() {
                    _stockAdjustments.insert(0, StockAdjustment(
                      id: 'ADJ-${now.millisecondsSinceEpoch.toString().substring(7)}',
                      productId: product.id,
                      productName: product.name,
                      previousQuantity: product.stockQuantity,
                      newQuantity: newQuantity,
                      adjustment: newQuantity - product.stockQuantity,
                      reason: reason,
                      date: now,
                    ));
                    product.stockQuantity = newQuantity;
                    if (reason == 'Restock') product.lastRestocked = now;
                  });
                  _saveInventoryToDatabase();
                  _saveStockAdjustmentsToDatabase();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Save stock'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addDiscountDialog() async {
    TextEditingController controller = TextEditingController(text: _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    _updateState(() { _cart.clear(); _applyVat = true; _discountAmount = 0.0; _loadedQuote = null; });
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

    Customer? selectedCustomer = _customers.where((c) => c.id == _loadedQuote?.customerId).firstOrNull;
    TextEditingController customerNameCtrl = TextEditingController(text: _loadedQuote?.customerName);
    TextEditingController businessNameCtrl = TextEditingController(text: _loadedQuote?.businessName);
    TextEditingController notesCtrl = TextEditingController();
    TextEditingController amountTenderedCtrl = TextEditingController();
    double amountTendered = 0.0;
    String selectedPaymentMethod = 'Cash';
    bool isNewCustomer = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder( 
        builder: (context, setCheckoutState) {
          double changeDue = amountTendered - _grandTotal;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  Wrap(
                    spacing: 8,
                    children: ['Cash', 'Card', 'EFT'].map((method) => ChoiceChip(
                      label: Text(method),
                      selected: selectedPaymentMethod == method,
                      onSelected: (_) => setCheckoutState(() => selectedPaymentMethod = method),
                    )).toList(),
                  ),
                  if (selectedPaymentMethod == 'Cash') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountTenderedCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Amount tendered', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixText: 'R '),
                      onChanged: (val) { setCheckoutState(() { amountTendered = parseNumber(val) ?? 0.0; }); },
                    ),
                  ],
                  if (selectedPaymentMethod == 'Cash' && amountTendered > 0) ...[
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

                  const SizedBox(height: 16),
                  TextField(controller: notesCtrl, decoration: InputDecoration(labelText: 'Order Notes (Internal)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.note_alt_outlined))),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount due', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(money(_grandTotal), style: AppText.display(26)),
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
                  _finalizeOrder('Awaiting Payment', selectedPaymentMethod, customerNameCtrl.text, businessNameCtrl.text, notesCtrl.text, selectedCustomer);
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade700, side: BorderSide(color: Colors.orange.shade300)),
                child: const Text('Awaiting Payment'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _finalizeOrder('Paid', selectedPaymentMethod, customerNameCtrl.text, businessNameCtrl.text, notesCtrl.text, selectedCustomer);
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

  void _finalizeOrder(String status, String method, String custName, String bizName, String notes, Customer? existingCustomer) {
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
      targetCustomer.loyaltyPoints += (_grandTotal / 10).floor(); 
      if (status == 'Awaiting Payment') targetCustomer.outstandingBalance += _grandTotal;
      _saveCustomersToDatabase();
    }

    final newTransaction = OrderTransaction(
      id: 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      date: DateTime.now(),
      subtotal: _subTotal, discount: _discountAmount, vat: _vatAmount, total: _grandTotal,
      // Copies the products so later price edits can't change this sale.
      items: _cart.map((item) => CartItem(product: Product.fromJson(item.product.toJson()), quantity: item.quantity)).toList(),
      includesVat: _applyVat,
      paymentStatus: status,
      paymentMethod: method,
      customerId: targetCustomer?.id,
      customerName: targetCustomer?.name ?? (custName.trim().isNotEmpty ? custName.trim() : null),
      businessName: targetCustomer?.businessName ?? (bizName.trim().isNotEmpty ? bizName.trim() : null),
      notes: notes.trim().isNotEmpty ? notes.trim() : null,
    );

    _updateState(() { 
      _history.insert(0, newTransaction);
      for (var cartItem in _cart) {
        var inventoryProduct = _inventory.where((p) => p.id == cartItem.product.id).firstOrNull;
        if (inventoryProduct != null) inventoryProduct.stockQuantity -= cartItem.quantity;
      }
    });

    final quote = _loadedQuote;
    if (quote != null) {
      quote.status = 'Converted';
      quote.convertedToTransactionId = newTransaction.id;
      _saveQuotesToDatabase();
    }

    _saveInventoryToDatabase();
    _saveHistoryToDatabase();
    _showSuccessDialog(newTransaction);
  }

  void _showSuccessDialog(OrderTransaction tx) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    bool isDesktop = MediaQuery.of(context).size.width > 980;

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop ? Drawer(
        backgroundColor: AppColors.navy,
        child: SafeArea(
          child: Column(
            children: [
              _buildBrandBlock(),
              _buildSidebarItem(Icons.request_quote, 'Quotes', 8),
              _buildSidebarItem(Icons.people, 'Customers', 4),
              _buildSidebarItem(Icons.account_balance_wallet, 'Expenses', 5),
              _buildSidebarItem(Icons.analytics, 'Reports', 6),
              const Divider(color: Colors.white24, indent: 20, endIndent: 20),
              _buildSidebarItem(Icons.settings, 'Settings', 7),
            ],
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
              selectedIndex: const {0: 0, 1: 1, 3: 2, 2: 3}[_currentMenuIndex] ?? 4,
              onDestinationSelected: (index) {
                if (index == 4) {
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  setState(() => _currentMenuIndex = const [0, 1, 3, 2][index]);
                }
              },
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.yellow,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Sell'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stock'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Sales'),
                NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
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
                            Expanded(child: _buildCartPanel(inSheet: true)),
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
      case 8: return _buildQuotesView(isDesktop);
      default: return _buildPosView(isDesktop);
    }
  }

  // ==========================================
  // DASHBOARD VIEW
  // ==========================================
  Widget _buildDashboardView(bool isDesktop) {
    final pad = isDesktop ? 24.0 : 16.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todaysSales = _history.where((tx) => !tx.date.isBefore(today)).toList();
    final salesToday = todaysSales.fold(0.0, (sum, tx) => sum + tx.subtotal);
    final totalRev = _history.fold(0.0, (sum, tx) => sum + tx.subtotal);
    final totalExp = _expenses.fold(0.0, (sum, e) => sum + e.amount);
    final netProfit = totalRev - totalExp;
    final owed = _customers.fold(0.0, (sum, c) => sum + c.outstandingBalance);
    final lowStock = _inventory.where((p) => p.isLowStock).toList()..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

    final Map<DateTime, double> revByDay = {};
    for (int i = 6; i >= 0; i--) {
      revByDay[DateTime(now.year, now.month, now.day - i)] = 0;
    }
    final Map<String, double> revByDepartment = {};
    for (final tx in _history) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (revByDay.containsKey(day)) revByDay[day] = revByDay[day]! + tx.subtotal;
      for (final item in tx.items) {
        revByDepartment[item.product.category] = (revByDepartment[item.product.category] ?? 0) + item.totalPrice;
      }
    }

    final stats = <Widget>[
      _statBlock('Net profit', money(netProfit), Icons.account_balance, netProfit >= 0 ? AppColors.ok : AppColors.red),
      _statBlock('Owed by customers', money(owed), Icons.schedule, owed > 0 ? AppColors.warn : AppColors.muted, onTap: () => setState(() => _currentMenuIndex = 4)),
      _statBlock('Items to reorder', '${lowStock.length}', Icons.warning_amber_rounded, lowStock.isNotEmpty ? AppColors.warn : AppColors.muted, onTap: () => setState(() {
        _inventoryLowOnly = true;
        _inventoryCategory = 'All';
        _currentMenuIndex = 3;
      })),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _salesTodayBanner(salesToday, todaysSales.length, isDesktop),
          const SizedBox(height: 12),
          if (isDesktop)
            Row(children: [for (int i = 0; i < stats.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: stats[i])]])
          else
            Column(children: [for (final stat in stats) Padding(padding: const EdgeInsets.only(bottom: 8), child: stat)]),
          const SizedBox(height: 12),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildRevenueBarChart(revByDay, isDesktop)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildDepartmentSalesChart(revByDepartment)),
              ],
            )
          else ...[
            _buildRevenueBarChart(revByDay, isDesktop),
            const SizedBox(height: 12),
            _buildDepartmentSalesChart(revByDepartment),
          ],
          const SizedBox(height: 12),
          _buildReorderCard(lowStock),
        ],
      ),
    );
  }

  Widget _salesTodayBanner(double salesToday, int saleCount, bool isDesktop) {
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sales today, excl. VAT', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 6),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: GoldText(money(salesToday), style: AppText.display(isDesktop ? 58 : 46))),
        const SizedBox(height: 4),
        Text(saleCount == 1 ? '1 sale so far' : '$saleCount sales so far', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
    final outlineStyle = OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0x22FFFFFF), side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16));
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: () => setState(() => _currentMenuIndex = 1),
          icon: const Icon(Icons.point_of_sale, size: 18),
          label: const Text('New sale'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow, foregroundColor: AppColors.navy, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
        ),
        OutlinedButton.icon(onPressed: () => _productDialog(), icon: const Icon(Icons.add, size: 18), label: const Text('Add item'), style: outlineStyle),
        OutlinedButton.icon(onPressed: _addExpenseDialog, icon: const Icon(Icons.receipt, size: 18), label: const Text('Record expense'), style: outlineStyle),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isDesktop ? 26 : 18),
      decoration: BoxDecoration(
        gradient: AppGradients.banner,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.red.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: isDesktop
          ? Row(children: [Expanded(child: summary), Flexible(child: actions)])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [summary, const SizedBox(height: 16), actions]),
    );
  }

  Widget _statBlock(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(value, style: AppText.display(24, color: color == AppColors.muted ? AppColors.ink : color)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _panelDecoration => BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line));

  Widget _buildRevenueBarChart(Map<DateTime, double> revByDay, bool isDesktop) {
    double maxRev = revByDay.values.fold(0.0, (max, v) => v > max ? v : max);
    if (maxRev == 0) maxRev = 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales, last 7 days', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: isDesktop ? 220 : 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: revByDay.entries.map((e) {
                final isToday = e.key == revByDay.keys.last;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (e.value > 0)
                      Text(e.value >= 1000 ? '${(e.value / 1000).toStringAsFixed(1)}k' : e.value.toStringAsFixed(0), style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      width: isDesktop ? 34 : 22,
                      height: (isDesktop ? 160 : 100) * (e.value / maxRev),
                      decoration: BoxDecoration(color: isToday ? AppColors.red : AppColors.navy, borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(height: 8),
                    Text('${e.key.day}/${e.key.month}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentSalesChart(Map<String, double> revByDepartment) {
    final entries = revByDepartment.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales by department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text('Each department shows here after its first sale.', style: TextStyle(color: AppColors.muted)),
          ...entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(money(e.value), style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: e.value / total, minHeight: 8, backgroundColor: AppColors.ground, color: departmentFor(e.key).color),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReorderCard(List<Product> lowStock) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reorder soon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (lowStock.isEmpty)
            const Text('All items are above their reorder level.', style: TextStyle(color: AppColors.muted)),
          ...lowStock.take(6).map((p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(p.department.icon, color: p.department.color, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
                Text('${p.stockLabel} left', style: TextStyle(color: p.isOutOfStock ? AppColors.red : AppColors.warn, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                TextButton(onPressed: () => _adjustStockDialog(p), child: const Text('Restock')),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ==========================================
  // POS VIEW
  // ==========================================
  void _handleSearchSubmit(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    final lower = query.toLowerCase();
    Product? hit = _inventory.where((p) => p.barcode?.toLowerCase() == lower || p.id.toLowerCase() == lower).firstOrNull;
    if (hit == null) {
      final matches = _inventory.where((p) => p.matches(query)).toList();
      if (matches.length == 1) hit = matches.first;
    }
    if (hit != null) {
      _searchController.clear();
      setState(() {});
      _addToCart(hit);
    }
    _searchFocus.requestFocus();
  }

  Widget _buildPosView(bool isDesktop) {
    final pad = isDesktop ? 20.0 : 12.0;
    final query = _searchController.text;
    final displayedProducts = _inventory.where((p) => (_selectedCategory == 'All' || p.category == _selectedCategory) && p.matches(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: AppColors.surface,
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      decoration: InputDecoration(
                        hintText: isDesktop ? 'Search name, SKU or scan a barcode' : 'Search or scan',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: () { _searchController.clear(); setState(() {}); }),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _handleSearchSubmit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _addMiscItemDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isDesktop ? 'Custom item' : 'Custom'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _departmentBar(_selectedCategory, (name) => setState(() => _selectedCategory = name)),
            ],
          ),
        ),
        Expanded(
          child: displayedProducts.isEmpty
              ? (query.isEmpty
                  ? _emptyState(Icons.add_business, 'No items in this department yet.', actionLabel: 'Add item', onAction: () => _productDialog())
                  : _emptyState(Icons.search_off, 'No items match "$query".', actionLabel: 'Sell as custom item', onAction: _addMiscItemDialog))
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, isDesktop ? pad : 88),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: isDesktop ? 210 : 180, mainAxisExtent: 152, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: displayedProducts.length,
                  itemBuilder: (context, index) => _productTag(displayedProducts[index]),
                ),
        ),
      ],
    );
  }

  /// Horizontal row of aisle signs, one per department.
  Widget _departmentBar(String selected, ValueChanged<String> onSelect) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _aisleSign('All', Icons.apps, AppColors.navy, selected == 'All', () => onSelect('All')),
          ...departments.map((d) => _aisleSign(d.name, d.icon, d.color, selected == d.name, () => onSelect(d.name))),
        ],
      ),
    );
  }

  Widget _aisleSign(String name, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 8, 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.forColor(color) : null,
          color: isSelected ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.transparent : AppColors.line),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: isSelected ? Colors.white : color),
                  const SizedBox(width: 7),
                  Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.ink)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A product tile with a full-colour department band and a loud price.
  Widget _productTag(Product product) {
    final department = product.department;
    final inCart = _cart.where((item) => item.product.id == product.id).firstOrNull;
    final stockText = product.isOutOfStock ? 'Out of stock' : '${product.stockLabel} left';
    final stockColor = !product.isOutOfStock && product.isLowStock ? AppColors.yellow : Colors.white;
    final band = product.isOutOfStock ? const LinearGradient(colors: [Color(0xFF4A5560), Color(0xFF6B7681)]) : AppGradients.forColor(department.color);

    return GlowTile(
      onTap: () => _addToCart(product),
      glow: department.color,
      selected: inCart != null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(gradient: band),
            child: Row(
              children: [
                Icon(department.icon, size: 19, color: Colors.white),
                const SizedBox(width: 7),
                Expanded(child: Text(stockText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: stockColor, fontWeight: FontWeight.w700))),
                if (inCart != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.yellow, borderRadius: BorderRadius.circular(5)),
                    child: Text(inCart.qtyLabel, style: const TextStyle(fontSize: 13, color: AppColors.navy, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.25)),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(money(product.price), style: AppText.display(27, color: AppColors.red)),
                        if (product.unit != 'each') Text(' / ${product.unit}', style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message, {String? actionLabel, VoidCallback? onAction}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 16, fontWeight: FontWeight.w500)),
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pageHeader(String title, bool isDesktop, {String? subtitle, Widget? trailing}) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(isDesktop ? 38 : 30)),
                const SizedBox(height: 6),
                Container(width: 56, height: 5, decoration: BoxDecoration(gradient: AppGradients.hot, borderRadius: BorderRadius.circular(3))),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ==========================================
  // INVENTORY VIEW
  // ==========================================
  Widget _buildInventoryView(bool isDesktop) {
    final pad = isDesktop ? 24.0 : 16.0;
    final query = _inventorySearchController.text;
    final lowCount = _inventory.where((p) => p.isLowStock).length;
    final items = _inventory.where((p) =>
      (_inventoryCategory == 'All' || p.category == _inventoryCategory) &&
      (!_inventoryLowOnly || p.isLowStock) &&
      p.matches(query)
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageHeader('Inventory', isDesktop,
          subtitle: '${_inventory.length} items, $lowCount to reorder',
          trailing: ElevatedButton.icon(onPressed: () => _productDialog(), icon: const Icon(Icons.add, size: 18), label: const Text('Add item')),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inventorySearchController,
                  decoration: InputDecoration(hintText: isDesktop ? 'Search name, SKU or barcode' : 'Search or scan', prefixIcon: const Icon(Icons.search), isDense: true, filled: true, fillColor: AppColors.surface),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Low stock'),
                selected: _inventoryLowOnly,
                selectedColor: AppColors.yellow,
                backgroundColor: AppColors.surface,
                onSelected: (val) => setState(() => _inventoryLowOnly = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: _departmentBar(_inventoryCategory, (name) => setState(() => _inventoryCategory = name)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? _emptyState(Icons.inventory_2_outlined, 'No items match these filters.')
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _inventoryRow(items[index], isDesktop),
                ),
        ),
      ],
    );
  }

  Widget _inventoryRow(Product p, bool isDesktop) {
    final department = p.department;
    final stockColor = p.isOutOfStock ? AppColors.red : (p.isLowStock ? AppColors.warn : AppColors.muted);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.line)),
      child: Row(
        children: [
          Icon(department.icon, color: department.color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 3),
                Text('${p.stockLabel} in stock', style: TextStyle(fontSize: 13, color: stockColor, fontWeight: FontWeight.w500)),
                Text('SKU ${p.id}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(p.priceLabel, style: AppText.display(isDesktop ? 22 : 18)),
          const SizedBox(width: 4),
          IconButton(tooltip: 'Adjust stock', icon: const Icon(Icons.add_box_outlined, color: AppColors.navy), onPressed: () => _adjustStockDialog(p)),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_vert, color: AppColors.muted),
            onSelected: (val) {
              if (val == 'edit') _productDialog(p);
              if (val == 'delete') _deleteProduct(p);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit item')),
              PopupMenuItem(value: 'delete', child: Text('Delete item')),
            ],
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

    List<OrderTransaction> filteredHistory = _history.where((tx) {
      String query = _ledgerSearchController.text.toLowerCase();
      return tx.id.toLowerCase().contains(query) ||
             (tx.customerName?.toLowerCase().contains(query) ?? false) ||
             (tx.businessName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader('Sales', isDesktop,
            subtitle: 'Every sale, with receipts and unpaid orders.',
            trailing: isDesktop ? SizedBox(width: 300, child: _ledgerSearchField()) : null,
          ),
          if (!isDesktop) Padding(
            padding: EdgeInsets.symmetric(horizontal: screenPadding),
            child: _ledgerSearchField(),
          ),
          Expanded(
            child: filteredHistory.isEmpty
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
                      mainAxisExtent: 240,
                      crossAxisSpacing: isDesktop ? 20 : 12,
                      mainAxisSpacing: isDesktop ? 20 : 12,
                    ),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final tx = filteredHistory[index];
                      int itemCount = tx.items.length;
                      MaterialColor statusColor = tx.paymentStatus == 'Paid' ? Colors.green : Colors.orange;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.line),
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
                                                decoration: BoxDecoration(color: AppColors.redTint, borderRadius: BorderRadius.circular(6)),
                                                child: Text(tx.id, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 10)),
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
                                    Text('R ${tx.total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isDesktop ? 20 : 18, color: AppColors.ink)),
                                    const SizedBox(height: 4),
                                    Text('${tx.date.day}/${tx.date.month}/${tx.date.year} at ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                                    
                                    if (tx.customerName != null || tx.businessName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text('${tx.customerName ?? ''} ${tx.businessName != null ? '(${tx.businessName})' : ''}', style: const TextStyle(color: AppColors.red, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ),

                                    const SizedBox(height: 4),
                                    Text('$itemCount line${itemCount == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
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
                                              decoration: BoxDecoration(color: AppColors.redTint, borderRadius: BorderRadius.circular(10)),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.download, size: 16, color: AppColors.red),
                                                  SizedBox(width: 4),
                                                  Text('Docs', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.bold))
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

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader('Customers', isDesktop,
            subtitle: 'Accounts and what they owe.',
            trailing: ElevatedButton.icon(onPressed: () => _addOrEditCustomerDialog(), icon: const Icon(Icons.person_add, size: 18), label: Text(isDesktop ? 'Add customer' : 'Add')),
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
                          border: Border.all(color: AppColors.line),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          tilePadding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 8),
                          leading: CircleAvatar(backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1), radius: 20, child: Text(c.name[0].toUpperCase(), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16))),
                          title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: isDesktop ? 16 : 14)),
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
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: () => _deleteCustomer(c),
                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                      label: const Text('Remove Customer Profile', style: TextStyle(fontSize: 12, color: Colors.red)),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                    ),
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
    double totalExpenses = _expenses.fold(0, (sum, exp) => sum + exp.amount);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader('Expenses', isDesktop,
            subtitle: 'Recorded: ${money(totalExpenses)}',
            trailing: ElevatedButton.icon(onPressed: _addExpenseDialog, icon: const Icon(Icons.add, size: 18), label: Text(isDesktop ? 'Record expense' : 'Add')),
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
                          border: Border.all(color: AppColors.line),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 16, vertical: 8),
                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.money_off, color: Colors.red.shade400, size: 24)),
                          title: Text(exp.description, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: isDesktop ? 16 : 14)),
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

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHeader('Reports', isDesktop, subtitle: 'Create a PDF to print or share.'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenPadding),
              child: Builder(builder: (context) {
                final now = DateTime.now();
                final startOfDay = DateTime(now.year, now.month, now.day);
                final startOfMonth = DateTime(now.year, now.month);
                final cards = [
                  _buildReportGeneratorCard('Daily cash-up', 'All of today\'s sales and expenses.', Icons.today,
                    () => PdfGenerator.generateFinancialReportPdf('End of Day Report (Today)', _history.where((tx) => !tx.date.isBefore(startOfDay)).toList(), _expenses.where((e) => !e.date.isBefore(startOfDay)).toList(), _storeName)),
                  _buildReportGeneratorCard('Monthly summary', 'Profit and loss for this month.', Icons.calendar_month,
                    () => PdfGenerator.generateFinancialReportPdf('Monthly Profit & Loss Statement', _history.where((tx) => !tx.date.isBefore(startOfMonth)).toList(), _expenses.where((e) => !e.date.isBefore(startOfMonth)).toList(), _storeName)),
                  _buildReportGeneratorCard('Reorder list', 'Every item at or below its reorder level.', Icons.playlist_add_check,
                    () => PdfGenerator.printReorderList(_inventory.where((p) => p.isLowStock).toList(), _storeName)),
                ];
                return isDesktop
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (int i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: cards[i])]])
                    : Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: card)]);
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportGeneratorCard(String title, String desc, IconData icon, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.redTint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: AppColors.red, size: 32)),
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
          _pageHeader('Settings', isDesktop, subtitle: 'Store details printed on receipts and invoices.'),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenPadding),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.line)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Global Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink)),
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade100)),
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
  Widget _buildBrandBlock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
      child: Row(
        children: [
          const SolumateLogo(size: 58),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: GoldText('Solumate', style: AppText.display(30))),
                const Text('Business OS', maxLines: 1, style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final lowCount = _inventory.where((p) => p.isLowStock).length;
    return Container(
      width: 224,
      decoration: const BoxDecoration(gradient: AppGradients.sidebar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrandBlock(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSidebarItem(Icons.point_of_sale, 'Point of Sale', 1),
                  _buildSidebarItem(Icons.bar_chart, 'Dashboard', 0),
                  _buildSidebarItem(Icons.receipt_long, 'Sales', 2),
                  _buildSidebarItem(Icons.request_quote, 'Quotes', 8),
                  const Divider(color: Colors.white24, indent: 20, endIndent: 20, height: 24),
                  _buildSidebarItem(Icons.inventory_2, 'Inventory', 3, badge: lowCount > 0 ? '$lowCount' : null),
                  _buildSidebarItem(Icons.people, 'Customers', 4),
                  _buildSidebarItem(Icons.account_balance_wallet, 'Expenses', 5),
                  const Divider(color: Colors.white24, indent: 20, endIndent: 20, height: 24),
                  _buildSidebarItem(Icons.analytics, 'Reports', 6),
                  _buildSidebarItem(Icons.settings, 'Settings', 7),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: AppColors.navyRaised, radius: 17, child: Text('MW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('M. Wajah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    Text('Admin', style: TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, int index, {String? badge}) {
    final isActive = _currentMenuIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          gradient: isActive ? AppGradients.gold : null,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [BoxShadow(color: AppColors.orange.withValues(alpha: 0.6), blurRadius: 14, offset: const Offset(0, 4))] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              setState(() => _currentMenuIndex = index);
              if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: isActive ? AppColors.navyDeep : Colors.white70, size: 21),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: TextStyle(color: isActive ? AppColors.navyDeep : Colors.white, fontWeight: isActive ? FontWeight.w800 : FontWeight.w500, fontSize: 15))),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: isActive ? AppColors.navyDeep : AppColors.red, borderRadius: BorderRadius.circular(5)),
                      child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartPanel({bool inSheet = false}) {
    return Container(
      width: inSheet ? double.infinity : 380,
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(left: BorderSide(color: AppColors.line))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
            child: Row(
              children: [
                Expanded(child: Text('Current order', style: AppText.display(24))),
                if (_cart.isNotEmpty) TextButton(onPressed: _clearCart, child: const Text('Clear order', style: TextStyle(color: AppColors.red))),
              ],
            ),
          ),
          if (_loadedQuote != null)
            Container(
              width: double.infinity,
              color: AppColors.yellow,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Text('From quote ${_loadedQuote!.id}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: _cart.isEmpty
                ? _emptyState(Icons.shopping_basket_outlined, 'Tap an item to start an order.')
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.line),
                    itemBuilder: (context, index) => _cartLine(_cart[index]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('VAT ${(_globalVatRate * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted)),
                    Switch(value: _applyVat, onChanged: (val) => _updateState(() => _applyVat = val)),
                    const Spacer(),
                    TextButton.icon(onPressed: _addDiscountDialog, icon: const Icon(Icons.sell_outlined, size: 18), label: const Text('Discount')),
                  ],
                ),
                _totalRow('Subtotal', money(_subTotal)),
                if (_discountAmount > 0) _totalRow('Discount', '-${money(_discountAmount)}', color: AppColors.red),
                if (_applyVat) _totalRow('VAT', money(_vatAmount)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.navyDeep, Color(0xFF2A1238)]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppText.display(24, color: Colors.white)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(money(_grandTotal), style: AppText.display(42, color: AppColors.yellow).copyWith(shadows: [Shadow(color: AppColors.orange.withValues(alpha: 0.9), blurRadius: 16)])),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _cart.isEmpty ? null : _saveQuoteDialog,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), padding: const EdgeInsets.symmetric(horizontal: 16)),
                      child: const Text('Save quote'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: FlashButton(label: 'Checkout', onPressed: _cart.isEmpty ? null : _showCheckoutDialog)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Color color = AppColors.muted}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 14)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _cartLine(CartItem item) {
    Widget stepButton(IconData icon, String tooltip, VoidCallback onTap) => IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: AppColors.navy),
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              const SizedBox(width: 10),
              Text(money(item.totalPrice), style: AppText.display(18)),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text(item.product.priceLabel, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
              Container(
                decoration: BoxDecoration(color: AppColors.ground, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    stepButton(Icons.remove, 'Reduce quantity', () => _updateQuantity(item, -1)),
                    InkWell(
                      onTap: () => _editQuantityDialog(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        child: Text(item.qtyLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                    stepButton(Icons.add, 'Increase quantity', () => _updateQuantity(item, 1)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ledgerSearchField() {
    return TextField(
      controller: _ledgerSearchController,
      decoration: const InputDecoration(hintText: 'Search by order number or customer', prefixIcon: Icon(Icons.search), isDense: true, filled: true, fillColor: AppColors.surface),
      onChanged: (_) => setState(() {}),
    );
  }

  // ==========================================
  // QUOTES
  // ==========================================

  Future<void> _saveQuoteDialog() async {
    Customer? selectedCustomer = _customers.where((c) => c.id == _loadedQuote?.customerId).firstOrNull;
    final nameCtrl = TextEditingController(text: _loadedQuote?.customerName);
    final businessCtrl = TextEditingController(text: _loadedQuote?.businessName);
    int validDays = 14;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Save quote'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_customers.isNotEmpty) ...[
                  DropdownButtonFormField<Customer?>(
                    initialValue: selectedCustomer,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Existing customer'),
                    items: [
                      const DropdownMenuItem<Customer?>(value: null, child: Text('New customer')),
                      ..._customers.map((c) => DropdownMenuItem<Customer?>(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setDialogState(() {
                      selectedCustomer = val;
                      nameCtrl.text = val?.name ?? '';
                      businessCtrl.text = val?.businessName ?? '';
                    }),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Customer name')),
                const SizedBox(height: 12),
                TextField(controller: businessCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Business name (optional)')),
                const SizedBox(height: 16),
                const Text('Valid for', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [7, 14, 30].map((days) => ChoiceChip(
                    label: Text('$days days'),
                    selected: validDays == days,
                    onSelected: (_) => setDialogState(() => validDays = days),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final now = DateTime.now();
                final name = nameCtrl.text.trim();
                final business = businessCtrl.text.trim();
                final quote = Quote(
                  id: 'QTE-${now.millisecondsSinceEpoch.toString().substring(7)}',
                  date: now,
                  validUntil: now.add(Duration(days: validDays)),
                  total: _grandTotal,
                  subtotal: _subTotal,
                  discount: _discountAmount,
                  vat: _vatAmount,
                  items: _cart.map((item) => CartItem(product: Product.fromJson(item.product.toJson()), quantity: item.quantity)).toList(),
                  includesVat: _applyVat,
                  customerId: selectedCustomer?.id,
                  customerName: name.isEmpty ? null : name,
                  businessName: business.isEmpty ? null : business,
                );
                setState(() => _quotes.insert(0, quote));
                _saveQuotesToDatabase();
                Navigator.pop(dialogContext);
                if (_cartSheetSetState != null) Navigator.pop(context);
                _clearCart();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Quote ${quote.id} saved.'),
                  width: MediaQuery.of(context).size.width > 980 ? 360 : null,
                  action: SnackBarAction(label: 'Open PDF', onPressed: () => _printQuote(quote)),
                ));
              },
              child: const Text('Save quote'),
            ),
          ],
        ),
      ),
    );
  }

  void _printQuote(Quote quote) => PdfGenerator.printQuote(quote, _storeName, _storeAddress, _storePhone, _storeEmail, _globalVatRate);

  Future<void> _loadQuote(Quote quote) async {
    if (_cart.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace current order?'),
          content: const Text('The items in the current order will be removed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep order')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Replace order')),
          ],
        ),
      );
      if (replace != true) return;
    }
    _updateState(() {
      _cart
        ..clear()
        ..addAll(quote.items.map((item) => CartItem(product: Product.fromJson(item.product.toJson()), quantity: item.quantity)));
      _discountAmount = quote.discount;
      _applyVat = quote.includesVat;
      _loadedQuote = quote;
      _currentMenuIndex = 1;
    });
  }

  Future<void> _deleteQuote(Quote quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete quote'),
        content: Text('Delete quote ${quote.id}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete quote')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _quotes.remove(quote));
      _saveQuotesToDatabase();
    }
  }

  Widget _buildQuotesView(bool isDesktop) {
    final pad = isDesktop ? 24.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pageHeader('Quotes', isDesktop, subtitle: 'Priced orders waiting for a customer to go ahead.'),
        Expanded(
          child: _quotes.isEmpty
              ? _emptyState(Icons.request_quote_outlined, 'No quotes yet. Add items to an order and choose Save quote.', actionLabel: 'Go to Point of Sale', onAction: () => setState(() => _currentMenuIndex = 1))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 4),
                  itemCount: _quotes.length,
                  itemBuilder: (context, index) => _quoteRow(_quotes[index]),
                ),
        ),
      ],
    );
  }

  Widget _quoteRow(Quote quote) {
    final converted = quote.status == 'Converted';
    final expired = !converted && quote.isExpired;
    final statusText = converted ? 'Converted to sale' : (expired ? 'Expired' : 'Open');
    final statusColor = converted ? AppColors.ok : (expired ? AppColors.red : AppColors.navy);
    final validUntil = quote.validUntil;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote.customerName ?? quote.businessName ?? 'Walk-in customer', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text('${quote.id}, ${quote.items.length} line${quote.items.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    if (validUntil != null) Text('Valid until ${validUntil.day}/${validUntil.month}/${validUntil.year}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(quote.total), style: AppText.display(24)),
                  const SizedBox(height: 3),
                  Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!converted && !expired) ElevatedButton(onPressed: () => _loadQuote(quote), child: const Text('Sell this quote')),
              OutlinedButton(onPressed: () => _printQuote(quote), child: const Text('Open PDF')),
              TextButton(onPressed: () => _deleteQuote(quote), child: const Text('Delete', style: TextStyle(color: AppColors.red))),
            ],
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(Customer c) {
    setState(() {
      _customers.remove(c);
      // We nullify the customer reference in the ledger to preserve history 
      // without trying to link to a profile that no longer exists.
      for (var tx in _history) {
        if (tx.customerId == c.id) tx.customerId = null;
      }
    });
    _saveCustomersToDatabase();
    _saveHistoryToDatabase();
  }
}