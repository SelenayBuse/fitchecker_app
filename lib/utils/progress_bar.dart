import 'package:flutter/material.dart';
import 'package:flutter95/flutter95.dart'; // Flutter95 teması için gerekli

// 1. StatefulWidget'e dönüştürüldü
class RetroProgressBar95 extends StatefulWidget {
  final String? message;
  final VoidCallback? onCancel;
  final Color progressBarColor;
  final Color backgroundColor;
  final double width;
  final double height;
  final int segmentCount;
  final double segmentSpacing;
  final Duration duration; // Hızı ayarlamak için yeni parametre

  const RetroProgressBar95({
    Key? key,
    this.message = "Loading...",
    this.onCancel,
    this.progressBarColor = const Color(0xFFF472B6),
    this.backgroundColor = Flutter95.white,
    this.width = 250.0,
    this.height = 20.0,
    this.segmentCount = 15,
    this.segmentSpacing = 2.0,
    // 2. Varsayılan süre 2 saniyeden 800 milisaniyeye (0.8 saniye) düşürüldü.
    // Burayı değiştirerek hızı ayarlayabilirsiniz.
    this.duration = const Duration(milliseconds: 800),
  }) : super(key: key);

  @override
  _RetroProgressBar95State createState() => _RetroProgressBar95State();
}

// 3. State sınıfı ve SingleTickerProviderStateMixin eklendi
class _RetroProgressBar95State extends State<RetroProgressBar95>
    with SingleTickerProviderStateMixin {
  
  // 4. Animasyon Controller'ı tanımlandı
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration, // Hız parametresi buradan alınıyor
    )
      // 5. Animasyonun sürekli tekrar etmesi sağlandı
      ..repeat(); 
  }

  @override
  void dispose() {
    _controller.dispose(); // 6. Controller temizlendi
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Elevation95(
      type: Elevation95Type.up,
      child: Container(
        color: Flutter95.background,
        padding: const EdgeInsets.all(20.0),
        constraints: BoxConstraints(maxWidth: widget.width + 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message!,
              style: Flutter95.textStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16.0),
            Elevation95(
              type: Elevation95Type.down,
              child: Container(
                width: widget.width,
                height: widget.height,
                color: widget.backgroundColor,
                // 7. TweenAnimationBuilder yerine AnimatedBuilder kullanıldı
                child: AnimatedBuilder(
                  animation: _controller, // Controller'ı dinle
                  builder: (context, child) {
                    // Controller'ın o anki değeri (0.0 -> 1.0)
                    final double value = _controller.value;
                    final int filledSegments = (widget.segmentCount * value).floor();

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(widget.segmentCount, (index) {
                        return Container(
                          width: (widget.width / widget.segmentCount) -
                              widget.segmentSpacing,
                          height: widget.height,
                          margin: EdgeInsets.only(
                              right: index < widget.segmentCount - 1
                                  ? widget.segmentSpacing
                                  : 0),
                          color: index < filledSegments
                              ? widget.progressBarColor
                              : Colors.transparent,
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20.0),
            if (widget.onCancel != null)
              Button95(
                onTap: widget.onCancel,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    'Cancel',
                    style: Flutter95.textStyle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}