import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image_cropper/image_cropper.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const FitCheckerApp());
}

// =================================================================
// VERİ MODELLERİ
// =================================================================
class ImageItem {
  final String path;
  ImageItem(this.path);
}

enum ClothingCategory { top, bottom, coat }

// =================================================================
// TEMA SABİTLERİ
// =================================================================
class AppTheme {
  static const Color primary = Color(0xFF7C5CBF);
  static const Color primaryLight = Color(0xFFEDE7F6);
  static const Color background = Color(0xFFF8F7FC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  static const TextStyle heading1 = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border, width: 1),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
    ],
  );
}

// =================================================================

class FitCheckerApp extends StatelessWidget {
  const FitCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Virtual Wardrobe',
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary),
        useMaterial3: true,
      ),
      home: const FitCheckerHome(),
    );
  }
}

class FitCheckerHome extends StatefulWidget {
  const FitCheckerHome({super.key});

  @override
  State<FitCheckerHome> createState() => _FitCheckerHomeState();
}

class _FitCheckerHomeState extends State<FitCheckerHome> {
  final ImagePicker _picker = ImagePicker();
  int _currentNavIndex = 0;

  List<ImageItem> _tops = [];
  List<ImageItem> _bottoms = [];
  List<ImageItem> _coats = [];
  
  // Kombinleri tutmak için yeni liste
  List<ImageItem> _savedOutfits = [];

  File? _userImage;
  File? _generatedOutfitImage;

  bool _isLoading = false;
  int _topIndex = 0;
  int _bottomIndex = 0;
  int _coatIndex = 0;

  int? _selectedOutfitTopIndex;
  int? _selectedOutfitBottomIndex;

