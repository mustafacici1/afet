import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/theme.dart'; // Assuming theme data is here.

final supabase = Supabase.instance.client;

// Aile üyesi veri modeli (Değişiklik yok)
class FamilyMember {
  String fullName;
  String relationship;
  int birthYear;
  String? specialNeeds;
  File? image;

  FamilyMember({
    required this.fullName,
    required this.relationship,
    required this.birthYear,
    this.specialNeeds,
    this.image,
  });
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;

  // Controllers for all fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _addressDetailController = TextEditingController();

  bool _isLoading = false;
  File? _profileImage;
  final List<FamilyMember> _familyMembers = [];

  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _neighborhoodController.dispose();
    _addressDetailController.dispose();
    super.dispose();
  }

  // --- Core Business Logic ---

  Future<void> _pickImage(Function(File) onImageSelected) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      onImageSelected(File(pickedFile.path));
    }
  }

  Future<String?> _uploadImage(File image, String userId, String name) async {
    final String fileExt = image.path.split('.').last;
    final String fileName = '$name-$fileExt';
    final String path = 'public/$userId/$fileName';

    await supabase.storage.from('images').upload(path, image,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
    return supabase.storage.from('images').getPublicUrl(path);
  }

  Future<void> _signUp() async {
    // Validate the last page before signing up
    if (!_formKeys[_currentPage].currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authResponse = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = authResponse.user;

      if (user != null) {
        String? profilePhotoUrl;
        if (_profileImage != null) {
          try {
            profilePhotoUrl = await _uploadImage(_profileImage!, user.id, 'profile_photo');
          } catch (e) {
            debugPrint("Profil fotoğrafı yüklenemedi: $e");
          }
        }

        await supabase.from('profiles').insert({
          'auth_uid': user.id,
          'full_name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'photo_url': profilePhotoUrl,
          'address_city': _cityController.text.trim(),
          'address_district': _districtController.text.trim(),
          'address_neighborhood': _neighborhoodController.text.trim(),
          'address_detail': _addressDetailController.text.trim(),
          'role': 'user',
        });

        for (final member in _familyMembers) {
           String? memberPhotoUrl;
          if (member.image != null) {
            try {
              memberPhotoUrl = await _uploadImage(member.image!, user.id, 'family_${DateTime.now().millisecondsSinceEpoch}');
            } catch (e) {
               debugPrint("Aile üyesi fotoğrafı yüklenemedi: $e");
            }
          }
          await supabase.from('family_members').insert({
            'profile_id': user.id, // This should be the profile UUID, not auth_uid
            'full_name': member.fullName,
            'relationship': member.relationship,
            'birth_year': member.birthYear,
            'special_needs': member.specialNeeds,
            'photo_url': memberPhotoUrl,
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kayıt başarılı! Lütfen giriş yapın.'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      }
    } on AuthException catch (error) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Beklenmedik bir hata oluştu: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.seismoDarkTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0 
          ? IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: _previousPage)
          : null,
        title: Text('Adım ${_currentPage + 1} / 4', style: const TextStyle(fontWeight: FontWeight.w300)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Lottie.asset('assets/animation/login.json', fit: BoxFit.cover, width: double.infinity, height: double.infinity),
          Container(color: Colors.black.withOpacity(0.5)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6, // Constrain PageView height
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildStep(0, 'Kişisel Bilgiler', _buildPersonalInfoStep()),
                              _buildStep(1, 'Adres Bilgileri', _buildAddressStep()),
                              _buildStep(2, 'Aile Üyeleri', _buildFamilyStep()),
                              _buildStep(3, 'Hesap Bilgileri', _buildAuthStep()),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildNavigationButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int index, String title, Widget content) {
    return Form(
      key: _formKeys[index],
      child: ListView(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          content,
        ],
      ),
    );
  }

  // --- Page Navigation ---
  void _nextPage() {
    if (!_formKeys[_currentPage].currentState!.validate()) {
      return;
    }
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  // --- Step-specific Widgets ---

  Widget _buildPersonalInfoStep() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage((file) => setState(() => _profileImage = file)),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white.withOpacity(0.1),
            backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
            child: _profileImage == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.white70) : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Profil fotoğrafı eklemek isteğe bağlıdır.',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        const SizedBox(height: 24),
        _buildTextField(_fullNameController, 'Ad Soyad', Icons.person_outline),
        const SizedBox(height: 16),
        _buildTextField(_phoneController, 'Telefon Numarası (Başında 0 olmadan)', Icons.phone_outlined, keyboardType: TextInputType.phone),
      ],
    );
  }

  Widget _buildAddressStep() {
    return Column(
      children: [
        _buildTextField(_cityController, 'İl', Icons.location_city_outlined),
        const SizedBox(height: 16),
        _buildTextField(_districtController, 'İlçe', Icons.map_outlined),
        const SizedBox(height: 16),
        _buildTextField(_neighborhoodController, 'Mahalle', Icons.my_location_outlined),
        const SizedBox(height: 16),
        _buildTextField(_addressDetailController, 'Adres Detayı (Bina, kat, daire no)', Icons.home_outlined, maxLines: 3),
      ],
    );
  }

  Widget _buildFamilyStep() {
    return Column(
      children: [
        if (_familyMembers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Text('Henüz aile üyesi eklenmedi.', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _familyMembers.length,
            itemBuilder: (context, index) {
              final member = _familyMembers[index];
              return Card(
                color: Colors.white.withOpacity(0.15),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member.image != null ? FileImage(member.image!) : null,
                    child: member.image == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(member.fullName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(member.relationship, style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => setState(() => _familyMembers.removeAt(index)),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Aile Üyesi Ekle'),
          onPressed: _showAddFamilyMemberDialog,
        ),
      ],
    );
  }

  Widget _buildAuthStep() {
    return Column(
      children: [
        _buildTextField(_emailController, 'E-posta Adresi', Icons.email_outlined, keyboardType: TextInputType.emailAddress, isEmail: true),
        const SizedBox(height: 16),
        _buildTextField(_passwordController, 'Şifre (En az 6 karakter)', Icons.lock_outline, isPassword: true),
      ],
    );
  }

  // --- Reusable UI Components & Dialogs ---

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool isEmail = false, TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.isEmpty) return '$label alanı boş bırakılamaz.';
        if (isEmail && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Geçerli bir e-posta girin.';
        if (isPassword && value.length < 6) return 'Şifre en az 6 karakter olmalıdır.';
        return null;
      },
      decoration: _inputDecoration(label, icon),
    );
  }
  
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white70),
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildNavigationButtons() {
    return _isLoading
      ? const Center(child: CircularProgressIndicator())
      : SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _currentPage == 3 ? _signUp : _nextPage,
            child: Text(_currentPage == 3 ? 'KAYDI TAMAMLA' : 'İLERİ'),
          ),
        );
  }
  
  void _showAddFamilyMemberDialog() {
    showDialog(
      context: context,
      builder: (context) => AddFamilyMemberDialog(
        onAddMember: (member) {
          setState(() {
            _familyMembers.add(member);
          });
        },
      ),
    );
  }
}

