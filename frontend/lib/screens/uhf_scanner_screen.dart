import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class UhfScannerScreen extends StatefulWidget {
  const UhfScannerScreen({super.key});

  @override
  State<UhfScannerScreen> createState() => _UhfScannerScreenState();
}

class _UhfScannerScreenState extends State<UhfScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  final List<String> detectedTags = [];
  bool _torchOn = false;
  bool _isActive = true;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onTagDetected(String tag) {
    final cleaned = tag.trim().toUpperCase();
    if (!detectedTags.contains(cleaned) && cleaned.isNotEmpty) {
      setState(() => detectedTags.add(cleaned));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Scanner UHF',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            Text('Portée : 5-6 mètres • Lecture multiple',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, detectedTags),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () {
              cameraController.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: Icon(
              _isActive ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() => _isActive = !_isActive);
              if (_isActive) {
                cameraController.start();
              } else {
                cameraController.stop();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera View
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    if (!_isActive) return;
                    for (final barcode in capture.barcodes) {
                      final value = barcode.rawValue;
                      if (value != null) _onTagDetected(value);
                    }
                  },
                ),

                // Overlay UHF
                CustomPaint(
                  painter: _UhfOverlayPainter(),
                  child: const SizedBox.expand(),
                ),

                // Compteur en temps réel
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${detectedTags.length} Tag(s) Détecté(s)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Indicateur scan actif/inactif
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isActive ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isActive ? '🟢 Scan actif' : '⏸ En pause',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste des tags détectés
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF1A237E),
                    child: Row(
                      children: [
                        const Icon(Icons.list_alt,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tags détectés : ${detectedTags.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const Spacer(),
                        if (detectedTags.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setState(() => detectedTags.clear()),
                            child: const Text('Effacer',
                                style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: detectedTags.isEmpty
                        ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.radar,
                              size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Scannez les tags RFID/QR des animaux',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: detectedTags.length,
                      itemBuilder: (_, i) {
                        final tag = detectedTags[i];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(tag,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 18),
                            onPressed: () =>
                                setState(() => detectedTags.remove(tag)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bouton Valider
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Saisie manuelle
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Ajouter un tag manuellement (DZ-0007)',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) _onTagDetected(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bouton valider
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, detectedTags),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(
                      'Valider ${detectedTags.length} tag(s) et continuer',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay UHF
class _UhfOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2 - 30;

    final darkPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final double scanW = size.width * 0.8;
    final double scanH = size.height * 0.4;
    final double left = centerX - scanW / 2;
    final double top = centerY - scanH / 2;
    final double right = left + scanW;
    final double bottom = top + scanH;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), darkPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, bottom, size.width, size.height - bottom), darkPaint);
    canvas.drawRect(Rect.fromLTWH(0, top, left, scanH), darkPaint);
    canvas.drawRect(Rect.fromLTWH(right, top, size.width - right, scanH), darkPaint);

    final borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const double c = 30;
    canvas.drawLine(Offset(left, top + c), Offset(left, top), borderPaint);
    canvas.drawLine(Offset(left, top), Offset(left + c, top), borderPaint);
    canvas.drawLine(Offset(right - c, top), Offset(right, top), borderPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + c), borderPaint);
    canvas.drawLine(Offset(left, bottom - c), Offset(left, bottom), borderPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + c, bottom), borderPaint);
    canvas.drawLine(Offset(right - c, bottom), Offset(right, bottom), borderPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - c), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}