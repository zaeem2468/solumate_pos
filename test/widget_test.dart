import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solumate_pos/catalog.dart';
import 'package:solumate_pos/departments.dart';
import 'package:solumate_pos/main.dart';
import 'package:solumate_pos/models.dart';
import 'package:solumate_pos/theme.dart';

Future<void> pumpPos(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const PosScreen()));
  await tester.pumpAndSettle();
}

Map<String, dynamic> legacyProductJson() => {
  'id': 'CUSTOM-1',
  'name': 'Old Thinner',
  'price': 10,
  'category': 'Thinners',
  'color': 0xFF607D8B,
  'stockQuantity': 3,
};

/// Products a shop entered itself, used by the selling tests.
String shopInventory() => jsonEncode([
  Product(id: 'BIB', name: 'Bib Tap Brass 15mm', price: 89, category: 'Plumbing', stockQuantity: 24),
  Product(id: 'CAB', name: 'Twin and Earth Cable 2.5mm', price: 22, category: 'Electrical', unit: 'm', stockQuantity: 250),
].map((p) => p.toJson()).toList());

Future<List<dynamic>> savedInventory() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString('solumate_inventory')!) as List;
}

void main() {
  group('quantities and search', () {
    test('formatQty drops only trailing zeros', () {
      expect(formatQty(2), '2');
      expect(formatQty(10), '10');
      expect(formatQty(2.5), '2.5');
      expect(formatQty(0.25), '0.25');
    });

    test('parseNumber accepts a decimal comma', () {
      expect(parseNumber('2,5'), 2.5);
      expect(parseNumber(' 2.5 '), 2.5);
      expect(parseNumber('abc'), isNull);
    });

    test('matches every word in any order, across name and SKU', () {
      final tap = Product(id: 'PLB-TAP-BIB15', name: 'Bib Tap Brass 15mm', price: 89, category: 'Plumbing', barcode: '6001234');
      expect(tap.matches('15mm tap'), isTrue);
      expect(tap.matches('plb-tap'), isTrue);
      expect(tap.matches('6001234'), isTrue);
      expect(tap.matches('tap 22mm'), isFalse);
    });
  });

  group('starter products and saved data', () {
    test('old paint categories move to Paint & Solvents', () {
      final product = Product.fromJson(legacyProductJson());
      expect(product.category, 'Paint & Solvents');
      expect(product.unit, 'each');
    });

    test('whole-number cart quantities still load', () {
      final item = CartItem.fromJson({'product': legacyProductJson(), 'quantity': 3});
      expect(item.quantity, 3.0);
      expect(item.totalPrice, 30.0);
    });

    testWidgets('a new install starts with only the paint products', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPos(tester, const Size(1366, 800));

      final saved = await savedInventory();
      expect(saved.length, 12);
      expect(saved.every((p) => p['category'] == 'Paint & Solvents'), isTrue);
    });

    testWidgets('sample hardware is cleared once, keeping everything else', (tester) async {
      SharedPreferences.setMockInitialValues({
        'solumate_hardware_catalog_v1': true,
        'solumate_inventory': jsonEncode([
          Product(id: 'PLB-TAP-BIB15', name: 'Bib Tap Brass 15mm', price: 89, category: 'Plumbing').toJson(),
          paintStarterProducts().first.toJson(),
          legacyProductJson(),
        ]),
      });
      await pumpPos(tester, const Size(1366, 800));

      expect((await savedInventory()).map((p) => p['id']), unorderedEquals(['LCQ-750', 'CUSTOM-1']));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('solumate_hardware_catalog_v1'), isFalse);
    });

    testWidgets('items a shop adds itself are never treated as samples', (tester) async {
      SharedPreferences.setMockInitialValues({'solumate_inventory': shopInventory()});
      await pumpPos(tester, const Size(1366, 800));
      expect((await savedInventory()).length, 2);
    });
  });

  group('selling', () {
    setUp(() => SharedPreferences.setMockInitialValues({'solumate_inventory': shopInventory()}));

    testWidgets('cable sells by the metre with a decimal comma', (tester) async {
      await pumpPos(tester, const Size(1366, 800));
      await tester.tap(find.text('Twin and Earth Cable 2.5mm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '2,5');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to order'));
      await tester.pumpAndSettle();

      expect(find.text('2.5 m'), findsWidgets);
      expect(find.text('R 55.00'), findsWidgets); // 2.5 x R 22.00
      expect(find.text('R 63.25'), findsOneWidget); // with 15% VAT
    });

    testWidgets('a saved quote can be sold, and takes the stock off', (tester) async {
      await pumpPos(tester, const Size(1366, 800));
      await tester.tap(find.text('Bib Tap Brass 15mm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save quote'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Customer name'), 'Sipho Builders');
      await tester.tap(find.text('Save quote').last);
      await tester.pumpAndSettle();
      expect(find.text('Tap an item to start an order.'), findsOneWidget);

      await tester.tap(find.text('Quotes'));
      await tester.pumpAndSettle();
      expect(find.text('Sipho Builders'), findsOneWidget);
      await tester.tap(find.text('Sell this quote'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Paid'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('23 left'), findsOneWidget); // started at 24
      await tester.tap(find.text('Quotes'));
      await tester.pumpAndSettle();
      expect(find.text('Converted to sale'), findsOneWidget);
    });

    testWidgets('one tap on + in the phone cart adds exactly one', (tester) async {
      await pumpPos(tester, const Size(390, 844));
      await tester.tap(find.text('Bib Tap Brass 15mm'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();

      expect(find.text('R 178.00'), findsNWidgets(2)); // 2 x R 89.00, as line total and subtotal
    });
  });
}
