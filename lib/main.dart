import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as ex;

void main() {
  runApp(const StoreInventoryApp());
}

class StoreInventoryApp extends StatelessWidget {
  const StoreInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store & JP Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ---------------- MODELS ----------------
class Item {
  String id;
  String name;
  String unit;
  double stock;

  Item({required this.id, required this.name, required this.unit, required this.stock});
}

class JobPerformer {
  String id;
  String name;
  String phone;

  JobPerformer({required this.id, required this.name, required this.phone});
}

class IssuedItem {
  String itemId;
  String itemName;
  String unit;
  double qty;

  IssuedItem({required this.itemId, required this.itemName, required this.unit, required this.qty});
}

class IssueSlip {
  String id;
  String jpId;
  String jpName;
  DateTime date;
  List<IssuedItem> items;

  IssueSlip({
    required this.id,
    required this.jpId,
    required this.jpName,
    required this.date,
    required this.items,
  });
}

class RequisitionItem {
  String itemId;
  String itemName;
  String unit;
  double requestedQty;
  double receivedQty;

  RequisitionItem({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.requestedQty,
    this.receivedQty = 0,
  });
}

class StockRequisition {
  String id;
  DateTime date;
  String status;
  List<RequisitionItem> items;

  StockRequisition({
    required this.id,
    required this.date,
    required this.status,
    required this.items,
  });
}

// ---------------- GLOBAL DATA STORE ----------------
class AppData {
  static final AppData instance = AppData._();
  AppData._();

  List<Item> items = [
    Item(id: '1', name: 'GI Pipe 1/2"', unit: 'Mtr', stock: 120),
    Item(id: '2', name: 'Cable 4mm', unit: 'Coil', stock: 15),
    Item(id: '3', name: 'Circuit Breaker 16A', unit: 'Pcs', stock: 45),
    Item(id: '4', name: 'Insulation Tape', unit: 'Roll', stock: 80),
  ];

  List<JobPerformer> jps = [
    JobPerformer(id: 'jp1', name: 'Tariq Mehmood', phone: '0300-1234567'),
    JobPerformer(id: 'jp2', name: 'Muhammad Rashid', phone: '0312-9876543'),
  ];

  List<IssueSlip> issueSlips = [];
  List<StockRequisition> requisitions = [];
}

// ---------------- MAIN BOTTOM NAV ----------------
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const JPListScreen(),
    const ItemsStockScreen(),
    const RequisitionScreen(),
    const ReportsAndSearchScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_shared), label: 'JP Folders'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Stock Items'),
          NavigationDestination(icon: Icon(Icons.local_shipping), label: 'Store Requests'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'Reports & Search'),
        ],
      ),
    );
  }
}

// ---------------- SMART QUANTITY STEPPER WIDGET ----------------
class SmartQtyStepper extends StatefulWidget {
  final double initialValue;
  final double maxValue;
  final ValueChanged<double> onChanged;

  const SmartQtyStepper({
    super.key,
    required this.initialValue,
    this.maxValue = 999999,
    required this.onChanged,
  });

  @override
  State<SmartQtyStepper> createState() => _SmartQtyStepperState();
}

