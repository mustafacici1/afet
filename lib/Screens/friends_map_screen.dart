import 'dart:async';
import 'package:afet/Screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class FriendsMapScreen extends StatefulWidget {
  const FriendsMapScreen({super.key});

  @override
  State<FriendsMapScreen> createState() => _FriendsMapScreenState();
}

class _FriendsMapScreenState extends State<FriendsMapScreen> {
  List<Marker> _markers = [];
  bool _isLoading = true;
  String? _errorMessage;
  RealtimeChannel? _statusChannel;
  List<String> _friendIds = [];

  final LatLng _defaultCenter = const LatLng(39.9334, 32.8597);
  final double _defaultZoom = 5.0;

  @override
  void initState() {
    super.initState();
    _initializeAndFetch();
  }

  @override
  void dispose() {
    _statusChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initializeAndFetch() async {
    await _fetchFriendLocations();
    _subscribeToStatusChanges();
  }

  Future<void> _fetchFriendLocations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'Kullanıcı girişi yapılmamış.';
      }

      final profileResponse = await supabase.from('profiles').select('id').eq('auth_uid', userId).single();
      final currentProfileId = profileResponse['id'];

      final friendshipsResponse = await supabase
          .from('friendships')
          .select('requester_id, receiver_id')
          .or('requester_id.eq.$currentProfileId,receiver_id.eq.$currentProfileId')
          .eq('status', 'accepted');

      _friendIds = friendshipsResponse.map<String>((f) =>
          (f['requester_id'] == currentProfileId ? f['receiver_id'] : f['requester_id']).toString()
      ).toList();

      if (_friendIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final friendStatuses = await supabase
          .from('user_status')
          .select('user_id, status, location, profiles(full_name)')
          .filter('user_id', 'in', '(${_friendIds.join(',')})');
      
      final List<Marker> markers = [];
      for (final status in friendStatuses) {
        final marker = _createMarkerFromStatus(status);
        if (marker != null) {
          markers.add(marker);
        }
      }
      
      if (mounted) {
        setState(() {
          _markers = markers;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Konumlar alınamadı: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToStatusChanges() {
    if (_friendIds.isEmpty) return;
    _statusChannel = supabase.channel('public:user_status:map');
    _statusChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_status',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.inFilter,
        column: 'user_id',
        value: _friendIds,
      ),
      callback: (payload) async {
        final newStatus = payload.newRecord;
        if (newStatus.isEmpty) return;
        
        final friendId = newStatus['user_id'] as String;

        final profileData = await supabase.from('profiles').select('full_name').eq('id', friendId).single();
        final Map<String, dynamic> updatedData = Map.from(newStatus);
        updatedData['profiles'] = profileData;

        final newMarker = _createMarkerFromStatus(updatedData);
        if (newMarker != null && mounted) {
          setState(() {
            _markers.removeWhere((m) => m.key == Key(friendId));
            _markers.add(newMarker);
          });
        }
      },
    ).subscribe();
  }
  
  Marker? _createMarkerFromStatus(Map<String, dynamic> status) {
    final locationString = status['location'] as String?;
    final profile = status['profiles'] as Map<String, dynamic>?;

    if (locationString == null || profile == null) return null;

    final locationParts = locationString.replaceAll('POINT(', '').replaceAll(')', '').split(' ');
    if (locationParts.length != 2) return null;

    final longitude = double.tryParse(locationParts[0]);
    final latitude = double.tryParse(locationParts[1]);

    if (longitude == null || latitude == null) return null;
    
    final friendName = profile['full_name'] ?? 'İsimsiz';
    final friendStatus = status['status'] ?? 'bilinmiyor';
    final friendId = status['user_id'];

    return Marker(
      key: Key(friendId),
      point: LatLng(latitude, longitude),
      width: 45,
      height: 45,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                friendId: friendId,
                friendName: friendName,
              ),
            ),
          );
        },
        child: Tooltip(
          message: '$friendName ($friendStatus)',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getMarkerColor(friendStatus).withOpacity(0.8),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: Icon(
              _getMarkerIconData(friendStatus),
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getMarkerColor(String status) {
    switch (status) {
      case 'safe':
        return Colors.green.shade600;
      case 'unsafe':
        return Colors.orange.shade700;
      case 'enkazda':
        return Colors.red.shade700;
      default:
        return Colors.purple.shade600;
    }
  }

  IconData _getMarkerIconData(String status) {
    switch (status) {
      case 'safe':
        return Icons.check;
      case 'unsafe':
        return Icons.warning_amber_rounded;
      case 'enkazda':
        return Icons.dangerous_outlined;
      default:
        return Icons.person_pin;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arkadaşlarımın Konumu'),
        backgroundColor: const Color(0xFF0A0F1D),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF135BEC)),
            ),
          if (_errorMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8.0),
                child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}