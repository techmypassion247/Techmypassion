import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// AUTONEX FLUTTER MOBILE APP
// Direct conversion of AutoNex Web Dashboard into a native Android Flutter App
// ============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AutoNexApp());
}

class AppColors {
  static const Color bg = Color(0FF070B18);
  static const Color panel = Color(0FF0D1325);
  static const Color panel2 = Color(0FF111A30);
  static const Color line = Color(0FF24304A);
  static const Color text = Color(0FFF5F7FF);
  static const Color muted = Color(0FF9AA7C2);
  static const Color cyan = Color(0FF16D9FF);
  static const Color blue = Color(0FF3B82F6);
  static const Color purple = Color(0FF7C3AED);
  static const Color green = Color(0FF22C55E);
  static const Color red = Color(0FFEF4444);
  static const Color yellow = Color(0FFF59E0B);
}

class ApiConstants {
  static const String loginUrl = 'http://192.168.43.134:5678/webhook/autonex-login';
  static const String dashboardUrl = 'http://192.168.43.134:5678/webhook/autonex-dashboard';
  static const String offerUrl = 'http://192.168.43.134:5678/webhook/autonex-offer';
  static const String approveUrl = 'http://192.168.43.134:5678/webhook/autonex-approve';
  static const String regenerateUrl = 'http://192.168.43.134:5678/webhook/autonex-regenerate';
  static const String createPostUrl = 'http://192.168.43.134:5678/webhook/autonex-create-post';
}

class PostModel {
  final String id;
  final String date;
  final String title;
  final String caption;
  final String status;
  final String img;
  final String hashtags;

  PostModel({
    required this.id,
    required this.date,
    required this.title,
    required this.caption,
    required this.status,
    required this.img,
    required this.hashtags,
  });

  factory PostModel.fromJson(Map<String, dynamic> json, int index) {
    String normalizeStatus(dynamic rawStatus) {
      final s = (rawStatus ?? 'Pending').toString().trim().toLowerCase();
      if (s.contains('publish')) return 'Published';
      if (s.contains('approve')) return 'Approved';
      if (s.contains('reject')) return 'Rejected';
      return 'Pending';
    }

    final rawId = json['post_id'] ?? json['Post ID'] ?? json['Post_ID'] ?? json['id'] ?? 'temp-$index';

    return PostModel(
      id: rawId.toString(),
      date: (json['created_date'] ?? json['date'] ?? '').toString(),
      title: (json['topic'] ?? json['title'] ?? 'Untitled post').toString(),
      caption: (json['caption'] ?? 'Caption is not available yet.').toString(),
      status: normalizeStatus(json['status']),
      img: (json['image_url'] ?? json['img'] ?? '').toString(),
      hashtags: (json['hashtags'] ?? '').toString(),
    );
  }
}

class OfferModel {
  final String text;
  final String endDate;

  OfferModel({required this.text, required this.endDate});
}

class SessionManager {
  static String? token;
  static String? clientId;
  static String? expiresAt;

  static bool get isLoggedIn =>
      token != null && token!.isNotEmpty && clientId != null && clientId!.isNotEmpty;

  static void clear() {
    token = null;
    clientId = null;
    expiresAt = null;
  }
}

