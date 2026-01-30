import 'dart:async';
import 'dart:ui';
import 'package:afet/models/earthquake.dart';
import 'package:afet/services/earthquake_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:torch_light/torch_light.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';

// Projenizdeki diğer dosyalar
import 'last_earthquake.dart';
import 'friends.dart';
import 'forum_screen.dart';
import 'hasar_tespit_screen.dart';
import 'profil.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isFlashlightOn = false;
  bool _isSosActive = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;

  Map<String, dynamic>? _profile;
  String? _userStatus;
  int _friendsSafeCount = 0;
  int _forumPostCount = 0;
  String _location = 'Konum alınıyor...';
  Earthquake? _latestEarthquake;
  bool _isLoadingEarthquake = true;

  @override
  void initState() {
    super.initState();
    _loadWhistleSound();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Don't show snackbar on initial load
    _refreshData(showSnackbar: false);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _getLatestEarthquake() async {
    if (!mounted) return;
    debugPrint("Fetching latest earthquake...");
    setState(() {
      _isLoadingEarthquake = true;
    });
    try {
      final earthquake = await EarthquakeService.fetchLatestEarthquake();
      if (mounted) {
        setState(() {
          _latestEarthquake = earthquake;
          _isLoadingEarthquake = false;
        });
        debugPrint("Latest earthquake: ${_latestEarthquake?.title}");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEarthquake = false;
        });
        debugPrint("Failed to load latest earthquake: $e");
      }
    }
  }

  Future<void> _getProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('auth_uid', userId)
          .single();

      if (mounted) {
        setState(() {
          _profile = data;
          _location = '${_profile?['address_city'] ?? 'Bilinmiyor'}, Türkiye';
        });
        await _getUserStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _location = 'Profil bulunamadı';
        });
      }
    }
  }

  Future<void> _getUserStatus() async {
    try {
      final userId = _profile?['id'];
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('user_status')
          .select('status')
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _userStatus = data['status'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userStatus = 'safe'; // Default status
        });
      }
    }
  }

  Future<void> _getFriendsStatus() async {
    try {
      final count = await Supabase.instance.client
          .from('user_status')
          .count(CountOption.exact)
          .eq('status', 'safe');

      if (mounted) {
        setState(() {
          _friendsSafeCount = count;
        });
      }
    } catch (e) {
      debugPrint('Friends count error: $e');
    }
  }

  Future<void> _getForumPostCount() async {
    try {
      final count = await Supabase.instance.client
          .from('forum_posts')
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _forumPostCount = count;
        });
      }
    } catch (e) {
      debugPrint('Forum count error: $e');
    }
  }

  Future<void> _loadWhistleSound() async {
    try {
      await _audioPlayer.setSource(AssetSource('sounds/whistle.mp3'));
    } catch (e) {
      debugPrint('Error loading whistle: $e');
    }
  }

  List<Widget> get _widgetOptions => <Widget>[
        _buildHomeContent(),
        const LastEarthquakeScreen(),
        const FriendsScreen(),
        const ForumScreen(),
        const HasarTespitScreen(),
        const ProfilScreen(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _toggleFlashlight() async {
    try {
      if (await TorchLight.isTorchAvailable()) {
        if (_isFlashlightOn) {
          await TorchLight.disableTorch();
        } else {
          await TorchLight.enableTorch();
        }
        setState(() {
          _isFlashlightOn = !_isFlashlightOn;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fener hatası: $e'),
            backgroundColor: const Color(0xFFFF4D4D),
          ),
        );
      }
    }
  }

  Future<void> _playWhistle() async {
    try {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Whistle error: $e');
    }
  }

  void _activateSOS() {
    setState(() {
      _isSosActive = !_isSosActive;
    });

    if (_isSosActive) {
      _showStatusDialog();
    }
  }

  Future<void> _refreshData({bool showSnackbar = true}) async {
    if (mounted && showSnackbar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veriler yenileniyor...'),
          backgroundColor: Color(0xFF135BEC),
          duration: Duration(seconds: 1),
        ),
      );
    }
    await Future.wait([
      _getProfile(),
      _getFriendsStatus(),
      _getForumPostCount(),
      _getLatestEarthquake(),
    ]);
  }

  Future<String> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    final position = await Geolocator.getCurrentPosition();
    return 'POINT(${position.longitude} ${position.latitude})';
  }

  Future<void> _updateUserStatus(String status) async {
    final userId = _profile?['id'];
    if (userId == null) return;

    try {
      final location = await _getCurrentLocation();

      await Supabase.instance.client.from('user_status').upsert({
        'user_id': userId,
        'status': status,
        'location': location,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Durum güncellendi: $status'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
      _getUserStatus();
      _getFriendsStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Durum güncellenemedi: $e'),
            backgroundColor: const Color(0xFFFF4D4D),
          ),
        );
      }
    }
  }

  Future<void> _createAidRequest(String item) async {
    final userId = _profile?['id'];
    if (userId == null) return;

    try {
      final location = await _getCurrentLocation();
      await Supabase.instance.client.from('aid_requests').insert({
        'requester_id': userId,
        'type': 'need',
        'item': item,
        'location': location,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yardım talebiniz iletildi.'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yardım talebi oluşturulamadı: $e'),
            backgroundColor: const Color(0xFFFF4D4D),
          ),
        );
      }
    }
  }

  void _showStatusDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF192233).withOpacity(0.95),
              const Color(0xFF0A0F1D),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'DURUM BİLDİRİMİ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mevcut durumunuzu seçin',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            _buildStatusOption(
              'GÜVENDEYİM',
              Icons.check_circle_outline,
              const Color(0xFF4CAF50),
              'Konumum güvenli, yardıma ihtiyacım yok',
              () {
                _updateUserStatus('safe');
                Navigator.pop(context);
                setState(() => _isSosActive = false);
              },
            ),
            const SizedBox(height: 16),
            _buildStatusOption(
              'YARDIM İSTİYORUM',
              Icons.warning_amber_rounded,
              const Color(0xFFFF9800),
              'Tehlike altındayım, konum paylaşılsın',
              () {
                _updateUserStatus('unsafe');
                _createAidRequest('Genel Yardım');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
            _buildStatusOption(
              'ENKAZ ALTINDAYIM',
              Icons.emergency,
              const Color(0xFFFF4D4D),
              'Kritik durum - Acil SOS sinyali gönder',
              () {
                _updateUserStatus('critical');
                _createAidRequest('Enkaz Altında');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final zoneColor = _userStatus == 'safe'
        ? const Color(0xFF4CAF50)
        : (_userStatus == 'unsafe'
            ? const Color(0xFFFF9800)
            : const Color(0xFFFF4D4D));
    final zoneText = _userStatus?.toUpperCase() ?? 'YÜKLENİYOR';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0F1D),
            Color(0xFF0A0F1D),
          ],
        ),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          backgroundColor: const Color(0xFF192233),
          color: const Color(0xFF135BEC),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 48),
              Container( // Status Header
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF192233).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF135BEC).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFF135BEC),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: zoneColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: zoneColor.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ZONE: $zoneText',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _location,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _refreshData(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF192233).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.cloud_sync,
                          color: Color(0xFFFF9800),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row( // Tactical Toggles
                children: [
                  Expanded(
                    child: _buildTacticalButton(
                      icon: _isFlashlightOn
                          ? Icons.flashlight_on
                          : Icons.flashlight_off,
                      label: 'FLASHLIGHT',
                      isActive: _isFlashlightOn,
                      onTap: _toggleFlashlight,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTacticalButton(
                      icon: Icons.campaign,
                      label: 'WHISTLE',
                      isActive: false,
                      onTap: _playWhistle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Row( // Section Header
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tactical Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'LIVE TELEMETRY',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildEarthquakeCard(),
              const SizedBox(height: 16),
              Row( // Grid Cards
                children: [
                  Expanded(
                    child: _buildGridCard(
                      icon: Icons.group,
                      title: 'Güvenlik Ağı',
                      subtitle: '$_friendsSafeCount Kişi Güvende',
                      color: const Color(0xFF42A5F5),
                      subtitleColor: const Color(0xFF4CAF50),
                      onTap: () => _onItemTapped(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGridCard(
                      icon: Icons.forum,
                      title: 'Topluluk',
                      subtitle: '$_forumPostCount Yerel Paylaşım',
                      color: const Color(0xFFAB47BC),
                      subtitleColor: Colors.white.withOpacity(0.5),
                      onTap: () => _onItemTapped(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell( // Damage Report
                onTap: () => _onItemTapped(4),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF192233).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFF4D4D).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.report_problem,
                          color: Color(0xFFFF4D4D),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Damage Report',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Submit urgent incident details',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withOpacity(0.3),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container( // Active Route
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF135BEC).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF135BEC).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF135BEC).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.map,
                        color: Color(0xFF135BEC),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACTIVE ROUTE',
                            style: TextStyle(
                              color: const Color(0xFF135BEC).withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'To: Emergency Shelter #4',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.near_me,
                      color: Colors.white.withOpacity(0.2),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarthquakeCard() {
    Widget content;
    if (_isLoadingEarthquake) {
      content = const Center(key: ValueKey('loading'), child: CircularProgressIndicator(color: Colors.white));
    } else if (_latestEarthquake == null) {
      content = const Center(key: ValueKey('no-data'), child: Text('Son deprem verisi bulunamadı.', style: TextStyle(color: Colors.white70)));
    } else {
      content = Column(
        key: ValueKey(_latestEarthquake!.rawDateTime),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Son Deprem',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _latestEarthquake!.title,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                               ),
               ),
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D4D),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4D4D).withOpacity(_pulseController.value),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFFFF4D4D),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFF135BEC).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 _buildWaveBar(0.25, const Color(0xFF135BEC).withOpacity(0.2)),
                _buildWaveBar(0.5, const Color(0xFF135BEC).withOpacity(0.3)),
                _buildWaveBar(0.33, const Color(0xFF135BEC).withOpacity(0.4)),
                _buildWaveBar(0.75, const Color(0xFF135BEC).withOpacity(0.6)),
                _buildWaveBar(0.86, const Color(0xFFFF4D4D).withOpacity(0.6)),
                _buildWaveBar(0.5, const Color(0xFF135BEC).withOpacity(0.4)),
                _buildWaveBar(0.25, const Color(0xFF135BEC).withOpacity(0.2)),
                _buildWaveBar(0.16, const Color(0xFF135BEC).withOpacity(0.1)),
                _buildWaveBar(0.4, const Color(0xFF135BEC).withOpacity(0.4)),
                _buildWaveBar(0.33, const Color(0xFF135BEC).withOpacity(0.2)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mag: ${_latestEarthquake!.magnitude.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Derinlik: ${_latestEarthquake!.depth.toStringAsFixed(1)} km',
                 style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF135BEC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DETAYLAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return InkWell(
      onTap: () => _onItemTapped(1),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF192233).withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildWaveBar(double height, Color color) {
    return Container(
      width: 8,
      height: 80 * height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }

  Widget _buildTacticalButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF192233).withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF135BEC).withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF135BEC).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF135BEC).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF135BEC).withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: isActive
                    ? const Color(0xFF135BEC)
                    : Colors.white.withOpacity(0.8),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF192233).withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF192233).withOpacity(0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavIcon(Icons.home, 0),
            _buildNavIcon(Icons.map, 1),
            _buildSOSButton(),
            _buildNavIcon(Icons.shield_outlined, 2),
            _buildNavIcon(Icons.person, 5),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: isSelected
              ? const Color(0xFF135BEC)
              : Colors.white.withOpacity(0.4),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: _activateSOS,
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D4D),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF0A0F1D),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4D4D).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
