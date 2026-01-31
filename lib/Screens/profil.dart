import 'dart:io';
import 'dart:ui'; // ImageFilter için gerekli
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../giris/login_screen.dart'; // Add this import

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressCityController = TextEditingController();
  final _addressDistrictController = TextEditingController();
  final _addressNeighborhoodController = TextEditingController();
  final _addressDetailController = TextEditingController();

  // State Variables
  String? _avatarUrl;
  bool _loading = true;
  bool _uploadingAvatar = false;
  String? _userId;
  List<Map<String, dynamic>> _familyMembers = [];

  // Animation Controller
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _loadAllProfileData();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressCityController.dispose();
    _addressDistrictController.dispose();
    _addressNeighborhoodController.dispose();
    _addressDetailController.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS (Aynı kaldı) ---
  Future<void> _loadAllProfileData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    await _getProfile();
    await _getFamilyMembers();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _getProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('auth_uid', user.id)
          .maybeSingle(); // single yerine maybeSingle hata önler

      if (!mounted) return;

      if (data != null) {
        _userId = data['id'] as String?;
        _fullNameController.text = data['full_name'] as String? ?? '';
        _phoneController.text = data['phone'] as String? ?? '';
        _addressCityController.text = data['address_city'] as String? ?? '';
        _addressDistrictController.text = data['address_district'] as String? ?? '';
        _addressNeighborhoodController.text = data['address_neighborhood'] as String? ?? '';
        _addressDetailController.text = data['address_detail'] as String? ?? '';
        _avatarUrl = data['photo_url'] as String?;
      }
    } catch (error) {
      _showErrorSnackBar('Profil bilgileri alınamadı: $error');
    }
  }

  Future<void> _getFamilyMembers() async {
    if (_userId == null) return;
    try {
      final response = await Supabase.instance.client
          .from('family_members')
          .select()
          .eq('profile_id', _userId!);
      if (mounted) {
        setState(() {
          _familyMembers = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      // Sessiz hata veya log
    }
  }

  Future<void> _updateProfile({String? newAvatarUrl}) async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final updates = {
        'id': _userId, // Eğer id yoksa insert, varsa update (upsert mantığı)
        'auth_uid': Supabase.instance.client.auth.currentUser?.id,
        'full_name': _fullNameController.text,
        'phone': _phoneController.text,
        'address_city': _addressCityController.text,
        'address_district': _addressDistrictController.text,
        'address_neighborhood': _addressNeighborhoodController.text,
        'address_detail': _addressDetailController.text,
        'photo_url': newAvatarUrl ?? _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert kullanırken primary key çakışması önemlidir.
      await Supabase.instance.client.from('profiles').upsert(updates);

      if (mounted) {
        _showSuccessSnackBar('Profil başarıyla güncellendi!');
        setState(() {
          if (newAvatarUrl != null) _avatarUrl = newAvatarUrl;
        });
      }
    } catch (error) {
      _showErrorSnackBar('Profil güncellenemedi: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (!mounted) return;
    setState(() => _uploadingAvatar = true);
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (imageFile == null) {
      if (mounted) setState(() => _uploadingAvatar = false);
      return;
    }

    try {
      final file = File(imageFile.path);
      final fileExt = imageFile.path.split('.').last;
      final fileName = 'public/${_userId ?? "temp"}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage.from('avatars').upload(fileName, file);
      final newAvatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

      // Eğer profil henüz oluşmamışsa önce profili oluşturup sonra avatarı eklemek gerekebilir
      // Ancak basitlik adına direkt update çağırıyoruz.
      await _updateProfile(newAvatarUrl: newAvatarUrl);

    } on StorageException catch (e) {
      _showErrorSnackBar('Avatar yüklenemedi: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _deleteProfile() async {
    final shouldDelete = await _showConfirmDialog('Profili Sil', 'Hesabınızı ve tüm verilerinizi silmek üzeresiniz. Bu işlem geri alınamaz.', isDanger: true);
    if (shouldDelete == true) {
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        if (_userId != null) {
          await Supabase.instance.client.from('profiles').delete().eq('id', _userId!);
        }
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        _showErrorSnackBar('Silme işlemi başarısız.');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteFamilyMember(String memberId) async {
    final shouldDelete = await _showConfirmDialog('Kişiyi Sil', 'Bu kişiyi aile listesinden çıkarmak istiyor musunuz?');
    if (shouldDelete == true) {
      try {
        await Supabase.instance.client.from('family_members').delete().eq('id', memberId);
        _getFamilyMembers();
      } catch (e) {
        _showErrorSnackBar('Silinemedi.');
      }
    }
  }

  // --- UI HELPERS ---
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(message))]),
      backgroundColor: Colors.red.shade900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.check_circle_outline, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(message))]),
      backgroundColor: Colors.green.shade800,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<bool?> _showConfirmDialog(String title, String content, {bool isDanger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2746),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDanger ? Colors.red : const Color(0xFF135BEC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isDanger ? 'Sil' : 'Onayla', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    // Tasarım Sabitleri
    const Color bgDark = Color(0xFF0A0F1D);

    return Scaffold(
      backgroundColor: bgDark,
      body: _loading && _userId == null // İlk yükleme
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF135BEC)))
          : CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _SlideInAnimation(delay: 1, child: _buildPersonalInfoSection()),
                  const SizedBox(height: 25),
                  _SlideInAnimation(delay: 2, child: _buildAddressSection()),
                  const SizedBox(height: 25),
                  _SlideInAnimation(delay: 3, child: _buildFamilySection()),
                  const SizedBox(height: 35),
                  _SlideInAnimation(delay: 4, child: _buildActionButtons()),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0A0F1D),
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        centerTitle: true,
        title: Text(
          _fullNameController.text.isEmpty ? 'Profilim' : _fullNameController.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Arkaplan Dekoru (Gradyan)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF135BEC), Color(0xFF0A0F1D)],
                ),
              ),
            ),
            // Dekoratif daireler
            Positioned(top: -50, right: -50, child: _BlurryCircle(color: Colors.purple.withOpacity(0.3), size: 200)),
            Positioned(bottom: 50, left: -30, child: _BlurryCircle(color: Colors.blue.withOpacity(0.2), size: 150)),

            // Profil Fotoğrafı Alanı
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow Efekti
                    Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF135BEC).withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
                        ],
                      ),
                    ),
                    // Avatar
                    Hero(
                      tag: 'profile_avatar',
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: const Color(0xFF1E2746),
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _uploadingAvatar
                            ? const CircularProgressIndicator(color: Colors.white)
                            : (_avatarUrl == null
                            ? const Icon(Icons.person, size: 60, color: Colors.white54)
                            : null),
                      ),
                    ),
                    // Kamera İkonu
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF135BEC),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (Route<dynamic> route) => false,
                        );
                      }
                    },
                  )      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return _GlassContainer(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Kişisel Bilgiler', Icons.person_outline),
            const SizedBox(height: 20),
            _buildModernTextField(controller: _fullNameController, label: 'Ad Soyad', icon: Icons.badge_outlined, validator: (v) => v!.isEmpty ? 'Gerekli' : null),
            const SizedBox(height: 15),
            _buildModernTextField(controller: _phoneController, label: 'Telefon Numarası', icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Adres Bilgileri', Icons.map_outlined),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildModernTextField(controller: _addressCityController, label: 'Şehir', icon: Icons.location_city)),
              const SizedBox(width: 15),
              Expanded(child: _buildModernTextField(controller: _addressDistrictController, label: 'İlçe', icon: Icons.apartment)),
            ],
          ),
          const SizedBox(height: 15),
          _buildModernTextField(controller: _addressNeighborhoodController, label: 'Mahalle', icon: Icons.signpost_outlined),
          const SizedBox(height: 15),
          _buildModernTextField(controller: _addressDetailController, label: 'Açık Adres', icon: Icons.home_work_outlined, maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildFamilySection() {
    return _GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Aile Üyeleri', Icons.family_restroom_outlined),
              IconButton(
                onPressed: () => _showFamilyMemberDialog(),
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF135BEC), size: 28),
                tooltip: 'Üye Ekle',
              )
            ],
          ),
          const SizedBox(height: 15),
          if (_familyMembers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
              child: const Column(
                children: [
                  Icon(Icons.diversity_3, size: 40, color: Colors.white24),
                  SizedBox(height: 10),
                  Text('Henüz aile üyesi eklenmemiş.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _familyMembers.length,
              separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 20),
              itemBuilder: (context, index) {
                final member = _familyMembers[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF135BEC), width: 1.5)),
                    child: CircleAvatar(
                      backgroundImage: member['photo_url'] != null ? NetworkImage(member['photo_url']) : null,
                      backgroundColor: const Color(0xFF0A0F1D),
                      child: member['photo_url'] == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                    ),
                  ),
                  title: Text(member['full_name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(member['relationship'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.white38, size: 18), onPressed: () => _showFamilyMemberDialog(member: member)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _deleteFamilyMember(member['id'])),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _loading ? null : () => _updateProfile(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135BEC),
              shadowColor: const Color(0xFF135BEC).withOpacity(0.5),
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _loading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _loading ? null : _deleteProfile,
          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
          label: const Text('Hesabımı Kalıcı Olarak Sil', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF135BEC), size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 22),
        filled: true,
        fillColor: const Color(0xFF0A0F1D).withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF135BEC), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  void _showFamilyMemberDialog({Map<String, dynamic>? member}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FamilyMemberForm(profileId: _userId ?? '', member: member),
    );

    if (result == true) {
      _getFamilyMembers();
    }
  }
}

