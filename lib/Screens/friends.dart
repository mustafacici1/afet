import 'package:afet/Screens/chat_screen.dart';
import 'package:afet/Screens/friends_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async'; // Timer ve Stream işlemleri için şart

// Not: Bu dosyada RealtimeChannel kullanıyorsanız onPostgresChanges metodunu kullanın.
// Hata aldığınız satırları (on, RealtimeListenTypes, ChannelFilter)
// yukarıdaki Map örneğindeki gibi onPostgresChanges ile güncelleyin.
final supabase = Supabase.instance.client;

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  
  Future<List<Map<String, dynamic>>>? _friendsFuture;
  Future<List<Map<String, dynamic>>>? _requestsFuture;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _currentProfileId;
  RealtimeChannel? _statusChannel;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeAndFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeAndFetch() async {
    final authId = supabase.auth.currentUser?.id;
    if (authId == null) return;
    
    try {
      final profileResponse = await supabase.from('profiles').select('id').eq('auth_uid', authId).single();
      if (mounted) {
        _currentProfileId = profileResponse['id'];
        _refreshData();
        
        _statusChannel = supabase.channel('public:user_status');
        _statusChannel!.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_status',
          callback: (payload) {
            _refreshData();
          },
        ).subscribe();
      }
    } catch (e) {
      debugPrint("Could not fetch profile_id: $e");
    }
  }

  void _refreshData() {
    if (_currentProfileId == null || !mounted) return;
    setState(() {
      _friendsFuture = _getFriends();
      _requestsFuture = _getFriendRequests();
    });
  }

  // --- DATA METHODS ---

  Future<List<Map<String, dynamic>>> _getFriends() async {
    if (_currentProfileId == null) return [];
    try {
      final response = await supabase.rpc('get_friends_with_status', params: {'p_user_id': _currentProfileId});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Friends RPC Error, falling back to client-side join: $e");
      return _getFriendsClientSide();
    }
  }

  // Client-side fallback if the RPC function doesn't exist
  Future<List<Map<String, dynamic>>> _getFriendsClientSide() async {
      if (_currentProfileId == null) return [];
      final response = await supabase
          .from('friendships')
          .select('requester_id, receiver_id')
          .or('requester_id.eq.$_currentProfileId,receiver_id.eq.$_currentProfileId')
          .eq('status', 'accepted');
      if (response.isEmpty) return [];
      final friendProfileIds = response.map((f) =>
          f['requester_id'] == _currentProfileId ? f['receiver_id'] : f['requester_id']
      ).toList();
      if (friendProfileIds.isEmpty) return [];

      final profiles = await supabase.from('profiles').select('id, full_name, photo_url').filter('id', 'in', '(${friendProfileIds.map((id) => '"$id"').join(',')})');
      final statusResponse = await supabase.from('user_status').select('user_id, status').filter('user_id', 'in', '(${friendProfileIds.map((id) => '"$id"').join(',')})');
      
      return profiles.map((profile) {
        final status = statusResponse.firstWhere((s) => s['user_id'] == profile['id'], orElse: () => <String, dynamic>{'status': 'bilinmiyor'});
        return {...profile, ...status};
      }).toList();
  }

  Future<List<Map<String, dynamic>>> _getFriendRequests() async {
    if (_currentProfileId == null) return [];
    try {
      final response = await supabase
          .from('friendships')
          .select('id, profiles:requester_id(id, full_name, photo_url)')
          .eq('receiver_id', _currentProfileId!)
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Requests Error: $e");
      return [];
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (_currentProfileId == null || trimmedQuery.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isSearching = true);

    List<Map<String, dynamic>> results = [];
    try {
      final response = await supabase.rpc('search_users', params: {
        'p_user_id': _currentProfileId,
        'p_query': trimmedQuery,
      });
      results = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Search RPC Error: $e");
      // Keep results as empty list in case of error
    } finally {
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _updateFriendshipStatus(String friendshipId, String status) async {
    await supabase.from('friendships').update({'status': status}).eq('id', friendshipId);
    _refreshData();
  }

  Future<void> _removeFriend(String friendId) async {
    await supabase.from('friendships').delete().or('and(requester_id.eq.$_currentProfileId,receiver_id.eq.$friendId),and(requester_id.eq.$friendId,receiver_id.eq.$_currentProfileId)');
    _refreshData();
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    if (_currentProfileId == null) return;
    try {
      await supabase.from('friendships').insert({'requester_id': _currentProfileId, 'receiver_id': receiverId});
      _onSearchChanged(_searchController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek gönderildi'), backgroundColor: Color(0xFF135BEC)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('duplicate key') ? 'Zaten bir bağlantı veya istek mevcut.' : 'Bir hata oluştu'), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Güvenlik Ağı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicator: const UnderlineTabIndicator(borderSide: BorderSide(width: 3, color: Color(0xFF135BEC)), insets: EdgeInsets.symmetric(horizontal: 20)),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'Arkadaşlar'), Tab(text: 'İstekler'), Tab(text: 'Keşfet')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFriendsList(), _buildRequestsList(), _buildSearchPage()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FriendsMapScreen()),
          );
        },
        backgroundColor: const Color(0xFF135BEC),
        child: const Icon(Icons.map, color: Colors.white),
      ),
    );
  }
  
  Widget _buildFriendsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _friendsFuture == null) return const Center(child: CircularProgressIndicator(color: Color(0xFF135BEC)));
        if (snapshot.hasError) return _buildEmptyState(Icons.error_outline, 'Veriler yüklenemedi.');
        final friends = snapshot.data ?? [];
        if (friends.isEmpty) return _buildEmptyState(Icons.group_off, 'Henüz kimse eklenmemiş.');
        return RefreshIndicator(onRefresh: () async => _refreshData(), child: _buildUserListView(friends, 'friend'));
      },
    );
  }
  
  Widget _buildRequestsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _requestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _requestsFuture == null) return const Center(child: CircularProgressIndicator(color: Color(0xFF135BEC)));
        if (snapshot.hasError) return _buildEmptyState(Icons.error_outline, 'İstekler yüklenemedi.');
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return _buildEmptyState(Icons.notifications_none, 'Yeni istek yok.');
        return RefreshIndicator(onRefresh: () async => _refreshData(), child: _buildUserListView(requests, 'request'));
      },
    );
  }

  Widget _buildSearchPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              hintText: 'Kullanıcı adı ile ara...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF135BEC)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFF135BEC)),
        Expanded(
          child: _searchResults.isEmpty
                  ? _buildEmptyState(Icons.search, _searchController.text.isEmpty ? 'Kişi bulmak için yazmaya başla.' : 'Aramanızla eşleşen kimse bulunamadı.')
                  : _buildUserListView(_searchResults, 'search'),
        ),
      ],
    );
  }

  ListView _buildUserListView(List<Map<String, dynamic>> users, String type) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final profile = (type == 'request' ? user['profiles'] : user) as Map<String, dynamic>;
        Widget trailing;
        switch (type) {
          case 'friend':
            trailing = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.message, color: Colors.white54),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          friendId: profile['id'],
                          friendName: profile['full_name'] ?? 'İsimsiz',
                        ),
                      ),
                    );
                  },
                ),
                IconButton(icon: const Icon(Icons.more_vert, color: Colors.white54), onPressed: () => _showFriendOptions(profile)),
              ],
            );
            break;
          case 'request':
            trailing = Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.check_circle, color: Colors.greenAccent), onPressed: () => _updateFriendshipStatus(user['id'], 'accepted')),
              IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () => _updateFriendshipStatus(user['id'], 'declined')),
            ]);
            break;
          case 'search':
            trailing = _buildFriendshipButton(profile['friendship_status'] as String? ?? 'none', profile['id']);
            break;
          default:
            trailing = const SizedBox.shrink();
        }
        
        final status = (profile['status'] as String?) ?? 'bilinmiyor';
        final isSafe = status == 'safe';
        final color = isSafe ? Colors.greenAccent : (status == 'unsafe' ? Colors.orangeAccent : Colors.redAccent);

        return Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.0)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: _buildSafeAvatar(profile['photo_url'], color: type == 'friend' ? color : null),
              title: Text(profile['full_name'] ?? 'İsimsiz', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: type == 'friend' ? Text(status.toUpperCase(), style: TextStyle(color: color.withOpacity(0.9), fontWeight: FontWeight.bold, letterSpacing: 0.5)) : null,
              trailing: trailing,
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFriendshipButton(String status, String userId) {
    switch (status) {
      case 'accepted':
        return ElevatedButton(onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Arkadaş'));
      case 'pending':
        return ElevatedButton(onPressed: null, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('İstek Gönderildi'));
      default:
        return ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF135BEC), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => _sendFriendRequest(userId),
          child: const Text('Ekle'),
        );
    }
  }

  Widget _buildSafeAvatar(String? url, {Color? color}) {
    final bool hasImage = url != null && url.isNotEmpty;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white10,
          backgroundImage: hasImage ? NetworkImage(url) : null,
          child: !hasImage ? const Icon(Icons.person, color: Colors.white54) : null,
        ),
        if (color != null)
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0A0F1D), width: 2), boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]),
          ),
      ],
    );
  }

  void _showFriendOptions(Map<String, dynamic> friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0F1D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.person_remove, color: Colors.redAccent),
            title: const Text('Arkadaşlıktan Çıkar', style: TextStyle(color: Colors.white)),
            onTap: () {
              _removeFriend(friend['id']);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}