class _SmartQtyStepperState extends State<SmartQtyStepper> {
  late double _qty;
  Timer? _timer;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialValue;
    _textController = TextEditingController(text: _qty.toStringAsFixed(_qty % 1 == 0 ? 0 : 2));
  }

  void _update(double val) {
    if (val < 0) val = 0;
    if (val > widget.maxValue) val = widget.maxValue;
    setState(() {
      _qty = val;
      _textController.text = _qty.toStringAsFixed(_qty % 1 == 0 ? 0 : 2);
    });
    widget.onChanged(_qty);
  }

  void _startHold(double delta) {
    _update(_qty + delta);
    int speed = 180;
    _timer = Timer.periodic(Duration(milliseconds: speed), (t) {
      _update(_qty + delta);
      if (t.tick > 8 && speed > 40) {
        speed = 40;
      }
    });
  }

  void _stopHold() {
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onLongPressStart: (_) => _startHold(-1),
          onLongPressEnd: (_) => _stopHold(),
          child: IconButton.filledTonal(
            onPressed: () => _update(_qty - 1),
            icon: const Icon(Icons.keyboard_arrow_down, size: 22),
          ),
        ),
        SizedBox(
          width: 65,
          child: TextField(
            controller: _textController,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            onChanged: (text) {
              double? parsed = double.tryParse(text);
              if (parsed != null) {
                _qty = parsed;
                widget.onChanged(_qty);
              }
            },
          ),
        ),
        GestureDetector(
          onLongPressStart: (_) => _startHold(1),
          onLongPressEnd: (_) => _stopHold(),
          child: IconButton.filledTonal(
            onPressed: () => _update(_qty + 1),
            icon: const Icon(Icons.keyboard_arrow_up, size: 22),
          ),
        ),
      ],
    );
  }
}

// ---------------- 1. JP FOLDERS & ISSUE SCREEN ----------------
class JPListScreen extends StatefulWidget {
  const JPListScreen({super.key});

  @override
  State<JPListScreen> createState() => _JPListScreenState();
}

class _JPListScreenState extends State<JPListScreen> {
  void _addJPDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Job Performer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone / ID')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  AppData.instance.jps.add(
                    JobPerformer(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add JP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jps = AppData.instance.jps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Performers (JP Folders)'),
        centerTitle: true,
      ),
      body: jps.isEmpty
          ? const Center(child: Text('No JP added yet. Tap + to add.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: jps.length,
              itemBuilder: (ctx, i) {
                final jp = jps[i];
                final slips = AppData.instance.issueSlips.where((s) => s.jpId == jp.id).length;
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: const Icon(Icons.folder, color: Colors.indigo),
                    ),
                    title: Text(jp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text('ID/Phone: ${jp.phone} • History: $slips slips'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => JPDetailScreen(jp: jp)),
                      ).then((_) => setState(() {}));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addJPDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add JP'),
      ),
    );
  }
}

// ---------------- JP DETAIL (FOLDER VIEW) ----------------
class JPDetailScreen extends StatefulWidget {
  final JobPerformer jp;
  const JPDetailScreen({super.key, required this.jp});

  @override
  State<JPDetailScreen> createState() => _JPDetailScreenState();
}

