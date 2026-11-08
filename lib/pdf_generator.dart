import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'departments.dart';
import 'models.dart';

class PdfGenerator {
  
  static Future<void> printReceipt(OrderTransaction tx, String storeName, double globalVatRate) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page( 
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('Hardware & Industrial Supplies')),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Text('Order: #${tx.id}'),
              pw.Text('Date: ${tx.date.day}/${tx.date.month}/${tx.date.year} ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}'),
              pw.Text('Payment: ${tx.paymentMethod}'),
              if (tx.customerName != null) pw.Text('Customer: ${tx.customerName}'),
              if (tx.businessName != null) pw.Text('Business: ${tx.businessName}'),
              pw.Divider(),
              ...tx.items.map((item) => pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Text('${item.qtyLabel} x ${item.product.name}', style: const pw.TextStyle(fontSize: 10))),
                  pw.Text('R ${item.totalPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                ],
              )),
              pw.Divider(),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:'), pw.Text('R ${tx.subtotal.toStringAsFixed(2)}')]),
              if (tx.discount > 0)
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount:', style: const pw.TextStyle(color: PdfColors.red)), pw.Text('-R ${tx.discount.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red))]),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VAT (${tx.includesVat ? "${(globalVatRate*100).toInt()}%" : "Exempt"}):'), pw.Text('R ${tx.vat.toStringAsFixed(2)}')]),
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
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Receipt_${tx.id}.pdf');
  }

  static Future<void> printInvoice(OrderTransaction tx, String storeName, String storeAddress, String storePhone, String storeEmail, double globalVatRate) async {
    final doc = _salesDocument(
      storeName: storeName, storeAddress: storeAddress, storePhone: storePhone, storeEmail: storeEmail,
      title: 'TAX INVOICE',
      billedToLabel: 'BILLED TO:',
      headerLines: [
        pw.Text('Invoice #: ${tx.id}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Date: ${_date(tx.date)}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Method: ${tx.paymentMethod}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Status: ${tx.paymentStatus}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: tx.paymentStatus == 'Paid' ? PdfColors.green700 : PdfColors.orange700)),
      ],
      customerName: tx.customerName, businessName: tx.businessName,
      items: tx.items, subtotal: tx.subtotal, discount: tx.discount, vat: tx.vat, total: tx.total, includesVat: tx.includesVat, vatRate: globalVatRate,
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Invoice_${tx.id}.pdf');
  }

  static Future<void> printQuote(Quote quote, String storeName, String storeAddress, String storePhone, String storeEmail, double globalVatRate) async {
    final validUntil = quote.validUntil;
    final doc = _salesDocument(
      storeName: storeName, storeAddress: storeAddress, storePhone: storePhone, storeEmail: storeEmail,
      title: 'QUOTATION',
      billedToLabel: 'QUOTED TO:',
      headerLines: [
        pw.Text('Quote #: ${quote.id}', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Date: ${_date(quote.date)}', style: const pw.TextStyle(fontSize: 12)),
        if (validUntil != null) pw.Text('Valid until: ${_date(validUntil)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
      customerName: quote.customerName, businessName: quote.businessName,
      items: quote.items, subtotal: quote.subtotal, discount: quote.discount, vat: quote.vat, total: quote.total, includesVat: quote.includesVat, vatRate: globalVatRate,
      footnote: 'Stock is subject to availability at the time of purchase.',
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Quote_${quote.id}.pdf');
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  /// Builds an invoice or quote. Uses MultiPage so long trade orders flow
  /// onto extra pages instead of being cut off.
  static pw.Document _salesDocument({
    required String storeName, required String storeAddress, required String storePhone, required String storeEmail,
    required String title, required String billedToLabel, required List<pw.Widget> headerLines,
    required String? customerName, required String? businessName,
    required List<CartItem> items, required double subtotal, required double discount, required double vat, required double total, required bool includesVat, required double vatRate,
    String? footnote,
  }) {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(storeName, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  pw.Text('Hardware & Industrial Supplies', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.Text(storePhone, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.Text(storeEmail, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey400)),
                  pw.SizedBox(height: 8),
                  ...headerLines,
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 32),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(billedToLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(customerName ?? 'Cash Customer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (businessName != null) pw.Text(businessName, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 4, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text('Unit Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ],
            ),
          ),
          ...items.map((item) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 4, child: pw.Text(item.product.name)),
                pw.Expanded(flex: 1, child: pw.Text(item.qtyLabel, textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 2, child: pw.Text(item.product.priceLabel, textAlign: pw.TextAlign.right)),
                pw.Expanded(flex: 2, child: pw.Text('R ${item.totalPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right)),
              ],
            ),
          )),
          pw.SizedBox(height: 20),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:'), pw.Text('R ${subtotal.toStringAsFixed(2)}')]),
                    if (discount > 0) pw.SizedBox(height: 4),
                    if (discount > 0) pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount:', style: const pw.TextStyle(color: PdfColors.red)), pw.Text('-R ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red))]),
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VAT (${includesVat ? "${(vatRate * 100).toInt()}%" : "Exempt"}):'), pw.Text('R ${vat.toStringAsFixed(2)}')]),
                    pw.Divider(color: PdfColors.grey400),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Grand Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      pw.Text('R ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.red900)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (footnote != null) ...[
            pw.SizedBox(height: 16),
            pw.Text(footnote, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ],
      ),
    );
    return doc;
  }

  static Future<void> printBusinessCopy(OrderTransaction tx, String storeName) async {
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
                        pw.Text(storeName, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                        pw.Text('INTERNAL BUSINESS RECORD', style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PICK SLIP / WAYBILL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey400)),
                        pw.SizedBox(height: 8),
                        pw.Text('Order #: ${tx.id}', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Date: ${tx.date.day}/${tx.date.month}/${tx.date.year}', style: const pw.TextStyle(fontSize: 12)),
                      ]
                    )
                  ]
                ),
                pw.SizedBox(height: 40),
                
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('ORDER FOR:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                      pw.SizedBox(height: 4),
                      pw.Text(tx.customerName ?? 'Cash Customer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (tx.businessName != null) pw.Text(tx.businessName!, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  )
                ),
                pw.SizedBox(height: 20),

                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 1, child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 4, child: pw.Text('Product Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 1, child: pw.Text('Check', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ]
                  )
                ),
                pw.SizedBox(height: 8),
                ...tx.items.map((item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 1, child: pw.Text(item.qtyLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16))),
                      pw.Expanded(flex: 4, child: pw.Text(item.product.name)),
                      pw.Expanded(flex: 1, child: pw.Container(height: 14, width: 14, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)))),
                    ]
                  )
                )),
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Prepared By: _________________________'),
                        pw.SizedBox(height: 20),
                        pw.Text('Date: _________________________'),
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Received By: _________________________'),
                        pw.SizedBox(height: 20),
                        pw.Text('Date: _________________________'),
                      ]
                    )
                  ]
                )
              ]
            )
          );
        },
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Business_Waybill_${tx.id}.pdf');
  }

  static Future<void> generateFinancialReportPdf(String periodTitle, List<OrderTransaction> history, List<Expense> expenses, String storeName) async {
    double totalRev = history.fold(0, (sum, tx) => sum + tx.subtotal); 
    double totalExp = expenses.fold(0, (sum, e) => sum + e.amount);
    double netProfit = totalRev - totalExp;

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
                pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.Text('FINANCIAL REPORT', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                pw.SizedBox(height: 8),
                pw.Text('Report Type: $periodTitle', style: const pw.TextStyle(fontSize: 12)),
                pw.Text('Generated On: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 30),
                
                pw.Text('EXECUTIVE SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Gross Revenue (Ex VAT):'), pw.Text('R ${totalRev.toStringAsFixed(2)}')]),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Expenses:'), pw.Text('R ${totalExp.toStringAsFixed(2)}')]),
                pw.Divider(),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('NET PROFIT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('R ${netProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: netProfit >= 0 ? PdfColors.green700 : PdfColors.red700))]),
                
                pw.SizedBox(height: 30),
                pw.Text('RECENT TRANSACTIONS (Top 10)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                ...history.take(10).map((tx) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${tx.date.day}/${tx.date.month} - ${tx.id} (${tx.paymentStatus})', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('R ${tx.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                    ]
                  )
                )),

                pw.SizedBox(height: 30),
                pw.Text('RECENT EXPENSES (Top 10)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                ...expenses.take(10).map((exp) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${exp.date.day}/${exp.date.month} - ${exp.description} (${exp.category})', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('R ${exp.amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                    ]
                  )
                )),
              ]
            )
          );
        }
      )
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Financial_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<void> printReorderList(List<Product> products, String storeName) async {
    final sorted = [...products]..sort((a, b) => a.category == b.category ? a.name.compareTo(b.name) : a.category.compareTo(b.category));
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          pw.Text(storeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          pw.Text('REORDER LIST', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
          pw.Text('Generated on: ${_date(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          if (sorted.isEmpty) pw.Text('All items are above their reorder level.'),
          if (sorted.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: ['SKU', 'Item', 'Department', 'In stock', 'Reorder at'],
              data: sorted.map((p) => [p.id, p.name, p.category, p.stockLabel, formatQty(p.reorderPoint)]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Reorder_List_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }
}