import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'role_selection.dart';
import 'change_password_page.dart';
import 'users_tab.dart';
import 'deliveries_tab.dart';
import 'orders_tab.dart';

class AdminDashboard extends StatefulWidget {
  final String adminEmail;
  final String adminPassword;

  const AdminDashboard({
    super.key,
    required this.adminEmail,
    required this.adminPassword,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'change_password':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
        );
        break;
      case 'logout':
        _showLogoutConfirmation();
        break;
    }
  }

  Future<void> _logout() async {
    // Clear persistent login state
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Logout", style: TextStyle(color: Colors.black)),
          content: const Text(
            "Are you sure you want to logout?",
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text(
          "Admin Panel",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: "Users"),
            Tab(text: "Orders"),
            Tab(text: "Reports"),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'change_password',
                child: ListTile(
                  leading: Icon(LucideIcons.key, color: Colors.black),
                  title: Text(
                    'Change Password',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(LucideIcons.logOut, color: Colors.black),
                  title: Text('Logout', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
            icon: const Icon(LucideIcons.moreVertical, color: Colors.black),
            color: Colors.white,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [UsersTab(), OrdersTab(), DeliveriesTab()],
      ),
    );
  }
}