  @override
  void initState() {
    super.initState();
    _loadAllSavedData();
  }

  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'FitChecker'));
    return imagesDir;
  }

  Future<void> _initAppDirectories() async {
    try {
      final imagesDir = await _getImagesDirectory();
      // Outfits klasörü eklendi
      final dirs = ['Tops', 'Bottoms', 'Coats', 'UserPhoto', 'Outfits']
          .map((d) => Directory(p.join(imagesDir.path, d)));
      for (var dir in dirs) {
        if (!await dir.exists()) await dir.create(recursive: true);
      }
      print('[Storage] App directories initialized successfully.');
    } catch (e) {
      debugPrint("[Storage] Directory initialization error: $e");
    }
  }

  Future<void> _loadAllSavedData() async {
    await _initAppDirectories();
    await _loadClothes();
    await _loadUserPhoto();
    await _loadSavedOutfits(); // Kayıtlı kombinleri de yükle
    setState(() {});
  }

  Future<void> _loadClothes() async {
    final imagesDir = await _getImagesDirectory();
    for (var category in ClothingCategory.values) {
      List<ImageItem> targetList;
      String subDir;
      switch (category) {
        case ClothingCategory.top: targetList = _tops; subDir = 'Tops'; break;
        case ClothingCategory.bottom: targetList = _bottoms; subDir = 'Bottoms'; break;
        case ClothingCategory.coat: targetList = _coats; subDir = 'Coats'; break;
      }
      final categoryDir = Directory(p.join(imagesDir.path, subDir));
      final existingPaths = targetList.map((e) => e.path).toSet();
      if (await categoryDir.exists()) {
        try {
          final files = categoryDir.listSync().whereType<File>().toList();
          for (var file in files) {
            if (!existingPaths.contains(file.path)) targetList.add(ImageItem(file.path));
          }
          print('[Storage] Loaded ${files.length} items for $subDir');
        } catch (e) { debugPrint("[Storage] Read error for $subDir: $e"); }
      }
    }
  }

  Future<void> _loadUserPhoto() async {
    final imagesDir = await _getImagesDirectory();
    final userPhotoDir = Directory(p.join(imagesDir.path, 'UserPhoto'));
    if (await userPhotoDir.exists()) {
      try {
        final files = userPhotoDir.listSync().whereType<File>().toList();
        if (files.isNotEmpty) {
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          setState(() { _userImage = files.first; });
          print('[Storage] User photo loaded successfully.');
        }
      } catch (e) { debugPrint("[Storage] User photo read error: $e"); }
    }
  }

  // Yeni Fonksiyon: Kaydedilmiş Kombinleri Yükle
  Future<void> _loadSavedOutfits() async {
    final imagesDir = await _getImagesDirectory();
    final outfitsDir = Directory(p.join(imagesDir.path, 'Outfits'));
    if (await outfitsDir.exists()) {
      try {
        final files = outfitsDir.listSync().whereType<File>().toList();
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        setState(() {
          _savedOutfits = files.map((f) => ImageItem(f.path)).toList();
        });
        print('[Storage] Loaded ${_savedOutfits.length} saved outfits.');
      } catch (e) { 
        debugPrint("[Storage] Saved outfits read error: $e"); 
      }
    }
  }

  Future<String?> _cropImage(String imagePath) async {
    print('[ImageCropper] Starting crop process for: $imagePath');
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Düzenle',
          toolbarColor: AppTheme.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Fotoğrafı Düzenle',
        ),
      ],
    );

    if (croppedFile != null) {
      print('[ImageCropper] Crop successful. Result path: ${croppedFile.path}');
    } else {
      print('[ImageCropper] Crop cancelled by user.');
    }
    return croppedFile?.path;
  }

  Future<Uint8List?> _removeBackground(String imagePath) async {
    final String? apiKey = dotenv.env['REMOVE_BG_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      print('[RemoveBG API] ERROR: API Key is missing.');
      return null;
    }
    print('[RemoveBG API] Sending request to remove background...');
    final uri = Uri.parse('https://api.remove.bg/v1.0/removebg');
    final request = http.MultipartRequest('POST', uri)
      ..headers['X-Api-Key'] = apiKey
      ..fields['size'] = 'auto'
      ..files.add(await http.MultipartFile.fromPath('image_file', imagePath));
    try {
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        print('[RemoveBG API] Background removed successfully.');
        return await streamedResponse.stream.toBytes();
      }
      print('[RemoveBG API] FAILED with status code: ${streamedResponse.statusCode}');
      return null;
    } catch (e) { 
      print('[RemoveBG API] Exception occurred: $e');
      return null; 
    }
  }

  Future<Uint8List?> _callGeminiImageApi({
    required File userImageFile,
    required ImageItem topItem,
    required ImageItem bottomItem,
    ImageItem? coatItem,
  }) async {
    print('--- [Gemini API] Generation Process Started ---');
    
    final String? apiKey = dotenv.env['GOOGLE_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      print('[Gemini API] ERROR: Google API Key not found.');
      return null;
    }

    bool includeCoat = coatItem != null;
    const String modelName = 'gemini-2.5-flash-image';
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');
    
    List<Map<String, dynamic>> parts = [];
    
    String textPrompt = """
    Dress this person using the provided items. 
    CRITICAL INSTRUCTIONS: 
    1. STRICTLY REPLACE the person's existing clothing. DO NOT layer new clothes over the old ones. The original clothes MUST BE COMPLETELY REMOVED.
    2. KEEP THE ORIGINAL BACKGROUND AND POSITION: Do not change the environment, lighting, or the person's exact placement in the frame.
    3. EXACTLY ONE PERSON: There must be ONLY ONE person in the final image. Completely remove any duplicate faces, clones, twins, or background figures of the person.
    4. Dress her realistically. Do NOT change the person's body shape, identity, or face gestures.
    """;
    
    try {
      parts.add({"text": textPrompt});
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await userImageFile.readAsBytes())}});
      
      parts.add({"text": "Use this image as the top:"});
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(topItem.path).readAsBytes())}});
      
      parts.add({"text": "Use this image as the bottom:"});
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(bottomItem.path).readAsBytes())}});
      
      if (includeCoat) {
        parts.add({"text": "Use this image as the coat:"});
        parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(coatItem!.path).readAsBytes())}});
      }

      print('[Gemini API] Sending POST request to Gemini API...');
      final requestBody = jsonEncode({"contents": [{"parts": parts}]});
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: requestBody);
      
      if (response.statusCode == 200) {
        print('[Gemini API] SUCCESS: Image generated successfully.');
        final responseData = jsonDecode(response.body);
        final List<dynamic> responseParts = responseData['candidates'][0]['content']['parts'];
        
        for (var part in responseParts) {
          if (part.containsKey('inlineData')) {
            return base64Decode(part['inlineData']['data']);
          }
        }
      } else {
        print('[Gemini API] ERROR Detail: ${response.body}');
      }
      return null;
    } catch (e) {
      print('[Gemini API] Exception: $e');
      return null;
    }
  }

  Future<Uint8List?> _callGeminiImageApiWithPrompt({
    required File userImageFile,
    required String prompt,
    required List<ImageItem> allTops,
    required List<ImageItem> allBottoms,
    required List<ImageItem> allCoats,
  }) async {
    print('--- [Gemini API] Custom Prompt Generation Started ---');
    final String? apiKey = dotenv.env['GOOGLE_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) return null;
    
    const String modelName = 'gemini-2.5-flash-image';
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');
    List<Map<String, dynamic>> parts = [];
    String textPrompt = """You are an expert fashion stylist. Dress the person based on: '$prompt'. Select ONE top, ONE bottom, and optionally ONE coat from the lists below. Dress realistically. STRICTLY REPLACE existing clothes without layering. KEEP the original background. GENERATE EXACTLY ONE PERSON in the image, absolutely NO clones or duplicate faces in the background. Do NOT change the person's face, body, or pose. Here is the user:""";
    
    parts.add({"text": textPrompt});
    parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await userImageFile.readAsBytes())}});
    
    parts.add({"text": "--- AVAILABLE TOPS ---"});
    for (int i = 0; i < allTops.length; i++) {
      parts.add({"text": "Top ${i+1}:"}); 
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(allTops[i].path).readAsBytes())}});
    }
    
    parts.add({"text": "--- AVAILABLE BOTTOMS ---"});
    for (int i = 0; i < allBottoms.length; i++) {
      parts.add({"text": "Bottom ${i+1}:"}); 
      parts.add({"inlineData": {"mimeType": "image/png", "data": base64Encode(await File(allBottoms[i].path).readAsBytes())}});
    }
    
    parts.add({"text": "Now generate the final image based on: '$prompt'."});
    final requestBody = jsonEncode({"contents": [{"parts": parts}]});
    
    try {
      print('[Gemini API] Sending POST request for custom prompt...');
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: requestBody);
      if (response.statusCode == 200) {
        print('[Gemini API] SUCCESS: Custom prompt image generated.');
        final responseData = jsonDecode(response.body);
        final List<dynamic> responseParts = responseData['candidates'][0]['content']['parts'];
        for (var part in responseParts) {
          if (part.containsKey('inlineData')) return base64Decode(part['inlineData']['data']);
        }
      } else {
        print('[Gemini API] ERROR Detail: ${response.body}');
      }
      return null;
    } catch (e) { 
      print('[Gemini API] Exception: $e');
      return null; 
    }
  }

  Future<void> _pickUserPhoto() async {
    print('[ImagePicker] Opening picker for user photo...');
    String? pickedFilePath;
    if (Platform.isAndroid || Platform.isIOS) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) pickedFilePath = pickedFile.path;
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) pickedFilePath = result.files.single.path;
    }
    
    if (pickedFilePath != null) {
      print('[ImagePicker] Selected file: $pickedFilePath');
      final croppedPath = await _cropImage(pickedFilePath);
      if (croppedPath == null) {
        print('[ImagePicker] Operation cancelled during crop.');
        return; 
      }
      
      setState(() { _isLoading = true; });
      try {
        final imagesDir = await _getImagesDirectory();
        final targetDir = Directory(p.join(imagesDir.path, 'UserPhoto'));
        if (!await targetDir.exists()) await targetDir.create(recursive: true);
        
        final fileName = 'user_photo_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedImageFile = await File(croppedPath).copy(p.join(targetDir.path, fileName));
        
        print('[Storage] User photo saved to: ${savedImageFile.path}');
        setState(() { _userImage = savedImageFile; _generatedOutfitImage = null; });
      } catch (e) {
        print('[Storage] ERROR saving user photo: $e');
        if (mounted) _showSnack('Fotoğraf yüklenirken hata oluştu: $e', isError: true);
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _pickAndAddImage(ClothingCategory category) async {
    print('[ImagePicker] Opening picker for category: ${category.name}...');
    String? pickedFilePath;
    if (Platform.isAndroid || Platform.isIOS) {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) pickedFilePath = pickedFile.path;
    } else {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) pickedFilePath = result.files.single.path;
    }
    
    if (pickedFilePath != null) {
      print('[ImagePicker] Selected file: $pickedFilePath');
      final croppedPath = await _cropImage(pickedFilePath);
      if (croppedPath == null) return; 
      
      setState(() { _isLoading = true; });
      try {
        final imageBytesWithoutBg = await _removeBackground(croppedPath); 
        if (imageBytesWithoutBg != null) {
          final imagesDir = await _getImagesDirectory();
          String subDir;
          switch (category) {
            case ClothingCategory.top: subDir = 'Tops'; break;
            case ClothingCategory.bottom: subDir = 'Bottoms'; break;
            case ClothingCategory.coat: subDir = 'Coats'; break;
          }
          final targetDir = Directory(p.join(imagesDir.path, subDir));
          if (!await targetDir.exists()) await targetDir.create(recursive: true);
          
          final fileName = 'clothing_${category.name}_${DateTime.now().millisecondsSinceEpoch}.png';
          final savedImageFile = await File(p.join(targetDir.path, fileName)).writeAsBytes(imageBytesWithoutBg);
          final newItem = ImageItem(savedImageFile.path);
          
          print('[Storage] Clothing item saved to: ${savedImageFile.path}');
          
          setState(() {
            switch (category) {
              case ClothingCategory.top: _tops.add(newItem); _topIndex = _tops.length - 1; _selectedOutfitTopIndex = _topIndex; break;
              case ClothingCategory.bottom: _bottoms.add(newItem); _bottomIndex = _bottoms.length - 1; _selectedOutfitBottomIndex = _bottomIndex; break;
              case ClothingCategory.coat: _coats.add(newItem); _coatIndex = _coats.length - 1; break;
            }
            _generatedOutfitImage = null;
          });
          if (mounted) _showSnack('Kıyafet başarıyla eklendi!');
        } else {
          if (mounted) _showSnack('Arka plan temizlenemedi.', isError: true);
        }
      } catch (e) {
        print('[Storage/Network] ERROR adding clothing: $e');
        if (mounted) _showSnack('Bir hata oluştu: $e', isError: true);
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _removeClothingItem(ClothingCategory category, int index) {
    print('[Storage] Removing clothing item from ${category.name} at index $index');
    setState(() {
      switch (category) {
        case ClothingCategory.top:
          if (_tops.isNotEmpty) {
            final file = File(_tops[index].path);
            _tops.removeAt(index);
            _topIndex = _tops.isEmpty ? 0 : _topIndex.clamp(0, _tops.length - 1);
            _selectedOutfitTopIndex = null;
            file.delete().catchError((e) => print('[Storage] ERROR deleting file: $e'));
          }
          break;
        case ClothingCategory.bottom:
          if (_bottoms.isNotEmpty) {
            final file = File(_bottoms[index].path);
            _bottoms.removeAt(index);
            _bottomIndex = _bottoms.isEmpty ? 0 : _bottomIndex.clamp(0, _bottoms.length - 1);
            _selectedOutfitBottomIndex = null;
            file.delete().catchError((e) => print('[Storage] ERROR deleting file: $e'));
          }
          break;
        case ClothingCategory.coat:
          if (_coats.isNotEmpty) {
            final file = File(_coats[index].path);
            _coats.removeAt(index);
            _coatIndex = _coats.isEmpty ? 0 : _coatIndex.clamp(0, _coats.length - 1);
            file.delete().catchError((e) => print('[Storage] ERROR deleting file: $e'));
          }
          break;
      }
    });
  }

  Future<void> _createOutfit() async {
    if (_userImage == null) {
      _showSnack('Lütfen önce fotoğrafınızı ekleyin.', isError: true);
      return;
    }
    if (_tops.isEmpty || _bottoms.isEmpty) {
      _showSnack('Lütfen en az bir üst ve bir alt giyim ekleyin/seçin.', isError: true);
      return;
    }
    
    int tIndex = _selectedOutfitTopIndex ?? _topIndex;
    int bIndex = _selectedOutfitBottomIndex ?? _bottomIndex;
    
    if (tIndex >= _tops.length) tIndex = 0;
    if (bIndex >= _bottoms.length) bIndex = 0;
    int cIndex = _coatIndex >= _coats.length ? 0 : _coatIndex;

    setState(() { _isLoading = true; });
    try {
      final ImageItem currentTop = _tops[tIndex];
      final ImageItem currentBottom = _bottoms[bIndex];
      final ImageItem? currentCoat = _coats.isNotEmpty ? _coats[cIndex] : null;
      
      final Uint8List? generatedImageBytes = await _callGeminiImageApi(
        userImageFile: _userImage!, topItem: currentTop, bottomItem: currentBottom, coatItem: currentCoat,
      );
      
      if (generatedImageBytes != null && mounted) {
        final imagesDir = await _getImagesDirectory();
        final fileName = 'generated_outfit_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedImageFile = await File(p.join(imagesDir.path, fileName)).writeAsBytes(generatedImageBytes);
        print('[Storage] Generated outfit temporary saved to: ${savedImageFile.path}');
        setState(() { _generatedOutfitImage = savedImageFile; });
        if (mounted) _showSnack('Kombininiz hazır! ✨');
      } else if (mounted) {
        _showSnack('Kombin oluşturulamadı. Tekrar deneyin.', isError: true);
      }
    } catch (e) {
      print('[Generation] ERROR creating outfit: $e');
      if (mounted) _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _createOutfitFromCustomPrompt() async {
    final String? customPrompt = await _showPromptDialog();
    if (customPrompt == null || customPrompt.trim().isEmpty) return;
    if (_userImage == null) {
      _showSnack('Lütfen önce fotoğrafınızı ekleyin.', isError: true);
      return;
    }
    if (_tops.isEmpty || _bottoms.isEmpty) {
      _showSnack('Gardırobunuzda en az bir alt ve bir üst giyim olmalı.', isError: true);
      return;
    }
    
    setState(() { _isLoading = true; });
    try {
      final Uint8List? generatedImageBytes = await _callGeminiImageApiWithPrompt(
        userImageFile: _userImage!, prompt: customPrompt, allTops: _tops, allBottoms: _bottoms, allCoats: _coats,
      );
      if (generatedImageBytes != null && mounted) {
        final imagesDir = await _getImagesDirectory();
        final fileName = 'generated_outfit_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedImageFile = await File(p.join(imagesDir.path, fileName)).writeAsBytes(generatedImageBytes);
        print('[Storage] Custom generated outfit temporary saved to: ${savedImageFile.path}');
        setState(() { _generatedOutfitImage = savedImageFile; });
        if (mounted) _showSnack('Kombininiz hazır! ✨');
      } else if (mounted) {
        _showSnack('Kombin oluşturulamadı. Tekrar deneyin.', isError: true);
      }
    } catch (e) {
      print('[Generation] ERROR creating custom outfit: $e');
      if (mounted) _showSnack('Hata: $e', isError: true);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // YENİ EKLENEN: Oluşturulan kombini kalıcı olarak kaydetme fonksiyonu
  Future<void> _saveOutfitToWardrobe() async {
    if (_generatedOutfitImage == null) return;
    
    print('[Storage] Attempting to save generated outfit to collection...');
    try {
      final imagesDir = await _getImagesDirectory();
      final targetDir = Directory(p.join(imagesDir.path, 'Outfits'));
      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final fileName = 'saved_outfit_${DateTime.now().millisecondsSinceEpoch}.png';
      final finalPath = p.join(targetDir.path, fileName);
      
      // Geçici dosyayı kopyala
      final savedFile = await _generatedOutfitImage!.copy(finalPath);
      
      setState(() {
        _savedOutfits.insert(0, ImageItem(savedFile.path)); // En başa ekle
      });
      
      print('[Storage] SUCCESS: Outfit saved to $finalPath');
      _showSnack('Kombin başarıyla kaydedildi! 🌟');
    } catch (e) {
      print('[Storage] ERROR saving outfit to collection: $e');
      _showSnack('Kombin kaydedilirken bir hata oluştu.', isError: true);
    }
  }


  Future<String?> _showPromptDialog() async {
    final TextEditingController promptController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kombin İsteği', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              const Text('Ne tür bir kombin istiyorsunuz?', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Örn: 'Ofis için formal bir kombin'",
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(promptController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Oluştur', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildBody(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.45),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
              SizedBox(height: 16),
              Text('Kombin oluşturuluyor...', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              SizedBox(height: 4),
              Text('Bu birkaç saniye sürebilir', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentNavIndex) {
      case 0: return _buildHomeTab();
      case 1: return _buildWardrobeTab();
      case 2: return _buildOutfitsTab(); // Güncellendi
      case 3: return _buildProfileTab();
      default: return _buildHomeTab();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, 'Ana Sayfa'),
              _navItem(1, Icons.checkroom_rounded, 'Gardırop'),
              _navItem(2, Icons.star_rounded, 'Kombinlerim'),
              _navItem(3, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textSecondary, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppTheme.primary : AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // =================================================================
  // HOME TAB
  // =================================================================
  Widget _buildHomeTab() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildSection1_Photo(),
                const SizedBox(height: 24),
                _buildSection2_Wardrobe(),
                const SizedBox(height: 24),
                _buildSection3_OutfitBuilder(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.background,
      floating: true,
      snap: true,
      elevation: 0,
      expandedHeight: 70,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.checkroom_rounded, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Virtual Wardrobe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text('Kendine en yakışanı keşfet ✨', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
              child: const Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection1_Photo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('1. Fotoğrafını Yükle', style: AppTheme.heading2),
        const SizedBox(height: 4),
        const Text('Kendini net bir şekilde gösteren bir fotoğraf seç.', style: AppTheme.body),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickUserPhoto,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
                        child: const Icon(Icons.person_outline_rounded, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(height: 8),
                      const Text('Fotoğraf Yükle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      const Text('veya sürükle-bırak', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            if (_userImage != null || _generatedOutfitImage != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey[100]),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _generatedOutfitImage ?? _userImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() { _generatedOutfitImage = null; _userImage = null; }),
                          child: Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSection2_Wardrobe() {
    final allClothes = [
      ..._tops.asMap().entries.map((e) => _ClothingEntry(e.value, ClothingCategory.top, e.key)),
      ..._bottoms.asMap().entries.map((e) => _ClothingEntry(e.value, ClothingCategory.bottom, e.key)),
      ..._coats.asMap().entries.map((e) => _ClothingEntry(e.value, ClothingCategory.coat, e.key)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('2. Kıyafetlerini Yükle', style: AppTheme.heading2),
                Text('Gardırobundaki kıyafetleri ekle.', style: AppTheme.body),
              ],
            ),
            _AddButton(onTap: () => _showAddClothingSheet()),
          ],
        ),
        const SizedBox(height: 12),
        if (allClothes.isEmpty)
          Container(
            height: 120,
            decoration: AppTheme.cardDecoration,
            child: const Center(child: Text('Henüz kıyafet eklenmedi.', style: AppTheme.body)),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allClothes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final entry = allClothes[i];
                return _ClothingGridItem(
                  item: entry.item,
                  onDelete: () => _removeClothingItem(entry.category, entry.index),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAddClothingSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kıyafet Ekle', style: AppTheme.heading2),
            const SizedBox(height: 16),
            _sheetOption(Icons.arrow_upward_rounded, 'Üst Giyim Ekle', () { Navigator.pop(context); _pickAndAddImage(ClothingCategory.top); }),
            _sheetOption(Icons.arrow_downward_rounded, 'Alt Giyim Ekle', () { Navigator.pop(context); _pickAndAddImage(ClothingCategory.bottom); }),
            _sheetOption(Icons.dry_cleaning_rounded, 'Mont / Palto Ekle', () { Navigator.pop(context); _pickAndAddImage(ClothingCategory.coat); }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSection3_OutfitBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('3. Kombinini Oluştur', style: AppTheme.heading2),
        const SizedBox(height: 4),
        const Text('Kıyafetlerinden seçim yap ve üzerinde nasıl durduğunu gör.', style: AppTheme.body),
        const SizedBox(height: 12),
        Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildOutfitGrid(_tops, _bottoms),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isLoading ? null : _createOutfit,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _isLoading ? AppTheme.textSecondary : AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutfitPreview(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildGenerateButtons(),
      ],
    );
  }

  Widget _buildOutfitGrid(List<ImageItem> tops, List<ImageItem> bottoms) {
    final allItems = <_GridSelectItem>[
      ...tops.asMap().entries.map((e) => _GridSelectItem(e.value, ClothingCategory.top, e.key)),
      ...bottoms.asMap().entries.map((e) => _GridSelectItem(e.value, ClothingCategory.bottom, e.key)),
    ];

    if (allItems.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Kıyafet ekleyin', style: AppTheme.caption, textAlign: TextAlign.center)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1),
      itemCount: allItems.length > 4 ? 4 : allItems.length,
      itemBuilder: (context, i) {
        final entry = allItems[i];
        final bool isSelected = entry.category == ClothingCategory.top
            ? _selectedOutfitTopIndex == entry.index
            : _selectedOutfitBottomIndex == entry.index;
        return GestureDetector(
          onTap: () {
            setState(() {
              if (entry.category == ClothingCategory.top) {
                _selectedOutfitTopIndex = isSelected ? null : entry.index;
                _topIndex = entry.index;
              } else {
                _selectedOutfitBottomIndex = isSelected ? null : entry.index;
                _bottomIndex = entry.index;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryLight : AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border, width: isSelected ? 2 : 1),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.file(File(entry.item.path), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary)),
                ),
                if (isSelected)
                  Positioned(top: 4, right: 4, child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                  )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutfitPreview() {
    if (_generatedOutfitImage != null) {
      return Stack(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppTheme.background),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_generatedOutfitImage!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare_rounded, size: 12, color: AppTheme.textPrimary),
                  SizedBox(width: 4),
                  Text('Karşılaştır', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (_userImage != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppTheme.background),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_userImage!, fit: BoxFit.cover, width: double.infinity),
        ),
      );
    }
    return Container(
      height: 200,
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
      child: const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary, size: 40),
          SizedBox(height: 8),
          Text('Önizleme', style: AppTheme.caption),
        ],
      )),
    );
  }

  Widget _buildGenerateButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null : _createOutfit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 18),
            minimumSize: const Size(double.infinity, 0),
            elevation: 0,
          ),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Kombinimi Oluştur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              SizedBox(height: 2),
              Text('Nano Banana (Gemini) ile oluştur', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white70)),
            ],
          ),
        ),
        
        // EĞER KOMBİN OLUŞTURULDUYSA KAYDET BUTONUNU GÖSTER
        if (_generatedOutfitImage != null) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveOutfitToWardrobe,
            icon: const Icon(Icons.bookmark_add_rounded, size: 20),
            label: const Text('Kombinlerime Ekle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
              elevation: 0,
            ),
          )
        ],

        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading ? null : _createOutfitFromCustomPrompt,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            minimumSize: const Size(double.infinity, 0),
          ),
          child: const Text(
            '✏️  Özel istek gir',
            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // =================================================================
  // WARDROBE TAB
  // =================================================================
  Widget _buildWardrobeTab() {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          backgroundColor: AppTheme.background,
          floating: true,
          title: Text('Gardırop', style: AppTheme.heading1),
          centerTitle: false,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategorySection('Üst Giyim', _tops, ClothingCategory.top),
                const SizedBox(height: 20),
                _buildCategorySection('Alt Giyim', _bottoms, ClothingCategory.bottom),
                const SizedBox(height: 20),
                _buildCategorySection('Mont / Palto', _coats, ClothingCategory.coat),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String title, List<ImageItem> items, ClothingCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTheme.heading2),
            _AddButton(onTap: () => _pickAndAddImage(category)),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            height: 100,
            decoration: AppTheme.cardDecoration,
            child: Center(child: Text('$title ekleyin', style: AppTheme.body)),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1),
            itemCount: items.length,
            itemBuilder: (context, i) {
              return _ClothingGridItem(
                item: items[i],
                onDelete: () => _removeClothingItem(category, i),
              );
            },
          ),
      ],
    );
  }

  // =================================================================
  // OUTFITS TAB (YENİLENMİŞ)
  // =================================================================
  Widget _buildOutfitsTab() {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          backgroundColor: AppTheme.background,
          floating: true,
          title: Text('Kombinlerim', style: AppTheme.heading1),
          centerTitle: false,
        ),
        if (_savedOutfits.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.star_rounded, color: AppTheme.primary, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text('Henüz Kombin Yok', style: AppTheme.heading2),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text('Ana sayfadan kombin oluşturduktan sonra "Kombinlerime Ekle" butonu ile buraya kaydedebilirsin.', 
                      style: AppTheme.body, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.70, // Resimlerin daha dikey durması için
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _savedOutfits[index];
                  return _buildSavedOutfitCard(item, index);
                },
                childCount: _savedOutfits.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSavedOutfitCard(ImageItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ]
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(item.path), 
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () {
                print('[Storage] Deleting saved outfit at index $index');
                setState(() { _savedOutfits.removeAt(index); });
                File(item.path).delete().catchError((e) => print('[Storage] ERROR deleting outfit file: $e'));
                _showSnack('Kombin silindi.');
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(color: AppTheme.primaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Profil', style: AppTheme.heading2),
          const SizedBox(height: 8),
          const Text('Profil ayarlarınız burada olacak.', style: AppTheme.body),
        ],
      ),
    );
  }
}

// =================================================================
// YARDIMCI WIDGET'LAR
// =================================================================

class _ClothingEntry {
  final ImageItem item;
  final ClothingCategory category;
  final int index;
  _ClothingEntry(this.item, this.category, this.index);
}

class _GridSelectItem {
  final ImageItem item;
  final ClothingCategory category;
  final int index;
  _GridSelectItem(this.item, this.category, this.index);
}

class _ClothingGridItem extends StatelessWidget {
  final ImageItem item;
  final VoidCallback? onDelete;

  const _ClothingGridItem({required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              File(item.path), 
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: AppTheme.textSecondary)
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle, border: Border.all(color: AppTheme.border)),
                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.danger),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: AppTheme.primary, size: 16),
            SizedBox(width: 4),
            Text('Kıyafet Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}