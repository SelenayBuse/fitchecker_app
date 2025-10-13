import 'package:flutter/material.dart';
import 'package:flutter95/flutter95.dart';
import 'dart:math' as math; 
import 'package:image_picker/image_picker.dart'; 
import 'dart:io'; 
import 'package:path_provider/path_provider.dart'; // Yerel yol bulma
import 'package:shared_preferences/shared_preferences.dart'; // Kalıcı veri saklama

void main() {
  runApp(const FitCheckerApp());
}

class FitCheckerApp extends StatelessWidget {
  const FitCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Flutter95.background,
      home: const FitCheckerHome(),
    );
  }
}

final ImagePicker _picker = ImagePicker();

class FitCheckerHome extends StatefulWidget {
  const FitCheckerHome({super.key});

  @override
  State<FitCheckerHome> createState() => _FitCheckerHomeState();
}

class _FitCheckerHomeState extends State<FitCheckerHome> {
  // --- STATE (DURUM) DEĞİŞKENLERİ ---
  final List<Color> _tops = [
    const Color(0xFFEECFEF),
    const Color(0xFFD6A6C7),
    const Color(0xFFF6D7E8),
  ];
  final List<Color> _bottoms = [
    const Color(0xFFD8E8E8),
    const Color(0xFFBDB3E0),
    const Color(0xFFCFD8B6),
  ];
  final List<Color> _coats = [
    const Color.fromARGB(255, 209, 245, 211),
    const Color.fromARGB(255, 224, 179, 192),
    const Color.fromARGB(255, 216, 208, 182),
  ];

  int _topIndex = 0;
  int _bottomIndex = 0;
  int _coatIndex = 0;
  final Color _userPhotoColor = const Color(0xFFF1E2E2);

  // --- METOTLAR ---

  void _cycleTop(int direction) {
    setState(() {
      _topIndex = (_topIndex + direction + _tops.length) % _tops.length;
    });
  }

  void _cycleBottom(int direction) {
    setState(() {
      _bottomIndex =
          (_bottomIndex + direction + _bottoms.length) % _bottoms.length;
    });
  }

  void _cycleCoat(int direction) {
    setState(() {
      _coatIndex =
          (_coatIndex + direction + _coats.length) % _coats.length;
    });
  }

  void _createOutfit() {
    showDialog95(
      context: context,
      title: 'Create outfit',
      message: 'This will call Nano Banana (not implemented).',
    );
  }

