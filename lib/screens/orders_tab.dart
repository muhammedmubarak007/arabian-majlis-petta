import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Model for a delivery item
class DeliveryItem {
  final String bill;
  final String location;
  final DateTime? startTime;
  final bool running;
  final int elapsedSeconds;
  final String status;
  final String? assignedTo;
  final String? assignedToEmail;
  final String? assignedToName;

  DeliveryItem({
    required this.bill,
    required this.location,
    this.startTime,
    this.running = false,
    this.elapsedSeconds = 0,
    this.status = 'pending',
    this.assignedTo,
    this.assignedToEmail,
    this.assignedToName,
  });

  DeliveryItem copyWith({
    String? bill,
    String? location,
    DateTime? startTime,
    bool? running,
    int? elapsedSeconds,
    String? status,
    String? assignedTo,
    String? assignedToEmail,
    String? assignedToName,
  }) {
    return DeliveryItem(
      bill: bill ?? this.bill,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      running: running ?? this.running,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToEmail: assignedToEmail ?? this.assignedToEmail,
      assignedToName: assignedToName ?? this.assignedToName,
    );
  }
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final TextEditingController billCtl = TextEditingController();
  final TextEditingController locCtl = TextEditingController();
  final TextEditingController searchCtl = TextEditingController();
  List<DeliveryItem> deliveries = [];
  List<DeliveryItem> filteredDeliveries = [];
  bool isLoading = false;
  Map<String, String> userIdToNameMap = {};