// --- ALT WIDGETLER & ANİMASYONLAR ---

class _GlassContainer extends StatelessWidget {
  final Widget child;
  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2746).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 0),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BlurryCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurryCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent)),
      ),
    );
  }
}

class _SlideInAnimation extends StatelessWidget {
  final Widget child;
  final int delay;
  const _SlideInAnimation({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (delay * 200)),
      curve: Curves.easeOutQuart,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}

// --- Family Member Form (Modernleştirilmiş) ---
class _FamilyMemberForm extends StatefulWidget {
  final String profileId;
  final Map<String, dynamic>? member;

  const _FamilyMemberForm({required this.profileId, this.member});

  @override
  State<_FamilyMemberForm> createState() => __FamilyMemberFormState();
}

class __FamilyMemberFormState extends State<_FamilyMemberForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _relationshipController;
  XFile? _imageFile;
  String? _imageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?['full_name']);
    _relationshipController = TextEditingController(text: widget.member?['relationship']);
    _imageUrl = widget.member?['photo_url'];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (file != null) setState(() => _imageFile = file);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      String? finalImageUrl = _imageUrl;
      if (_imageFile != null) {
        final ext = _imageFile!.path.split('.').last;
        final name = 'public/family/${widget.profileId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await Supabase.instance.client.storage.from('avatars').upload(name, File(_imageFile!.path));
        finalImageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(name);
      }

      final data = {
        'full_name': _nameController.text.trim(),
        'relationship': _relationshipController.text.trim(),
        'profile_id': widget.profileId,
        'photo_url': finalImageUrl,
      };
      if (widget.member != null) data['id'] = widget.member!['id'];

      await Supabase.instance.client.from('family_members').upsert(data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2746),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black45)],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(widget.member == null ? 'Yeni Aile Üyesi' : 'Kişiyi Düzenle', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF0A0F1D),
                backgroundImage: _imageFile != null ? FileImage(File(_imageFile!.path)) : (_imageUrl != null ? NetworkImage(_imageUrl!) : null) as ImageProvider?,
                child: _imageFile == null && _imageUrl == null ? const Icon(Icons.add_a_photo, color: Color(0xFF135BEC)) : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildInput(_nameController, 'Ad Soyad', Icons.person),
            const SizedBox(height: 12),
            _buildInput(_relationshipController, 'Yakınlık Derecesi', Icons.favorite),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF135BEC), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isSaving ? null : _save,
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      validator: (v) => v!.isEmpty ? 'Gerekli' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0A0F1D).withOpacity(0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        labelStyle: const TextStyle(color: Colors.white54),
      ),
    );
  }
}