  // --- ANA BUILD METODU ---
  @override
  Widget build(BuildContext context) {
    return Scaffold95(
      title: 'Slay Diva 💅',
      toolbar: Toolbar95(
        actions: [
          Item95(label: 'Add Clothes', menu: _buildMenu()),
          Item95(label: 'Edit', onTap: (context) {}),
          Item95(label: 'Help', onTap: (context) {}),
        ],
      ),
      // CRITICAL FIX: body'nin tamamını Expanded ile sararak 
      // LayoutBuilder'a sınırlı dikey kısıtlama gönderilmesini sağlıyoruz (RenderFlex hatası çözümü).
      body: Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double kDesktopBreakpoint = 700.0;
            
            if (constraints.maxWidth < kDesktopBreakpoint) {
              return _buildNarrowLayout(constraints);
            } else {
              return _buildWideLayout(constraints);
            }
          },
        ),
      ),
    );
  }

  // --- LAYOUT BUILDER'LARI ---

  /// Geniş ekranlar (desktop/tablet) için layout.
  Widget _buildWideLayout(BoxConstraints constraints) {
    debugPrint('*** Wide Layout aktif. Genişlik: ${constraints.maxWidth}');

    final double leftColumnRatio = 0.35; 
    const double maxPhotoAreaWidth = 650.0;
    const double maxPhotoAreaHeight = 650.0; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol Sütun: Karuseller (Kaydırmayı korumak için SingleChildScrollView)
          Flexible(
            flex: 40, 
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (constraints.maxWidth * leftColumnRatio).clamp(320.0, 450.0),
              ),
              child: SingleChildScrollView( 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Karusel aralıkları sabit hale getirildi.
                    _buildCarousel(
                      title: 'TOPS',
                      items: _tops,
                      currentIndex: _topIndex,
                      onPrev: () => _cycleTop(-1),
                      onNext: () => _cycleTop(1),
                      constraints: constraints,
                      isNarrow: false,
                    ),
                    const SizedBox(height: 16), 
                    
                    _buildCarousel(
                      title: 'BOTTOMS',
                      items: _bottoms,
                      currentIndex: _bottomIndex,
                      onPrev: () => _cycleBottom(-1),
                      onNext: () => _cycleBottom(1),
                      constraints: constraints,
                      isNarrow: false,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildCarousel(
                      title: 'COATS',
                      items: _coats,
                      currentIndex: _coatIndex,
                      onPrev: () => _cycleCoat(-1),
                      onNext: () => _cycleCoat(1),
                      constraints: constraints,
                      isNarrow: false,
                    ),
                    const SizedBox(height: 20), 
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          
          // Sağ Sütun: Max Boyut Kısıtlaması ve Ortalama
          Expanded(
            flex: 60, 
            child: Center( // Yatayda ve dikeyde ortalar
              child: ConstrainedBox( 
                constraints: const BoxConstraints(
                  maxWidth: maxPhotoAreaWidth,
                  maxHeight: maxPhotoAreaHeight,
                ),
                child: _buildPhotoArea(constraints, isNarrow: false), 
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dar ekranlar (telefon) için layout.
  Widget _buildNarrowLayout(BoxConstraints constraints) {
    debugPrint('*** Narrow Layout aktif. Genişlik: ${constraints.maxWidth}');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPhotoArea(constraints, isNarrow: true),
          const SizedBox(height: 16),
          _buildCarousel(
            title: 'TOPS',
            items: _tops,
            currentIndex: _topIndex,
            onPrev: () => _cycleTop(-1),
            onNext: () => _cycleTop(1),
            constraints: constraints,
            isNarrow: true,
          ),
          const SizedBox(height: 16),
          _buildCarousel(
            title: 'BOTTOMS',
            items: _bottoms,
            currentIndex: _bottomIndex,
            onPrev: () => _cycleBottom(-1),
            onNext: () => _cycleBottom(1),
            constraints: constraints,
            isNarrow: true,
          ),
          const SizedBox(height: 16),
          _buildCarousel(
            title: 'COATS',
            items: _coats,
            currentIndex: _coatIndex,
            onPrev: () => _cycleCoat(-1),
            onNext: () => _cycleCoat(1),
            constraints: constraints,
            isNarrow: true,
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  // --- UI PARÇALARI (REUSABLE WIDGETS) ---

  /// "Tops", "Bottoms" ve "Coats" için ortak carousel widget'ı.
  Widget _buildCarousel({
    required String title,
    required List<Color> items,
    required int currentIndex,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required BoxConstraints constraints,
    required bool isNarrow,
  }) {
    final double innerWidth = isNarrow
        ? (constraints.maxWidth * 0.5).clamp(180.0, 250.0)
        : 220.0;
    final double innerHeight = (innerWidth * 0.7).clamp(90.0, 150.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8),
          child: Text(title, style: Flutter95.textStyle),
        ),
        Elevation95(
          type: Elevation95Type.down,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: const Color(0xFF947B7B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _triangleButton(onTap: onPrev),
                Container(
                  width: innerWidth,
                  height: innerHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Flutter95.white,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      color: items[currentIndex],
                    ),
                  ),
                ),
                _triangleButton(onTap: onNext, rotate: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Kullanıcı fotoğrafı ve "Create Outfit" butonunu içeren alan.
  Widget _buildPhotoArea(BoxConstraints constraints, {required bool isNarrow}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        // Fotoğraf alanı (AspectRatio'yu sadece dar ekranda kullanıyoruz)
        Expanded( // Expanded, ConstrainedBox'tan gelen alanda esner.
          child: Elevation95(
            type: Elevation95Type.down,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFB38C8C),
              padding: const EdgeInsets.all(12),
              child: isNarrow ? AspectRatio(
                aspectRatio: 1.0, // Dar ekranda kare
                child: Container(
                  color: _userPhotoColor,
                  child: const Center(
                    child: Text('Your Photo', style: Flutter95.textStyle),
                  ),
                ),
              ) : 
              // Geniş ekranda AspectRatio'yu kaldırıp, Expanded'ın alanını dolduruyoruz.
              Container( 
                color: _userPhotoColor,
                child: const Center(
                  child: Text('Your Photo', style: Flutter95.textStyle),
                ),
              ),
            ),
          ),
        ),
        
        // Dikey taşmayı engellemek için Spacer yerine sabit boşluk kullanıyoruz
        const SizedBox(height: 12), 

        // Buton
        Align(
          alignment: Alignment.centerRight,
          child: Button95(
            onTap: _createOutfit,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Create outfit diva!', style: Flutter95.textStyle),
            ),
          ),
        ),
      ],
    );
  }

  Widget _triangleButton({required VoidCallback onTap, bool rotate = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(4.0),
        child: Elevation95(
          child: Container(
            width: 36,
            height: 36,
            color: const Color(0xFFD9C8C8),
            child: Transform.rotate(
              angle: rotate ? math.pi : 0,
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 18,
                  color: Color(0xFF8B5A5A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Menu95 _buildMenu() {
    return Menu95(
      items: [
        MenuItem95(value: 1, label: 'Add Tops'),
        
        MenuItem95(value: 2, label: 'Add Bottoms'),
        MenuItem95(value: 2, label: 'Add Coat'),
      ],
      onItemSelected: (item) {},
    );
  }
}