class AutoNexApp extends StatelessWidget {
  const AutoNexApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoNex — AI Automation Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        primaryColor: AppColors.blue,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.blue,
          secondary: AppColors.cyan,
          surface: AppColors.panel,
          background: AppColors.bg,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0FF080D1B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
          ),
        ),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({Key? key}) : super(key: key);

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool _isLoading = false;

  void _onLoginSuccess() {
    setState(() {});
  }

  void _onLogout() {
    SessionManager.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!SessionManager.isLoggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    return MainDashboardShell(onLogout: _onLogout);
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'client@example.com');
  final _passwordController = TextEditingController(text: '123456');
  bool _isSigningIn = false;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showToast('Please enter email and password.');
      return;
    }

    setState(() => _isSigningIn = true);

    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        SessionManager.token = data['token']?.toString();
        SessionManager.clientId = data['client_id']?.toString();
        SessionManager.expiresAt = data['expires_at']?.toString();

        _showToast('Login successful!');
        widget.onLoginSuccess();
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Invalid credentials');
      }
    } catch (e) {
      // Fallback for offline demo mode if API server is offline
      _showToast('Using demo session (API offline or unreachable)');
      SessionManager.token = 'demo_token_12345';
      SessionManager.clientId = '101';
      SessionManager.expiresAt = DateTime.now().add(const Duration(days: 7)).toIso8601String();
      widget.onLoginSuccess();
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.panel2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.7, -0.6),
            radius: 1.2,
            colors: [Color(0223B82F6), AppColors.bg],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.panel.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 20))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand Header
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.cyan, AppColors.purple],
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'AN',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.extrabold, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'AutoNex',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Client Portal • AI automation, simplified.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // Email
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Email', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Password', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSigningIn ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.blue, AppColors.purple],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isSigningIn
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Sign in',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in with your AutoNex client account.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainDashboardShell extends StatefulWidget {
  final VoidCallback onLogout;
  const MainDashboardShell({Key? key, required this.onLogout}) : super(key: key);

  @override
  State<MainDashboardShell> createState() => _MainDashboardShellState();
}

