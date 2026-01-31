import 'package:flutter/material.dart';
import 'dart:math' as math;

// --- DATA MODELS ---
enum ParticipationStatus { none, attending, notAttending }

class ForumPost {
  final String id;
  final String title;
  final String author;
  final String authorAvatar;
  final String timeAgo;
  final String content;
  final String category;
  final String city;
  final IconData icon;
  final int likes;
  final int comments;
  final int views;
  final List<String> tags;
  final Color categoryColor;
  final bool isPinned;
  final bool isUrgent;

  ForumPost({
    required this.id,
    required this.title,
    required this.author,
    required this.authorAvatar,
    required this.timeAgo,
    required this.content,
    required this.category,
    required this.city,
    required this.icon,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.tags = const [],
    required this.categoryColor,
    this.isPinned = false,
    this.isUrgent = false,
  });
}

class Comment {
  final String id;
  final String author;
  final String authorAvatar;
  final String content;
  final String timeAgo;
  final int likes;

  Comment({
    required this.id,
    required this.author,
    required this.authorAvatar,
    required this.content,
    required this.timeAgo,
    this.likes = 0,
  });
}

// --- DETAIL SCREEN ---
class ForumDetailScreen extends StatefulWidget {
  final ForumPost post;
  final VoidCallback onParticipate;
  final VoidCallback onNotParticipate;
  final ParticipationStatus participationStatus;

  const ForumDetailScreen({
    super.key,
    required this.post,
    required this.onParticipate,
    required this.onNotParticipate,
    required this.participationStatus,
  });

  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _heartController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _heartAnimation;

  bool _isLiked = false;
  int _localLikes = 0;
  bool _isBookmarked = false;
  final TextEditingController _commentController = TextEditingController();

  final List<Comment> _comments = [
    Comment(
      id: '1',
      author: 'Ayşe Yılmaz',
      authorAvatar: '👩',
      content: 'Çok bilgilendirici bir paylaşım olmuş, teşekkürler! Özellikle deprem çantası konusunda çok eksiklerimiz vardı.',
      timeAgo: '15 dk önce',
      likes: 12,
    ),
    Comment(
      id: '2',
      author: 'Mehmet Kaya',
      authorAvatar: '👨',
      content: 'Bunlara ek olarak powerbank ve radyo da eklenebilir. Deprem anında çok işe yarıyor.',
      timeAgo: '1 saat önce',
      likes: 8,
    ),
    Comment(
      id: '3',
      author: 'Zeynep Demir',
      authorAvatar: '👩‍⚕️',
      content: 'İlk yardım kitinde mutlaka yanık merhemi ve antiseptik olsun. Ayrıca kronik hastalığı olanlar ilaçlarını unutmasın!',
      timeAgo: '2 saat önce',
      likes: 15,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _localLikes = widget.post.likes;

    // Controller'lar önce tanımlanıyor
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _heartController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Animasyonlar controller'lara bağlanıyor
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _heartAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _heartController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _localLikes += _isLiked ? 1 : -1;
    });
    _heartController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: CustomScrollView(
        slivers: [
          _buildAnimatedAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPostHeader(),
                    _buildPostContent(),
                    _buildPostStats(),
                    _buildActionButtons(),
                    if (widget.post.category == 'Gönüllülük' || widget.post.category == 'Eğitim')
                      _buildParticipationSection(),
                    _buildTagsSection(),
                    const Divider(color: Colors.white12, height: 40),
                    _buildCommentsSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCommentInput(),
    );
  }