// Dialog widget is mostly unchanged but adapted for the dark theme.
class AddFamilyMemberDialog extends StatefulWidget {
  final Function(FamilyMember) onAddMember;
  const AddFamilyMemberDialog({super.key, required this.onAddMember});

  @override
  State<AddFamilyMemberDialog> createState() => _AddFamilyMemberDialogState();
}

class _AddFamilyMemberDialogState extends State<AddFamilyMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationshipController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _specialNeedsController = TextEditingController();
  File? _image;

  Future<void> _pickImage(Function(File) onImageSelected) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      onImageSelected(File(pickedFile.path));
    }
  }

  void _addMember() {
    if (_formKey.currentState!.validate()) {
      widget.onAddMember(FamilyMember(
        fullName: _nameController.text,
        relationship: _relationshipController.text,
        birthYear: int.tryParse(_birthYearController.text) ?? 0,
        specialNeeds: _specialNeedsController.text.isNotEmpty ? _specialNeedsController.text : null,
        image: _image,
      ));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.85),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.3))
        ),
        title: const Text('Aile Üyesi Ekle', style: TextStyle(color: Colors.white)),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _pickImage((file) => setState(() => _image = file)),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.black.withOpacity(0.3),
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null ? const Icon(Icons.camera_alt, size: 30, color: Colors.white70) : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Ad Soyad', Icons.person), validator: (v) => v!.isEmpty ? 'Zorunlu alan' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _relationshipController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Yakınlık (Eş, Çocuk vb.)', Icons.family_restroom), validator: (v) => v!.isEmpty ? 'Zorunlu alan' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _birthYearController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Doğum Yılı', Icons.cake), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Zorunlu alan' : null),
                const SizedBox(height: 8),
                TextFormField(controller: _specialNeedsController, style: const TextStyle(color: Colors.white), decoration: _inputDecoration('Özel Durum/Hastalık (Varsa)', Icons.medical_services)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('İPTAL', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            onPressed: _addMember, 
            child: const Text('EKLE')
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
      return InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
      );
  }
}