  bool get canAdd =>
      billCtl.text.trim().isNotEmpty && locCtl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    billCtl.addListener(() => setState(() {}));
    locCtl.addListener(() => setState(() {}));
    searchCtl.addListener(_filterDeliveries);
    _loadOrders();
  }

  Future<void> _resolveUserNames() async {
    try {
      // Get all unique user IDs from the current deliveries
      final userIds = deliveries
          .where((d) => d.assignedTo != null && d.assignedTo!.isNotEmpty)
          .map((d) => d.assignedTo!)
          .toSet()
          .toList();

      if (userIds.isEmpty) return;

      // Fetch user names from Firestore
      for (final userId in userIds) {
        if (!userIdToNameMap.containsKey(userId)) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data();
              final userName =
                  userData?['name'] ??
                  userData?['email']?.split('@').first ??
                  'Unknown User';
              userIdToNameMap[userId] = userName;
            } else {
              userIdToNameMap[userId] = 'Unknown User';
            }
          } catch (e) {
            print('Error fetching user $userId: $e');
            userIdToNameMap[userId] = 'Unknown User';
          }
        }
      }
    } catch (e) {
      print('Error resolving user names: $e');
    }
  }

  String _getDisplayName(DeliveryItem delivery) {
    // First try to use the resolved name from users collection
    if (delivery.assignedTo != null &&
        userIdToNameMap.containsKey(delivery.assignedTo)) {
      return userIdToNameMap[delivery.assignedTo]!;
    }

    // Fallback to stored name or email
    if (delivery.assignedToName != null &&
        delivery.assignedToName!.isNotEmpty) {
      return delivery.assignedToName!;
    }

    if (delivery.assignedToEmail != null &&
        delivery.assignedToEmail!.isNotEmpty) {
      return delivery.assignedToEmail!.split('@').first;
    }

    return 'Unknown User';
  }

  Color _getAssignedToTextColor(String status) {
    switch (status) {
      case 'selected':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return const Color.fromARGB(255, 132, 132, 132);
      default:
        return Colors.blue;
    }
  }

  Color _getAssignedToCardColor(String status) {
    switch (status) {
      case 'selected':
        return Colors.blue[50]!;
      case 'active':
        return Colors.green[50]!;
      case 'completed':
        return Colors.grey[100]!;
      default:
        return Colors.blue[50]!;
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _filterDeliveries() {
    final query = searchCtl.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        filteredDeliveries = List.from(deliveries);
      });
      return;
    }

    setState(() {
      filteredDeliveries = deliveries.where((delivery) {
        // Search in bill number
        if (delivery.bill.toLowerCase().contains(query)) {
          return true;
        }

        // Search in location
        if (delivery.location.toLowerCase().contains(query)) {
          return true;
        }

        // Search in assigned user name
        final displayName = _getDisplayName(delivery).toLowerCase();
        if (displayName.contains(query)) {
          return true;
        }

        return false;
      }).toList();
    });
  }

  @override
  void dispose() {
    billCtl.dispose();
    locCtl.dispose();
    searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      // Get today's date range
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        deliveries = snapshot.docs.map((doc) {
          final data = doc.data();
          return DeliveryItem(
            bill: data['billNo'] ?? '',
            location: data['location'] ?? '',
            startTime: data['startAt'] != null
                ? (data['startAt'] as Timestamp).toDate()
                : null,
            running: data['status'] == 'active',
            elapsedSeconds: data['elapsedSeconds'] ?? 0,
            status: data['status'] ?? 'pending',
            assignedTo: data['assignedTo'],
            assignedToEmail: data['assignedToEmail'],
            assignedToName: data['assignedToName'],
          );
        }).toList();

        // Sort orders by status: selected first, then pending, then completed
        deliveries.sort((a, b) {
          const statusOrder = {
            'selected': 0,
            'pending': 1,
            'active': 2,
            'completed': 3,
          };
          final aOrder = statusOrder[a.status] ?? 4;
          final bOrder = statusOrder[b.status] ?? 4;
          return aOrder.compareTo(bOrder);
        });

        // Initialize filtered deliveries
        filteredDeliveries = List.from(deliveries);
      });

      // Resolve user names after loading orders
      await _resolveUserNames();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _addOrder() async {
    if (!canAdd || !mounted) return;

    setState(() => isLoading = true);

    try {
      // Validate input
      final billNo = billCtl.text.trim();
      final location = locCtl.text.trim();

      if (billNo.isEmpty || location.isEmpty) {
        _showErrorSnackBar('Please fill in all fields');
        return;
      }

      // Check if bill number already exists (simplified check)
      final existingOrder = await FirebaseFirestore.instance
          .collection('orders')
          .where('billNo', isEqualTo: billNo)
          .limit(1)
          .get();

      if (existingOrder.docs.isNotEmpty) {
        _showErrorSnackBar('Bill number $billNo already exists');
        return;
      }

      await FirebaseFirestore.instance.collection('orders').add({
        'billNo': billNo,
        'location': location,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
      });

      if (!mounted) return;

      billCtl.clear();
      locCtl.clear();
      _showSuccessSnackBar('Order added successfully!');
      await _loadOrders();
      _filterDeliveries();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error adding order: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _deleteOrder(DeliveryItem delivery) async {
    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Are you sure you want to delete Bill No : ${delivery.bill}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('billNo', isEqualTo: delivery.bill)
          .where('location', isEqualTo: delivery.location)
          .get();

      if (querySnapshot.docs.isEmpty) {
        _showErrorSnackBar('Order not found');
        return;
      }

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      if (!mounted) return;
      _showSuccessSnackBar('Order deleted successfully!');
      await _loadOrders();
      _filterDeliveries();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error deleting order: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add Order Card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(LucideIcons.plus, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        "New Order",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: billCtl,
                    decoration: InputDecoration(
                      labelText: "Bill No",
                      prefixIcon: const Icon(
                        LucideIcons.fileText,
                        color: Colors.black,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locCtl,
                    decoration: InputDecoration(
                      labelText: "Address",
                      prefixIcon: const Icon(
                        LucideIcons.mapPin,
                        color: Colors.black,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canAdd && !isLoading ? _addOrder : null,
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.plus, color: Colors.white),
                      label: Text(
                        isLoading ? "Adding..." : "Add",
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Search Card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchCtl,
                decoration: InputDecoration(
                  hintText:
                      "Search by bill number, location, or assigned user...",
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: Colors.black54,
                  ),
                  suffixIcon: searchCtl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            LucideIcons.x,
                            color: Colors.black54,
                          ),
                          onPressed: () {
                            searchCtl.clear();
                            _filterDeliveries();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                ),
                onChanged: (value) => _filterDeliveries(),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Orders List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Orders",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.package, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "${filteredDeliveries.length}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (filteredDeliveries.isEmpty)
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Text(
                searchCtl.text.trim().isEmpty
                    ? "No orders today"
                    : "No orders found matching your search",
                style: const TextStyle(color: Colors.black54, fontSize: 16),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredDeliveries.length,
              itemBuilder: (context, index) {
                final d = filteredDeliveries[index];
                return Card(
                  color: Colors.white,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getStatusColor(d.status),
                              radius: 20,
                              child: Icon(
                                _getStatusIcon(d.status),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bill No : ${d.bill}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.mapPin,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          d.location,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(d.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getStatusText(d.status),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Assigned user info
                        if (d.assignedTo != null &&
                            d.assignedTo!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getAssignedToCardColor(d.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.user,
                                  size: 16,
                                  color: _getAssignedToTextColor(d.status),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Assigned to: ${_getDisplayName(d)}",
                                  style: TextStyle(
                                    color: _getAssignedToTextColor(d.status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Action button
                        if (d.status == 'pending') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _deleteOrder(d),
                              icon: const Icon(
                                LucideIcons.trash2,
                                color: Colors.red,
                                size: 18,
                              ),
                              label: const Text(
                                "Delete",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'selected':
        return Colors.blue;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.black12;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return LucideIcons.clock;
      case 'selected':
        return LucideIcons.userCheck;
      case 'active':
        return Icons.delivery_dining;
      case 'completed':
        return LucideIcons.checkCircle;
      default:
        return LucideIcons.clock;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'selected':
        return 'Selected';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }
}