class _JPDetailScreenState extends State<JPDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, bool> _selectedMap = {};
  final Map<String, double> _qtyMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (var itm in AppData.instance.items) {
      _selectedMap[itm.id] = false;
      _qtyMap[itm.id] = 1.0;
    }
  }

  void _issueItems() {
    List<IssuedItem> itemsToIssue = [];

    _selectedMap.forEach((id, isSelected) {
      if (isSelected) {
        final itm = AppData.instance.items.firstWhere((e) => e.id == id);
        final issueQty = _qtyMap[id] ?? 1.0;

        if (issueQty > 0) {
          if (issueQty > itm.stock) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Not enough stock for ${itm.name}! (Available: ${itm.stock})')),
            );
            return;
          }
          itemsToIssue.add(IssuedItem(
            itemId: itm.id,
            itemName: itm.name,
            unit: itm.unit,
            qty: issueQty,
          ));
        }
      }
    });

    if (itemsToIssue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 item with quantity!')),
      );
      return;
    }

    // Stock deduction
    for (var issued in itemsToIssue) {
      final itm = AppData.instance.items.firstWhere((e) => e.id == issued.itemId);
      itm.stock -= issued.qty;
    }

    final newSlip = IssueSlip(
      id: 'SLIP-${DateTime.now().millisecondsSinceEpoch}',
      jpId: widget.jp.id,
      jpName: widget.jp.name,
      date: DateTime.now(),
      items: itemsToIssue,
    );

    AppData.instance.issueSlips.insert(0, newSlip);

    setState(() {
      for (var key in _selectedMap.keys) {
        _selectedMap[key] = false;
        _qtyMap[key] = 1.0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material Approved & Issued!'), backgroundColor: Colors.green),
    );

    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final jpSlips = AppData.instance.issueSlips.where((s) => s.jpId == widget.jp.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jp.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.history), text: 'History (${jpSlips.length})'),
            const Tab(icon: const Icon(Icons.checklist), text: 'Issue New Items'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: HISTORY
          jpSlips.isEmpty
              ? const Center(child: Text('No material issued to this JP yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: jpSlips.length,
                  itemBuilder: (ctx, i) {
                    final slip = jpSlips[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(
                          DateFormat('dd-MMM-yyyy  hh:mm a').format(slip.date),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${slip.items.length} items issued'),
                        children: [
                          const Divider(),
                          ...slip.items.map((it) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(it.itemName, style: const TextStyle(fontSize: 15)),
                                    Text('${it.qty} ${it.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),

          // TAB 2: ISSUE NEW ITEMS
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: AppData.instance.items.length,
                  itemBuilder: (ctx, i) {
                    final itm = AppData.instance.items[i];
                    final isChecked = _selectedMap[itm.id] ?? false;

                    return Card(
                      elevation: isChecked ? 3 : 1,
                      color: isChecked ? Colors.indigo.shade50 : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (val) {
                                setState(() {
                                  _selectedMap[itm.id] = val ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(itm.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(
                                    'Stock: ${itm.stock} ${itm.unit}',
                                    style: TextStyle(
                                      color: itm.stock > 0 ? Colors.green.shade700 : Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isChecked)
                              SmartQtyStepper(
                                initialValue: _qtyMap[itm.id] ?? 1.0,
                                maxValue: itm.stock,
                                onChanged: (val) {
                                  _qtyMap[itm.id] = val;
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _issueItems,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('APPROVE & ISSUE MATERIAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- 2. ITEMS & STOCK MANAGEMENT ----------------
class ItemsStockScreen extends StatefulWidget {
  const ItemsStockScreen({super.key});

  @override
  State<ItemsStockScreen> createState() => _ItemsStockScreenState();
}

class _ItemsStockScreenState extends State<ItemsStockScreen> {
  void _addItemDialog() {
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'Pcs');
    final stockCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item Name')),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit (Pcs, Mtr, Kg)')),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Opening Stock')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  AppData.instance.items.add(Item(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    unit: unitCtrl.text.trim(),
                    stock: double.tryParse(stockCtrl.text) ?? 0,
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current Store Stock'), centerTitle: true),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: AppData.instance.items.length,
        itemBuilder: (ctx, i) {
          final itm = AppData.instance.items[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: itm.stock > 0 ? Colors.green.shade100 : Colors.red.shade100,
                child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              title: Text(itm.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                '${itm.stock} ${itm.unit}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: itm.stock > 0 ? Colors.green.shade800 : Colors.red,
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItemDialog,
        icon: const Icon(Icons.add_box),
        label: const Text('Add Item'),
      ),
    );
  }
}

// ---------------- 3. STORE REQUEST (INWARD) & EXPORT ----------------
class RequisitionScreen extends StatefulWidget {
  const RequisitionScreen({super.key});

  @override
  State<RequisitionScreen> createState() => _RequisitionScreenState();
}

class _RequisitionScreenState extends State<RequisitionScreen> {
  void _createRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewRequisitionPage()),
    ).then((_) => setState(() {}));
  }

  Future<void> _exportPdf(StockRequisition req) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MATERIAL REQUISITION SLIP', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Date: ${DateFormat('dd-MMM-yyyy').format(req.date)}'),
            pw.Text('Req ID: ${req.id}'),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Item Name', 'Unit', 'Requested Qty', 'Received Qty'],
              data: req.items.map((e) => [e.itemName, e.unit, '${e.requestedQty}', '${e.receivedQty}']).toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final reqs = AppData.instance.requisitions;
    return Scaffold(
      appBar: AppBar(title: const Text('Store Requisitions'), centerTitle: true),
      body: reqs.isEmpty
          ? const Center(child: Text('No store requisition created.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reqs.length,
              itemBuilder: (ctx, i) {
                final req = reqs[i];
                return Card(
                  child: ExpansionTile(
                    title: Text('Req #${req.id} - ${DateFormat('dd-MMM-yyyy').format(req.date)}'),
                    subtitle: Text('Status: ${req.status} (${req.items.length} items)'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          onPressed: () => _exportPdf(req),
                        ),
                        if (req.status == 'Requested')
                          IconButton(
                            icon: const Icon(Icons.inventory, color: Colors.blue),
                            tooltip: 'Receive Items & Edit Qty',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ReceiveStockPage(req: req)),
                              ).then((_) => setState(() {}));
                            },
                          ),
                      ],
                    ),
                    children: req.items
                        .map((it) => ListTile(
                              dense: true,
                              title: Text(it.itemName),
                              trailing: Text('Req: ${it.requestedQty} | Recv: ${it.receivedQty} ${it.unit}'),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRequest,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Request'),
      ),
    );
  }
}

class NewRequisitionPage extends StatefulWidget {
  const NewRequisitionPage({super.key});

  @override
  State<NewRequisitionPage> createState() => _NewRequisitionPageState();
}

class _NewRequisitionPageState extends State<NewRequisitionPage> {
  final Map<String, bool> _selected = {};
  final Map<String, double> _reqQty = {};

  @override
  void initState() {
    super.initState();
    for (var itm in AppData.instance.items) {
      _selected[itm.id] = false;
      _reqQty[itm.id] = 10.0;
    }
  }

  void _saveReq() {
    List<RequisitionItem> reqItems = [];
    _selected.forEach((id, isSel) {
      if (isSel) {
        final itm = AppData.instance.items.firstWhere((e) => e.id == id);
        reqItems.add(RequisitionItem(
          itemId: itm.id,
          itemName: itm.name,
          unit: itm.unit,
          requestedQty: _reqQty[id] ?? 1.0,
        ));
      }
    });

    if (reqItems.isEmpty) return;

    AppData.instance.requisitions.insert(
      0,
      StockRequisition(
        id: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        date: DateTime.now(),
        status: 'Requested',
        items: reqItems,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Store Request')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: AppData.instance.items.length,
              itemBuilder: (ctx, i) {
                final itm = AppData.instance.items[i];
                final isSel = _selected[itm.id] ?? false;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSel,
                      onChanged: (val) => setState(() => _selected[itm.id] = val ?? false),
                    ),
                    title: Text(itm.name),
                    subtitle: Text('Current Stock: ${itm.stock} ${itm.unit}'),
                    trailing: isSel
                        ? SmartQtyStepper(
                            initialValue: _reqQty[itm.id] ?? 10.0,
                            onChanged: (val) => _reqQty[itm.id] = val,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _saveReq,
              icon: const Icon(Icons.send),
              label: const Text('SUBMIT REQUISITION', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

class ReceiveStockPage extends StatefulWidget {
  final StockRequisition req;
  const ReceiveStockPage({super.key, required this.req});

  @override
  State<ReceiveStockPage> createState() => _ReceiveStockPageState();
}

class _ReceiveStockPageState extends State<ReceiveStockPage> {
  final Map<String, double> _recvMap = {};

  @override
  void initState() {
    super.initState();
    for (var itm in widget.req.items) {
      _recvMap[itm.itemId] = itm.requestedQty;
    }
  }

  void _finishReceive() {
    for (var itm in widget.req.items) {
      final actualRecv = _recvMap[itm.itemId] ?? 0;
      itm.receivedQty = actualRecv;

      final stockItem = AppData.instance.items.firstWhere((e) => e.id == itm.itemId);
      stockItem.stock += actualRecv;
    }

    widget.req.status = 'Received';
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stock Received and updated in Inventory!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Receive Stock (${widget.req.id})')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.shade100,
            child: const Text('Edit received qty if different from requested qty:'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.req.items.length,
              itemBuilder: (ctx, i) {
                final itm = widget.req.items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(itm.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Requested: ${itm.requestedQty} ${itm.unit}'),
                    trailing: SmartQtyStepper(
                      initialValue: _recvMap[itm.itemId] ?? itm.requestedQty,
                      onChanged: (val) => _recvMap[itm.itemId] = val,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: _finishReceive,
              icon: const Icon(Icons.done_all),
              label: const Text('CONFIRM STOCK RECEIVING'),
            ),
          )
        ],
      ),
    );
  }
}

// ---------------- 4. REPORTS, SEARCH (JP DATE-RANGE) & EXPORTS ----------------
class ReportsAndSearchScreen extends StatefulWidget {
  const ReportsAndSearchScreen({super.key});

  @override
  State<ReportsAndSearchScreen> createState() => _ReportsAndSearchScreenState();
}

class _ReportsAndSearchScreenState extends State<ReportsAndSearchScreen> {
  String? _selectedJpId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _exportExcel(Map<String, double> summary) async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['JP Report'];

    sheet.appendRow([ex.TextCellValue('JP Consumption Report')]);
    sheet.appendRow([ex.TextCellValue('Period: ${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}')]);
    sheet.appendRow([ex.TextCellValue('')]);

    sheet.appendRow([ex.TextCellValue('Item Name'), ex.TextCellValue('Total Issued Qty')]);
    summary.forEach((name, qty) {
      sheet.appendRow([ex.TextCellValue(name), ex.DoubleCellValue(qty)]);
    });

    final bytes = excel.encode();
    if (bytes != null) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'JP_Report.xlsx');
    }
  }

  Future<void> _exportPdf(Map<String, double> summary) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context ctx) => [
          pw.Text('Job Performer Consumption Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Period: ${DateFormat('dd-MMM-yyyy').format(_startDate)} to ${DateFormat('dd-MMM-yyyy').format(_endDate)}'),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text('Material Summary:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Item Name', 'Total Quantity Issued'],
            data: summary.entries.map((e) => [e.key, '${e.value}']).toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final filteredSlips = AppData.instance.issueSlips.where((slip) {
      final matchesJp = _selectedJpId == null || slip.jpId == _selectedJpId;
      final matchesDate = slip.date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
          slip.date.isBefore(_endDate.add(const Duration(days: 1)));
      return matchesJp && matchesDate;
    }).toList();

    final Map<String, double> summary = {};
    for (var slip in filteredSlips) {
      for (var itm in slip.items) {
        summary[itm.itemName] = (summary[itm.itemName] ?? 0) + itm.qty;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & JP Search'), centerTitle: true),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Filter by JP (Select JP)'),
                    value: _selectedJpId,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Job Performers')),
                      ...AppData.instance.jps.map((jp) => DropdownMenuItem(value: jp.id, child: Text(jp.name))),
                    ],
                    onChanged: (val) => setState(() => _selectedJpId = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${DateFormat('dd-MMM').format(_startDate)} - ${DateFormat('dd-MMM-yyyy').format(_endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.date_range),
                        label: const Text('Change Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                          onPressed: () => _exportPdf(summary),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF Report'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                          onPressed: () => _exportExcel(summary),
                          icon: const Icon(Icons.table_chart),
                          label: const Text('Excel Report'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Summary of Issued Materials (${summary.length} types):', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: summary.isEmpty
                ? const Center(child: Text('No records found for this period/JP.'))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: summary.entries.map((e) {
                      return Card(
                        child: ListTile(
                          title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text('${e.value}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                        ),
                      );
                    }).toList(),
                  ),
          )
        ],
      ),
    );
  }
}
