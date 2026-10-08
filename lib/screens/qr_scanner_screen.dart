import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/sync/sync_pairing.dart';
import '../theme/app_theme.dart';

/// Full-screen camera scanner used by the phone to read the desktop's
/// pairing QR code. Pops with a [SyncPairingInfo] on success.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;
  String? _notice;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      final info = SyncPairingInfo.tryParse(raw);
      if (info == null) {
        setState(() => _notice = 'That isn\'t an Adey sync QR code.');
        continue;
      }

      _handled = true;
      Navigator.of(context).pop(info);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Scan desktop QR code'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchable = state.torchState != TorchState.unavailable;
              return IconButton(
                tooltip: 'Torch',
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flashlight_on
                      : Icons.flashlight_off,
                  color: torchable ? Colors.white : Colors.white38,
                ),
                onPressed: torchable ? _controller.toggleTorch : null,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              children: [
                if (_notice != null) ...[
                  Text(
                    _notice!,
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(color: AppColors.danger),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Point the camera at the QR code shown in '
                  'the desktop\'s Settings screen.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported =
        error.errorCode == MobileScannerErrorCode.unsupported;

    final message = permissionDenied
        ? 'Camera access is needed to scan the QR code. '
            'Allow camera access for Adey in system settings, then come back.'
        : unsupported
            ? 'This device can\'t scan QR codes with the camera.'
            : 'Could not open the camera. Close and reopen this screen.';

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionDenied
                    ? Icons.no_photography_outlined
                    : Icons.error_outline,
                color: Colors.white54,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.bodyRegular.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              if (permissionDenied)
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
