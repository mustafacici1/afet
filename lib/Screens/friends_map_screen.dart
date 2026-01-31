import 'dart:async';
import 'package:afet/Screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

final supabase = Supabase.instance.client;

class FriendsMapScreen extends StatefulWidget {
  const FriendsMapScreen({super.key});

  @override
  State<FriendsMapScreen> createState() => _FriendsMapScreenState();
}

class _FriendsMapScreenState extends State<FriendsMapScreen> {
  final MapController _mapController = MapController();

  List<Marker> _markers = [];
  bool _isLoading = false;
  String? _myProfileId;
  RealtimeChannel? _statusChannel;

  final LatLng _defaultCenter = const LatLng(39.9334, 32.8597); // Ankara

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkPermissions();
    await _updateMyLocation();
    await _fetchLocations();
    _subscribeRealtime();
  }

  // --------------------------------------------------
  // PERMISSIONS
  // --------------------------------------------------
  Future<void> _checkPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  // --------------------------------------------------
  // UPDATE MY LOCATION
  // --------------------------------------------------
  Future<void> _updateMyLocation() async {
    debugPrint("[DEBUG] updateMyLocation: Başladı.");
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("[DEBUG] updateMyLocation: Kullanıcı bulunamadı.");
        return;
      }
      debugPrint("[DEBUG] updateMyLocation: Auth User ID: ${user.id}");

      // profiles.id almak (profiles.auth_uid -> auth user id)
      final profileResp = await supabase
          .from('profiles')
          .select('id')
          .eq('auth_uid', user.id)
          .maybeSingle();

      if (profileResp == null || profileResp['id'] == null) {
        debugPrint(
            "[DEBUG] updateMyLocation: Profile bulunamadı. profiles kaydı oluşturulmamış olabilir.");
        return;
      }

      final profileId = profileResp['id'].toString();
      debugPrint("[DEBUG] updateMyLocation: Profile ID: $profileId");

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
          "[DEBUG] updateMyLocation: Konum alındı: ${position.latitude}, ${position.longitude}");

      _mapController.move(
        LatLng(position.latitude, position.longitude),
        13,
      );

      final point = 'POINT(${position.longitude} ${position.latitude})';
      debugPrint("[DEBUG] updateMyLocation: Point oluşturuldu: $point");

      // profiles.id kullanarak upsert
      await supabase.from('user_status').upsert({
        'user_id': profileId, // profiles.id olmalı
        'location': point,
        'status': 'safe',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint("[DEBUG] updateMyLocation: Upsert başarılı.");
    } catch (e) {
      debugPrint('[DEBUG] updateMyLocation HATA: $e');
    }
  }

  // --------------------------------------------------
  // FETCH FRIEND + MY LOCATIONS
  // --------------------------------------------------
  Future<void> _fetchLocations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    debugPrint("[DEBUG] fetchLocations: Başladı.");

    try {
      final authId = supabase.auth.currentUser?.id;
      if (authId == null) {
        debugPrint("[DEBUG] fetchLocations: Auth ID null, çıkılıyor.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('id')
          .eq('auth_uid', authId)
          .maybeSingle();

      if (profile == null || profile['id'] == null) {
        debugPrint("[DEBUG] fetchLocations: Profile null, çıkılıyor.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _myProfileId = profile['id'].toString();
      debugPrint("[DEBUG] fetchLocations: My Profile ID: $_myProfileId");

      final friends = await supabase
          .from('friendships')
          .select('requester_id, receiver_id')
          .or('requester_id.eq.$_myProfileId,receiver_id.eq.$_myProfileId')
          .eq('status', 'accepted');

      List<dynamic> friendsList = [];
      if (friends is List) {
        friendsList = friends;
      } else if (friends != null) {
        friendsList = [friends];
      }
      debugPrint("[DEBUG] fetchLocations: Arkadaş listesi ham veri: $friendsList");

      final friendIds = friendsList.map<String>((f) {
        final req = f['requester_id']?.toString();
        final rec = f['receiver_id']?.toString();
        if (req == _myProfileId) return rec ?? '';
        return req ?? '';
      }).where((id) => id.isNotEmpty).toList();
      debugPrint("[DEBUG] fetchLocations: Arkadaş ID'leri: $friendIds");

      final ids = [...friendIds, _myProfileId!];
      debugPrint("[DEBUG] fetchLocations: Sorgulanacak toplam ID'ler: $ids");

      if (ids.isEmpty) {
        debugPrint("[DEBUG] fetchLocations: ID listesi boş, çıkılıyor.");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // DİKKAT: Burada "user_status_view" view'ini kullandık.
      // Supabase tarafında daha önce tanımlanmış olmalı:
      // user_id, status, location (ST_AsText), full_name
      final statuses = await supabase
          .from('user_status_view')
          .select('user_id, status, location, full_name')
          .filter('user_id', 'in', '(${ids.map((id) => '"$id"').join(',')})');

      debugPrint("[DEBUG] fetchLocations: Supabase'den gelen status'ler: $statuses");

      final List<Marker> markers = [];

      if (statuses is List) {
        for (final item in statuses) {
          final mapItem = Map<String, dynamic>.from(item);
          final marker = _createMarker(mapItem);
          if (marker != null) {
            markers.add(marker);
          } else {
            debugPrint("[DEBUG] fetchLocations: Marker oluşturulamadı: $mapItem");
          }
        }
      }
      debugPrint("[DEBUG] fetchLocations: Oluşturulan marker sayısı: ${markers.length}");

      if (mounted) {
        setState(() {
          _markers = markers;
        });
      }

      if (_markers.isNotEmpty) {
        _centerMapToMarkers(_markers);
      }

      if (mounted) setState(() => _isLoading = false);
      debugPrint("[DEBUG] fetchLocations: Tamamlandı.");
    } catch (e) {
      debugPrint('[DEBUG] fetchLocations HATA: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Haritayı marker'ların ortasına getir
  void _centerMapToMarkers(List<Marker> markers) {
    try {
      double sumLat = 0;
      double sumLng = 0;
      for (final m in markers) {
        sumLat += m.point.latitude;
        sumLng += m.point.longitude;
      }
      final avgLat = sumLat / markers.length;
      final avgLng = sumLng / markers.length;

      _mapController.move(LatLng(avgLat, avgLng), 13);
    } catch (e) {
      debugPrint('[DEBUG] Center map error: $e');
    }
  }

  // --------------------------------------------------
  // STATUS -> RENK
  // --------------------------------------------------
  Color _getStatusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'safe' || s == 'güvende' || s == 'active') return Colors.green;
    if (s == 'enkazda' || s == 'under_rubble' || s == 'trapped') return Colors.red;
    if (s == 'offline' || s == 'unknown') return Colors.grey;
    return Colors.orange; // default / other statuses
  }

  // --------------------------------------------------
  // MARKER (KÜÇÜK, ŞIK, STATUS RENKLİ)
  // --------------------------------------------------
  Marker? _createMarker(Map<String, dynamic> data) {
    debugPrint("[DEBUG] createMarker: Gelen veri: $data");
    final locObj = data['location'];
    if (locObj == null) {
      debugPrint("[DEBUG] createMarker: 'location' objesi null.");
      return null;
    }

    String locStr = locObj.toString();
    // view ile ST_AsText döndüğümüz için genelde "POINT(lng lat)" string'i gelecek.
    // Yine de SRID varsa temizle:
    locStr = locStr.replaceAll(RegExp(r'SRID=\d+;'), '');

    if (!locStr.startsWith('POINT')) {
      debugPrint("[DEBUG] createMarker: 'location' 'POINT' ile başlamıyor: $locStr");
      return null;
    }

    final clean = locStr.replaceAll('POINT(', '').replaceAll(')', '').trim();
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      debugPrint("[DEBUG] createMarker: 'location' parçalara ayrılamadı: $clean");
      return null;
    }

    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lat == null || lng == null) {
      debugPrint("[DEBUG] createMarker: Lat/Lng parse edilemedi: ${parts[0]}, ${parts[1]}");
      return null;
    }
    debugPrint("[DEBUG] createMarker: Parsed Lat: $lat, Lng: $lng");

    final userId = data['user_id']?.toString() ?? '';
    // artık view'den full_name geliyor
    String fullName = (data['full_name']?.toString() ?? 'Gizli').trim();
    if (fullName.isEmpty) fullName = 'Gizli';

    final isMe = userId == _myProfileId;
    final status = data['status']?.toString() ?? 'unknown';
    final statusColor = _getStatusColor(status);

    final firstLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    // Yeni boyutlar ve tasarım
    const markerSize = 72.0; // container total
    const avatarSize = 44.0; // circle avatar diameter
    const borderWidth = 3.0;
    const letterSize = 18.0;
    const labelFontSize = 13.0;

    return Marker(
      point: LatLng(lat, lng),
      width: markerSize,
      height: markerSize + 18,
      alignment: Alignment.center,
      child: Transform.translate(
        offset: Offset(0, - (markerSize / 4)),
        child: GestureDetector(
          onTap: () {
            if (!isMe) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatScreen(friendId: userId, friendName: fullName),
                ),
              );
            } else {
              _mapController.move(LatLng(lat, lng), 15);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // avatar + glow
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: statusColor, width: borderWidth),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.35),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    firstLetter,
                    style: TextStyle(
                      fontSize: letterSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  isMe ? 'SİZ' : fullName.split(' ')[0],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: labelFontSize,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // REALTIME
  // --------------------------------------------------
  void _subscribeRealtime() {
    // user_status tablosundaki değişiklikleri dinliyoruz.
    _statusChannel = supabase.channel('public:user_status');
    _statusChannel!
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_status',
      callback: (_) => _fetchLocations(),
    )
        .subscribe();
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harita'),
        backgroundColor: const Color(0xFF0A0F1D),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _defaultCenter,
              zoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_isLoading)
            const Positioned(
              top: 12,
              right: 12,
              child: CircularProgressIndicator(),
            ),
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () async {
                await _updateMyLocation();
                await _fetchLocations();
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