  Widget _buildAnimatedAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: widget.post.categoryColor.withOpacity(0.9),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          widget.post.category,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.post.categoryColor,
                widget.post.categoryColor.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  widget.post.icon,
                  size: 150,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          onPressed: () => setState(() => _isBookmarked = !_isBookmarked),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            // Share functionality
          },
        ),
      ],
    );
  }

  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.post.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.push_pin, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Text('SABİTLENMİŞ', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Text(
            widget.post.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [widget.post.categoryColor, widget.post.categoryColor.withOpacity(0.5)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF192233),
                  child: Text(widget.post.authorAvatar, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(
                          widget.post.timeAgo,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(
                          widget.post.city,
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        widget.post.content,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildPostStats() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF192233).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.visibility, '${widget.post.views}', 'Görüntülenme'),
          _buildStatItem(Icons.favorite, '$_localLikes', 'Beğeni'),
          _buildStatItem(Icons.comment, '${widget.post.comments}', 'Yorum'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ScaleTransition(
              scale: _heartAnimation,
              child: ElevatedButton.icon(
                onPressed: _toggleLike,
                icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                label: const Text('Beğen'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _isLiked ? const Color(0xFFE53935) : const Color(0xFF192233),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _isLiked ? const Color(0xFFE53935) : Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.ios_share),
              label: const Text('Paylaş'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF192233),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.post.categoryColor.withOpacity(0.2),
            widget.post.categoryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.post.categoryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: widget.post.categoryColor),
              const SizedBox(width: 8),
              const Text(
                'Katılım Durumu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildParticipationButton(
                  icon: Icons.check_circle,
                  label: 'Katılacağım',
                  color: Colors.green,
                  isSelected: widget.participationStatus == ParticipationStatus.attending,
                  onPressed: widget.onParticipate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildParticipationButton(
                  icon: Icons.cancel,
                  label: 'Katılmayacağım',
                  color: Colors.red,
                  isSelected: widget.participationStatus == ParticipationStatus.notAttending,
                  onPressed: widget.onNotParticipate,
                ),
              ),
            ],
          ),
          if (widget.participationStatus != ParticipationStatus.none) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.participationStatus == ParticipationStatus.attending
                        ? Icons.check_circle
                        : Icons.info,
                    color: widget.participationStatus == ParticipationStatus.attending
                        ? Colors.green
                        : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.participationStatus == ParticipationStatus.attending
                          ? 'Harika! Katılımınız kaydedildi.'
                          : 'Katılmayacağınız bilgisi alındı.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipationButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    // Create darker and lighter versions of the color
    final darkColor = Color.fromRGBO(
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
      1,
    );
    final veryDarkColor = Color.fromRGBO(
      (color.red * 0.4).round(),
      (color.green * 0.4).round(),
      (color.blue * 0.4).round(),
      1,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton.icon(
        onPressed: isSelected ? null : onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: isSelected ? darkColor : color,
          disabledBackgroundColor: veryDarkColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isSelected ? 0 : 4,
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    if (widget.post.tags.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.post.tags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.post.categoryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.post.categoryColor.withOpacity(0.4)),
            ),
            child: Text(
              '#$tag',
              style: TextStyle(
                color: widget.post.categoryColor.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.comment, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                'Yorumlar (${_comments.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._comments.map((comment) => _buildCommentCard(comment)).toList(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCommentCard(Comment comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF192233).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0A0F1D),
                child: Text(comment.authorAvatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      comment.timeAgo,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.white54, size: 20),
                onPressed: () {},
              ),
              Text(
                '${comment.likes}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment.content,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF192233),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Yorumunuzu yazın...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0A0F1D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: widget.post.categoryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () {
                  // Send comment
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MAIN FORUM SCREEN ---
class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  String _selectedCity = 'Tümü';
  String _sortBy = 'Yeni';

  final Set<String> _readPostIds = {};
  final Map<String, ParticipationStatus> _participationStatus = {};
  // _likedPostIds kullanılmıyordu ama tanımlanmış, silmedim:
  final Set<String> _likedPostIds = {};

  @override
  void initState() {
    super.initState();
    // 1. TabController
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() => setState(() {}));

    // 2. ÖNCE Controller'ı başlat (HATA BURADA ÇÖZÜLDÜ)
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 3. SONRA Animasyonu bu controller'a bağla
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );

    // 4. En son animasyonu tetikle
    _fabController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  final List<ForumPost> _forumPosts = [
    ForumPost(
      id: '1',
      title: 'ACİL: Deprem Çantasında Olması Gerekenler',
      author: 'AFAD Türkiye',
      authorAvatar: '🏛️',
      timeAgo: '2 dakika önce',
      category: 'Eğitim',
      city: 'Tümü',
      icon: Icons.school,
      content: 'Deprem çantası hazırlarken mutlaka bulundurmanız gerekenler:\n\n• 3 günlük su (kişi başı günde 2 litre)\n• Uzun ömürlü yiyecekler (konserveler, kuru meyveler)\n• İlk yardım kiti ve ilaçlar\n• El feneri ve yedek piller\n• Düdük\n• Radyo (pilli veya şarjlı)\n• Önemli belgelerin fotokopileri\n• Nakit para\n• Hijyen malzemeleri\n• Battaniye ve ısı yalıtım örtüsü\n• Çakı veya çok amaçlı alet\n\nÇantanızı düzenli olarak kontrol edin ve son kullanma tarihlerini takip edin!',
      likes: 456,
      comments: 89,
      views: 1234,
      tags: ['depremçantası', 'hazırlık', 'afet', 'güvenlik'],
      categoryColor: const Color(0xFF2196F3),
      isPinned: true,
      isUrgent: true,
    ),
    ForumPost(
      id: '2',
      title: 'Toplanma Alanları Güncellendi - Önemli Duyuru',
      author: 'İBB Afet Koordinasyon',
      authorAvatar: '🏢',
      timeAgo: '15 dakika önce',
      category: 'Duyurular',
      city: 'İstanbul',
      icon: Icons.campaign,
      content: 'Değerli hemşehrilerimiz,\n\nİstanbul genelindeki tüm toplanma alanları e-Devlet sistemi üzerinden güncellenmiştir. Lütfen:\n\n1. E-Devlet\'e giriş yapın\n2. "Toplanma Alanı Sorgulama" bölümüne gidin\n3. Adresinizi girin\n4. Size en yakın 3 toplanma alanını not edin\n\nToplanma alanlarına giden yolları önceden keşfedin. Alternatif yollar belirleyin. Aile bireylerinizle buluşma noktasını konuşun.\n\nAfet anında panik yapmayın, önceden belirlediğiniz toplanma alanına gidin.',
      likes: 234,
      comments: 45,
      views: 890,
      tags: ['toplanmalanı', 'edevlet', 'güvenlik', 'istanbul'],
      categoryColor: const Color(0xFFFF9800),
      isPinned: true,
    ),
    ForumPost(
      id: '3',
      title: 'GÖNÜLLÜ ARAĞI - Yardım Malzemesi Paketleme',
      author: 'Ahbap Derneği',
      authorAvatar: '🤝',
      timeAgo: '45 dakika önce',
      category: 'Gönüllülük',
      city: 'Ankara',
      icon: Icons.volunteer_activism,
      content: 'Ankara Yenimahalle deposunda acil gönüllü ihtiyacımız var!\n\n📦 İhtiyaç: Yardım malzemelerinin tasnifi ve paketlenmesi\n📅 Tarih: 1-2 Şubat 2026\n⏰ Saat: 09:00 - 18:00\n📍 Konum: Yenimahalle Lojistik Merkezi\n\nYapılacak işler:\n- Gıda kolilerinin hazırlanması\n- Giysi paketlerinin düzenlenmesi\n- Hijyen malzemelerinin tasnifi\n- Çocuk kıyafetlerinin ayrılması\n\n✅ Yemek ve ulaşım karşılanacaktır\n✅ Sertifika verilecektir\n\nİletişim: gonullu@ahbap.org\nTel: 0312 XXX XX XX',
      likes: 189,
      comments: 67,
      views: 543,
      tags: ['gönüllülük', 'yardım', 'ankara', 'ahbap'],
      categoryColor: const Color(0xFF4CAF50),
    ),
    ForumPost(
      id: '4',
      title: 'Hatay\'da Çadır Kent Hizmete Açıldı',
      author: 'Kızılay',
      authorAvatar: '🏥',
      timeAgo: '2 saat önce',
      category: 'Duyurular',
      city: 'Hatay',
      icon: Icons.campaign,
      content: 'Hatay Antakya\'da 5000 kişi kapasiteli çadır kent hizmete açılmıştır.\n\nÖzellikler:\n🏕️ 1000 adet aile çadırı\n🏥 Sağlık merkezi (7/24)\n🍲 Mutfak ve yemekhane\n🚿 Banyo ve WC birimleri\n👶 Çocuk oyun alanı\n📚 Eğitim çadırı\n🔌 Elektrik ve ısıtma\n💧 Temiz su\n\nBarınma ihtiyacı olan vatandaşlarımız kayıt için çadır kent girişindeki koordinasyon merkezine başvurabilir.\n\nİletişim: 0326 XXX XX XX',
      likes: 312,
      comments: 54,
      views: 987,
      tags: ['hatay', 'çadırkent', 'barınma', 'kızılay'],
      categoryColor: const Color(0xFFFF9800),
    ),
    ForumPost(
      id: '5',
      title: 'ÜCRETSİZ İlk Yardım Eğitimi - Kayıtlar Başladı',
      author: 'AKUT Arama Kurtarma',
      authorAvatar: '🚑',
      timeAgo: '3 saat önce',
      category: 'Eğitim',
      city: 'İzmir',
      icon: Icons.school,
      content: 'İzmir\'de düzenlenecek temel ilk yardım eğitimimize katılmak ister misiniz?\n\n📚 Eğitim İçeriği:\n• Temel yaşam desteği\n• Kalp masajı (CPR)\n• Suni teneffüs\n• Kanama kontrolü\n• Kırık ve çıkık müdahalesi\n• Yanık tedavisi\n• Zehirlenme durumları\n• Boğulma ve şok\n\n📅 Tarihler:\n• Grup 1: 8-9 Şubat\n• Grup 2: 15-16 Şubat\n• Grup 3: 22-23 Şubat\n\n⏰ Süre: 2 gün (09:00-17:00)\n👥 Kontenjan: Her grup 30 kişi\n💰 Ücretsiz + Sertifikalı\n\nKayıt: egitim@akut.org.tr',
      likes: 445,
      comments: 123,
      views: 1567,
      tags: ['ilkyardım', 'eğitim', 'izmir', 'akut', 'sertifika'],
      categoryColor: const Color(0xFF2196F3),
    ),
    ForumPost(
      id: '6',
      title: 'Psikolojik Destek Hattı 7/24 Hizmetinizde',
      author: 'Türk Psikologlar Derneği',
      authorAvatar: '🧠',
      timeAgo: '5 saat önce',
      category: 'Acil Yardım',
      city: 'Tümü',
      icon: Icons.sos,
      content: 'Afet sonrası psikolojik destek hattımız 7/24 hizmet vermektedir.\n\n🎯 Kimler Arayabilir?\n• Travma yaşayan bireyler\n• Kayıp yaşayan aileler\n• Kaygı ve stres yaşayanlar\n• Panik atak geçirenler\n• Uyku sorunu yaşayanlar\n\n📞 İletişim:\n• Telefon: 444 0 873\n• WhatsApp: 0850 XXX XX XX\n• Online Görüşme: www.tpd.org.tr\n\n👥 Hizmetlerimiz:\n✅ Ücretsiz\n✅ Gizli\n✅ Profesyonel\n✅ 7/24 Erişilebilir\n\nYalnız değilsiniz, biz buradayız.',
      likes: 678,
      comments: 34,
      views: 2134,
      tags: ['psikolojikdestek', 'travma', 'yardımhattı'],
      categoryColor: const Color(0xFFE91E63),
      isPinned: true,
    ),
    ForumPost(
      id: '7',
      title: 'Enkaz Altında Kalanlara Müdahale Protokolü',
      author: 'AFAD Eğitim Birimi',
      authorAvatar: '⛑️',
      timeAgo: '8 saat önce',
      category: 'Eğitim',
      city: 'Tümü',
      icon: Icons.school,
      content: 'Enkaz altında kalan birine müdahale ederken dikkat edilmesi gerekenler:\n\n⚠️ YAPILMASI GEREKENLER:\n• Hemen 112\'yi arayın\n• Kişinin konumunu not edin\n• Ses vererek kendini belli etmesini sağlayın\n• Boru veya sert bir cisimle yere vurarak işaret verin\n• Su ve yiyecek ulaştırmaya çalışın\n• Sakin kalmasını sağlayın\n• Profesyonel yardım gelene kadar bekleyin\n\n❌ YAPILMAMASI GEREKENLER:\n• Tek başınıza enkazı kaldırmaya çalışmayın\n• Elektrik tellerine dokunmayın\n• Gaz kokuyorsa kibrit/çakmak yakmayın\n• Yapıyı daha da tehlikeye sokmayın\n\nHer saniye önemli ama güvenlik önceliklidir!',
      likes: 523,
      comments: 78,
      views: 1876,
      tags: ['enkaz', 'kurtarma', 'müdahale', 'afad'],
      categoryColor: const Color(0xFF2196F3),
    ),
    ForumPost(
      id: '8',
      title: 'ACIL - Kan Bağışı Kampanyası',
      author: 'Kızılay Kan Merkezi',
      authorAvatar: '🩸',
      timeAgo: '1 gün önce',
      category: 'Acil Yardım',
      city: 'İstanbul',
      icon: Icons.sos,
      content: 'İstanbul bölgesinde acil kan ihtiyacı var!\n\n🩸 EN ÇOK İHTİYAÇ OLAN KAN GRUPLARI:\n• 0 Rh(-) - KRİTİK\n• A Rh(-) - ÇOK ACİL\n• B Rh(-) - ACİL\n• AB Rh(-) - ACİL\n\n📍 Bağış Noktaları:\n• Mecidiyeköy Kan Merkezi\n• Kadıköy Bağış Merkezi\n• Bakırköy Hastanesi\n• Kartal Kan Merkezi\n\n⏰ Saatler: 08:00 - 20:00\n\n✅ Kan bağışı şartları:\n• 18-65 yaş arası\n• En az 50 kg\n• Sağlıklı\n• Tok karnına\n\nHayat kurtarmak için bağışa geliniz!',
      likes: 891,
      comments: 156,
      views: 3456,
      tags: ['kanbağışı', 'acil', 'istanbul', 'kızılay'],
      categoryColor: const Color(0xFFE91E63),
      isUrgent: true,
    ),
    ForumPost(
      id: '9',
      title: 'Evde Afet Tatbikatı Nasıl Yapılır?',
      author: 'AFAD Eğitim',
      authorAvatar: '🏠',
      timeAgo: '1 gün önce',
      category: 'Eğitim',
      city: 'Tümü',
      icon: Icons.school,
      content: 'Ailenizle birlikte evde deprem tatbikatı yapın!\n\n📋 Hazırlık:\n1. Bir tarih belirleyin\n2. Tüm aile bireylerini bilgilendirin\n3. Güvenli noktaları belirleyin\n4. Acil çıkış yollarını planlayın\n5. Buluşma noktası seçin\n\n🏃 Tatbikat Adımları:\n1. Sarsıntı anında: ÇÖK-KAPAN-TUTUN\n2. Sarsıntı sonrası: Sakince dışarı çıkın\n3. Buluşma noktasında toplanın\n4. Sayım yapın\n5. Acil çantayı kontrol edin\n\n⏱️ Süreyi ölçün ve kaydırın\n📸 Eksikleri not edin\n🔄 Ayda bir tekrarlayın\n\nHazırlıklı olmak hayat kurtarır!',
      likes: 389,
      comments: 67,
      views: 1234,
      tags: ['tatbikat', 'hazırlık', 'aile', 'deprem'],
      categoryColor: const Color(0xFF2196F3),
    ),
    ForumPost(
      id: '10',
      title: 'Mobil Sağlık Ekipleri Sahada',
      author: 'Sağlık Bakanlığı',
      authorAvatar: '🚑',
      timeAgo: '2 gün önce',
      category: 'Duyurular',
      city: 'Adıyaman',
      icon: Icons.campaign,
      content: 'Adıyaman\'da 15 mobil sağlık ekibi 24 saat hizmet veriyor.\n\n🏥 Verilen Hizmetler:\n• Genel muayene\n• İlaç dağıtımı\n• Aşılama\n• Pansuman\n• Kronik hastalık takibi\n• Gebelik takibi\n• Çocuk sağlığı kontrolleri\n\n📍 Görev Bölgeleri:\n• Merkez: 5 ekip\n• Besni: 3 ekip\n• Gölbaşı: 2 ekip\n• Gerger: 2 ekip\n• Sincik: 2 ekip\n• Çelikhan: 1 ekip\n\nİletişim: 444 0 182',
      likes: 267,
      comments: 23,
      views: 789,
      tags: ['sağlık', 'adıyaman', 'mobilekip'],
      categoryColor: const Color(0xFFFF9800),
    ),
  ];

  final List<String> _categories = ['Tümü', 'Duyurular', 'Acil Yardım', 'Eğitim', 'Gönüllülük'];
  final List<String> _cities = ['Tümü', 'Ankara', 'İstanbul', 'İzmir', 'Hatay', 'Adıyaman', 'Elazığ'];
  final List<String> _sortOptions = ['Yeni', 'Popüler', 'Çok Yorumlanan'];

  void _navigateToDetail(ForumPost post) {
    setState(() {
      _readPostIds.add(post.id);
    });
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ForumDetailScreen(
          post: post,
          participationStatus: _participationStatus[post.id] ?? ParticipationStatus.none,
          onParticipate: () {
            setState(() => _participationStatus[post.id] = ParticipationStatus.attending);
            Navigator.pop(context);
            _showSnackBar('Katılımınız kaydedildi! 🎉', Colors.green);
          },
          onNotParticipate: () {
            setState(() => _participationStatus[post.id] = ParticipationStatus.notAttending);
            Navigator.pop(context);
            _showSnackBar('Bilginiz alındı.', Colors.orange);
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String selectedCategory = _categories[_tabController.index];
    final List<ForumPost> filteredPosts = _forumPosts.where((post) {
      final matchesCategory = selectedCategory == 'Tümü' || post.category == selectedCategory;
      final matchesCity = _selectedCity == 'Tümü' || post.city == _selectedCity || post.city == 'Tümü';
      return matchesCategory && matchesCity;
    }).toList();

    // Sort posts
    if (_sortBy == 'Popüler') {
      filteredPosts.sort((a, b) => b.likes.compareTo(a.likes));
    } else if (_sortBy == 'Çok Yorumlanan') {
      filteredPosts.sort((a, b) => b.comments.compareTo(a.comments));
    }

    // Pinned posts first
    filteredPosts.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      body: CustomScrollView(
        slivers: [
          _buildAnimatedAppBar(),
          SliverToBoxAdapter(child: _buildStatsBar()),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final post = filteredPosts[index];
                  final isRead = _readPostIds.contains(post.id);
                  return _buildAnimatedPostCard(post, isRead, index);
                },
                childCount: filteredPosts.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () {
            _showSnackBar('Yeni gönderi özelliği yakında...', Colors.blue);
          },
          backgroundColor: const Color(0xFF135BEC),
          icon: const Icon(Icons.add),
          label: const Text('Yeni Gönderi'),
        ),
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0A0F1D),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16.0, top: 16.0),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Forum',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF135BEC),
                Color(0xFF0A0F1D),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Transform.rotate(
                  angle: math.pi / 6,
                  child: Icon(
                    Icons.forum,
                    size: 200,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        _buildSortMenu(),
        _buildCityFilter(),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF135BEC),
        indicatorWeight: 3,
        tabs: _categories.map((category) {
          final count = _forumPosts.where((post) =>
          category == 'Tümü' || post.category == category
          ).length;
          return Tab(
            child: Row(
              children: [
                Text(category),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF135BEC).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort),
      color: const Color(0xFF192233),
      onSelected: (value) => setState(() => _sortBy = value),
      itemBuilder: (context) => _sortOptions.map((option) {
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              if (_sortBy == option)
                const Icon(Icons.check, color: Color(0xFF135BEC), size: 20),
              if (_sortBy == option) const SizedBox(width: 8),
              Text(
                option,
                style: TextStyle(
                  color: _sortBy == option ? const Color(0xFF135BEC) : Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCityFilter() {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: const Color(0xFF192233),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButton<String>(
        value: _selectedCity,
        dropdownColor: const Color(0xFF192233),
        style: const TextStyle(color: Colors.white),
        underline: Container(),
        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() => _selectedCity = newValue);
          }
        },
        items: _cities.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFF135BEC)),
                const SizedBox(width: 6),
                Text(value),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF192233), Color(0xFF0F1825)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.article, '${_forumPosts.length}', 'Gönderi'),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          _buildStatItem(Icons.people, '1.2K', 'Aktif Kullanıcı'),
          Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
          _buildStatItem(Icons.trending_up, '3.4K', 'Bugünkü Görüntülenme'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF135BEC), size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAnimatedPostCard(ForumPost post, bool isRead, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _navigateToDetail(post),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: post.isUrgent
                ? [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ]
                : null,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            color: const Color(0xFF192233).withOpacity(isRead ? 0.5 : 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: post.isUrgent
                    ? Colors.red.withOpacity(0.5)
                    : Colors.white.withOpacity(isRead ? 0.05 : 0.2),
                width: post.isUrgent ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Gradient overlay for category
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          post.categoryColor,
                          post.categoryColor.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: post.categoryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(post.icon, color: post.categoryColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.category.toUpperCase(),
                                  style: TextStyle(
                                    color: post.categoryColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 12, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.city,
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (post.isUrgent)
                            _buildUrgentBadge()
                          else if (post.isPinned)
                            _buildPinnedBadge()
                          else if (!isRead)
                              _buildNewBadge(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      // Title
                      Text(
                        post.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      // Author and time
                      Row(
                        children: [
                          Text(post.authorAvatar, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.author,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  post.timeAgo,
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Stats
                      Row(
                        children: [
                          _buildPostStat(Icons.favorite_border, post.likes.toString()),
                          const SizedBox(width: 16),
                          _buildPostStat(Icons.comment_outlined, post.comments.toString()),
                          const SizedBox(width: 16),
                          _buildPostStat(Icons.visibility_outlined, post.views.toString()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentBadge() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * math.sin(value * math.pi * 4)),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.error_outline, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text(
              'ACİL',
              style: TextStyle(
                color: Colors.red,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.push_pin, color: Colors.amber, size: 14),
          SizedBox(width: 4),
          Text(
            'SABİT',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: const Text(
        'YENİ',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPostStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