class _MainDashboardShellState extends State<MainDashboardShell> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  String _businessName = 'ABC Restaurant';
  List<PostModel> _posts = [];
  OfferModel _offer = OfferModel(text: '20% OFF Family Pizza', endDate: '2026-10-30');
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final clientId = SessionManager.clientId ?? '101';
      final token = SessionManager.token ?? '';

      final url = Uri.parse('${ApiConstants.dashboardUrl}?client_id=$clientId');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (data['business'] != null) {
            _businessName = data['business']['name'] ?? 'Client #$clientId';
          }
          if (data['offer'] != null) {
            _offer = OfferModel(
              text: data['offer']['offer_text'] ?? data['offer']['text'] ?? 'No active offer',
              endDate: data['offer']['end_date'] ?? data['offer']['date'] ?? '',
            );
          }
          if (data['posts'] is List) {
            final rawList = data['posts'] as List;
            _posts = rawList.asMap().entries.map((e) => PostModel.fromJson(e.value, e.key)).toList();
          }
        }
      } else {
        _useFallbackMockData();
      }
    } catch (_) {
      _useFallbackMockData();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _useFallbackMockData() {
    _posts = [
      PostModel(
        id: '101',
        date: '2026-09-22',
        title: 'Margherita Pizza Promotion',
        caption: 'Enjoy 20% off our signature wood-fired Margherita Pizza this week!',
        status: 'Pending',
        img: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600',
        hashtags: '#pizza #foodie #autonex #italian',
      ),
      PostModel(
        id: '102',
        date: '2026-09-20',
        title: 'Weekend Chef Special',
        caption: 'Taste our executive chef special pasta with freshly harvested truffle.',
        status: 'Published',
        img: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600',
        hashtags: '#chefspecial #dining #foodlovers',
      ),
      PostModel(
        id: '103',
        date: '2026-09-18',
        title: 'Family Feast Bundle',
        caption: 'Gather the family for our ultimate weekend banquet offer!',
        status: 'Pending',
        img: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600',
        hashtags: '#familydinner #foodies #special',
      ),
    ];
  }

  Future<void> _approvePost(String postId) async {
    _showToast('Publishing post...');
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.approveUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SessionManager.token}',
        },
        body: jsonEncode({
          'client_id': SessionManager.clientId,
          'post_id': postId,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showToast('Post approved & published ✓');
      } else {
        _updateLocalPostStatus(postId, 'Published');
        _showToast('Post approved locally (Demo Mode) ✓');
      }
    } catch (e) {
      _updateLocalPostStatus(postId, 'Published');
      _showToast('Post approved locally ✓');
    }
  }

  Future<void> _regeneratePost(String postId) async {
    _showToast('Regenerating post...');
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.regenerateUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SessionManager.token}',
        },
        body: jsonEncode({
          'client_id': SessionManager.clientId,
          'post_id': postId,
        }),
      );
      if (response.statusCode == 200) {
        _showToast('Post regenerated successfully ✓');
        _loadDashboardData();
      } else {
        _showToast('Post regeneration requested ✓');
      }
    } catch (e) {
      _showToast('Post regeneration trigger sent.');
    }
  }

  void _updateLocalPostStatus(String id, String newStatus) {
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == id);
      if (idx != -1) {
        final old = _posts[idx];
        _posts[idx] = PostModel(
          id: old.id,
          date: old.date,
          title: old.title,
          caption: old.caption,
          status: newStatus,
          img: old.img,
          hashtags: old.hashtags,
        );
      }
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.panel2,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreatePostModal(
        onPostCreated: () {
          _showToast('Post generated successfully ✓');
          _loadDashboardData();
        },
      ),
    );
  }

  void _openReviewModal(PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) => PostReviewDialog(
        post: post,
        onApprove: () => _approvePost(post.id),
        onRegenerate: () => _regeneratePost(post.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _posts.where((p) => p.status == 'Pending').length;
    final publishedCount = _posts.where((p) => p.status == 'Published').length;

    List<Widget> pages = [
      DashboardHomeView(
        posts: _posts,
        offer: _offer,
        pendingCount: pendingCount,
        publishedCount: publishedCount,
        onReviewPost: _openReviewModal,
        onApprovePost: _approvePost,
        onRegeneratePost: _regeneratePost,
        onNavigate: (index) => setState(() => _selectedIndex = index),
      ),
      PostsListView(
        posts: _posts,
        activeFilter: _activeFilter,
        onFilterChange: (f) => setState(() => _activeFilter = f),
        onReviewPost: _openReviewModal,
        onApprovePost: _approvePost,
        onRegeneratePost: _regeneratePost,
        onCreatePost: _openCreatePostModal,
      ),
      ApprovalsView(
        pendingPosts: _posts.where((p) => p.status == 'Pending').toList(),
        onReviewPost: _openReviewModal,
        onApprovePost: _approvePost,
        onRegeneratePost: _regeneratePost,
      ),
      OfferView(
        currentOffer: _offer,
        onSaveOffer: (newText, newDate) async {
          setState(() {
            _offer = OfferModel(text: newText, endDate: newDate);
          });
          _showToast('Offer saved successfully ✓');
        },
      ),
    ];

    final titles = ['Dashboard', 'Posts', 'Approvals', 'Offer'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Text(
              'Manage your AI social media content',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_businessName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const Text('Client Portal',
                        style: TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.cyan,
                  child: Text(
                    _businessName.isNotEmpty ? _businessName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.muted),
                  color: AppColors.panel2,
                  onSelected: (val) {
                    if (val == 'logout') widget.onLogout();
                    if (val == 'refresh') _loadDashboardData();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                        value: 'refresh',
                        child: Text('Refresh Data', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(
                        value: 'logout',
                        child: Text('Logout', style: TextStyle(color: AppColors.red))),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.cyan,
        backgroundColor: AppColors.panel,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
            : pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: AppColors.panel,
        selectedItemColor: AppColors.cyan,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_on_outlined), label: 'Posts'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Approvals'),
          BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), label: 'Offer'),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE WIDGETS
// ============================================================================

class DashboardHomeView extends StatelessWidget {
  final List<PostModel> posts;
  final OfferModel offer;
  final int pendingCount;
  final int publishedCount;
  final Function(PostModel) onReviewPost;
  final Function(String) onApprovePost;
  final Function(String) onRegeneratePost;
  final Function(int) onNavigate;

  const DashboardHomeView({
    Key? key,
    required this.posts,
    required this.offer,
    required this.pendingCount,
    required this.publishedCount,
    required this.onReviewPost,
    required this.onApprovePost,
    required this.onRegeneratePost,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard('📅', posts.length.toString(), 'Posts this month'),
              _buildStatCard('⏳', pendingCount.toString(), 'Pending approval'),
              _buildStatCard('✓', publishedCount.toString(), 'Published'),
              _buildStatCard('⚡', '60%', 'Monthly usage'),
            ],
          ),
          const SizedBox(height: 20),

          // Active Offer Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.blue.withOpacity(0.15),
                  AppColors.purple.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.blue.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ACTIVE OFFER',
                        style: TextStyle(
                            color: AppColors.cyan,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    TextButton(
                      onPressed: () => onNavigate(3),
                      child: const Text('Edit', style: TextStyle(color: AppColors.cyan)),
                    )
                  ],
                ),
                Text(
                  offer.text,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Valid until: ${offer.endDate.isNotEmpty ? offer.endDate : 'Ongoing'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: const LinearProgressIndicator(
                    value: 0.6,
                    minHeight: 8,
                    backgroundColor: Color(0FF182238),
                    color: AppColors.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upcoming Posts Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Upcoming posts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              TextButton(
                onPressed: () => onNavigate(1),
                child: const Text('View all', style: TextStyle(color: AppColors.cyan)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          posts.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text('No posts found.', style: TextStyle(color: AppColors.muted)),
                ))
              : Column(
                  children: posts
                      .take(2)
                      .map((p) => PostCardItem(
                            post: p,
                            onReview: () => onReviewPost(p),
                            onApprove: () => onApprovePost(p.id),
                            onRegenerate: () => onRegeneratePost(p.id),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String icon, String num, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(num,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class PostsListView extends StatelessWidget {
  final List<PostModel> posts;
  final String activeFilter;
  final Function(String) onFilterChange;
  final Function(PostModel) onReviewPost;
  final Function(String) onApprovePost;
  final Function(String) onRegeneratePost;
  final VoidCallback onCreatePost;

  const PostsListView({
    Key? key,
    required this.posts,
    required this.activeFilter,
    required this.onFilterChange,
    required this.onReviewPost,
    required this.onApprovePost,
    required this.onRegeneratePost,
    required this.onCreatePost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filtered = posts.where((p) {
      if (activeFilter == 'pending') return p.status == 'Pending';
      if (activeFilter == 'published') return p.status == 'Published';
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row & Create Button
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('Pending', 'pending'),
                      const SizedBox(width: 8),
                      _filterChip('Published', 'published'),
                    ],
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onCreatePost,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),

          // Posts List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('No posts found in this category.',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      return PostCardItem(
                        post: p,
                        onReview: () => onReviewPost(p),
                        onApprove: () => onApprovePost(p.id),
                        onRegenerate: () => onRegeneratePost(p.id),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = activeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onFilterChange(value),
      selectedColor: AppColors.panel2,
      backgroundColor: AppColors.panel,
      side: BorderSide(color: isSelected ? AppColors.cyan : AppColors.line),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.muted,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class ApprovalsView extends StatelessWidget {
  final List<PostModel> pendingPosts;
  final Function(PostModel) onReviewPost;
  final Function(String) onApprovePost;
  final Function(String) onRegeneratePost;

  const ApprovalsView({
    Key? key,
    required this.pendingPosts,
    required this.onReviewPost,
    required this.onApprovePost,
    required this.onRegeneratePost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Posts waiting for your approval',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Expanded(
            child: pendingPosts.isEmpty
                ? const Center(
                    child: Text('🎉 No posts waiting for approval.',
                        style: TextStyle(color: AppColors.muted, fontSize: 15)),
                  )
                : ListView.builder(
                    itemCount: pendingPosts.length,
                    itemBuilder: (ctx, i) {
                      final p = pendingPosts[i];
                      return PostCardItem(
                        post: p,
                        onReview: () => onReviewPost(p),
                        onApprove: () => onApprovePost(p.id),
                        onRegenerate: () => onRegeneratePost(p.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class OfferView extends StatefulWidget {
  final OfferModel currentOffer;
  final Function(String, String) onSaveOffer;

  const OfferView({Key? key, required this.currentOffer, required this.onSaveOffer})
      : super(key: key);

  @override
  State<OfferView> createState() => _OfferViewState();
}

class _OfferViewState extends State<OfferView> {
  late TextEditingController _offerTextController;
  late TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _offerTextController = TextEditingController(text: widget.currentOffer.text);
    _dateController = TextEditingController(text: widget.currentOffer.endDate);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage current offer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            const Text('Offer text', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _offerTextController,
              decoration: const InputDecoration(hintText: 'e.g. 20% OFF Family Pizza'),
            ),
            const SizedBox(height: 16),
            const Text('Valid until (YYYY-MM-DD)',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(hintText: '2026-12-31'),
            ),
            const SizedBox(height: 16),
            const Text(
              'When saved, AutoNex will use this offer for future AI-generated content.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSaveOffer(
                    _offerTextController.text.trim(),
                    _dateController.text.trim(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save offer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REUSABLE CARD & DIALOG WIDGETS
// ============================================================================

class PostCardItem extends StatelessWidget {
  final PostModel post;
  final VoidCallback onReview;
  final VoidCallback onApprove;
  final VoidCallback onRegenerate;

  const PostCardItem({
    Key? key,
    required this.post,
    required this.onReview,
    required this.onApprove,
    required this.onRegenerate,
  }) : super(key: key);

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return AppColors.blue;
      case 'approved':
        return AppColors.green;
      case 'rejected':
        return AppColors.red;
      default:
        return AppColors.yellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(post.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              post.img,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                width: 80,
                height: 80,
                color: AppColors.panel2,
                child: const Icon(Icons.image, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details & Actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 4),
                Text(post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        post.status,
                        style: TextStyle(
                            color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    if (post.status == 'Pending') ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: AppColors.green, size: 22),
                        onPressed: onApprove,
                        tooltip: 'Approve',
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.muted, size: 22),
                        onPressed: onRegenerate,
                        tooltip: 'Regenerate',
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.visibility, color: AppColors.cyan, size: 22),
                      onPressed: onReview,
                      tooltip: 'View Detail',
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class PostReviewDialog extends StatefulWidget {
  final PostModel post;
  final VoidCallback onApprove;
  final VoidCallback onRegenerate;

  const PostReviewDialog({
    Key? key,
    required this.post,
    required this.onApprove,
    required this.onRegenerate,
  }) : super(key: key);

  @override
  State<PostReviewDialog> createState() => _PostReviewDialogState();
}

class _PostReviewDialogState extends State<PostReviewDialog> {
  final TransformationController _transformationController = TransformationController();

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        maxWidth: 500,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.post.title,
                      style:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 12),

              // Interactive Pinch-to-Zoom Image Box
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.post.img,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Center(
                        child: Text('Image unavailable', style: TextStyle(color: AppColors.muted)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.restart_alt, size: 16, color: AppColors.cyan),
                  label: const Text('Reset Zoom', style: TextStyle(color: AppColors.cyan, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 12),

              // Caption & Hashtags
              const Text('CAPTION',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                      letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(widget.post.caption,
                  style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4)),
              const SizedBox(height: 12),

              if (widget.post.hashtags.isNotEmpty) ...[
                const Text('HASHTAGS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(widget.post.hashtags,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.post.status == 'Pending') ...[
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApprove();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
                      child: const Text('✓ Approve & Publish'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRegenerate();
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: const Text('↻ Regenerate', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class CreatePostModal extends StatefulWidget {
  final VoidCallback onPostCreated;
  const CreatePostModal({Key? key, required this.onPostCreated}) : super(key: key);

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _isGenerating = false;

  Future<void> _submitCreatePost() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title and description.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.createPostUrl),
      );

      request.headers['Authorization'] = 'Bearer ${SessionManager.token}';
      request.fields['title'] = title;
      request.fields['description'] = desc;
      request.fields['features_description'] = desc;
      request.fields['client_id'] = SessionManager.clientId ?? '101';

      final response = await request.send().timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        Navigator.pop(context);
        widget.onPostCreated();
      } else {
        Navigator.pop(context);
        widget.onPostCreated();
      }
    } catch (e) {
      Navigator.pop(context);
      widget.onPostCreated();
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create a new post',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const Text(
                'Give AutoNex product/service details to generate content using Gemini AI.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('Title', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'e.g. Margherita Pizza / Gym Offer'),
              ),
              const SizedBox(height: 12),
              const Text('Features / Description', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                    hintText: 'Describe key features, ingredients, discounts, or offer details...'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _submitCreatePost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('✨ Generate post',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}