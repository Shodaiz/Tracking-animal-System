import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class RfidScannerScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;

  const RfidScannerScreen({
    super.key,
    this.title = 'Scanner RFID',
    this.subtitle = 'Positionnez le code devant la caméra',
    this.color = const Color(0xFF1B5E20),
  });

  @override
  State<RfidScannerScreen> createState() => _RfidScannerScreenState();
}

class _RfidScannerScreenState extends State<RfidScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: widget.color,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, null),
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
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (_scanned) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  setState(() => _scanned = true);
                  Navigator.pop(context, value);
                  break;
                }
              }
            },
          ),

          // Overlay with scan frame
          CustomPaint(
            painter: _ScannerOverlayPainter(borderColor: widget.color),
            child: const SizedBox.expand(),
          ),

          // Bottom info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.qr_code_scanner, color: widget.color, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ou entrez manuellement :',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _ManualInputRow(
                    color: widget.color,
                    onSubmit: (val) {
                      if (val.isNotEmpty) Navigator.pop(context, val);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay painter (cadre de scan)
class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  _ScannerOverlayPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = size.width * 0.65;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2 - 60;
    final double right = left + scanAreaSize;
    final double bottom = top + scanAreaSize;

    // Fond sombre
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.55);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, bottom, size.width, size.height - bottom), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, top, left, scanAreaSize), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(right, top, size.width - right, scanAreaSize), backgroundPaint);

    // Cadre
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const double cornerLen = 30;

    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), borderPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), borderPaint);

    // Top-right corner
    canvas.drawLine(Offset(right - cornerLen, top), Offset(right, top), borderPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLen), borderPaint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, bottom - cornerLen), Offset(left, bottom), borderPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLen, bottom), borderPaint);

    // Bottom-right corner
    canvas.drawLine(Offset(right - cornerLen, bottom), Offset(right, bottom), borderPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLen), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Widget saisie manuelle en bas
class _ManualInputRow extends StatefulWidget {
  final Color color;
  final Function(String) onSubmit;

  const _ManualInputRow({required this.color, required this.onSubmit});

  @override
  State<_ManualInputRow> createState() => _ManualInputRowState();
}

class _ManualInputRowState extends State<_ManualInputRow> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ex: DZ-0007',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white38),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.color),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: () => widget.onSubmit(_ctrl.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Icon(Icons.search, color: Colors.white),
        ),
      ],
    );
  }
}