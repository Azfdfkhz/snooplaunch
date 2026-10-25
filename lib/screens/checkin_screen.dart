import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../main.dart';
import '../services/capture_service.dart';

class CheckInScreen extends StatefulWidget {
  final bool isOut;
  const CheckInScreen({super.key, this.isOut = false});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  bool _loading = false;

  Future<void> _run() async {
    final s = AppScope.of(context);
    if (_loading || s.busy) return; // cegah tap ganda
    setState(() => _loading = true);
    s.busy = true;
    try {
      final res = await CaptureService.capture();
      if (res == null || !mounted) return;
      final ok = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: C.bg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _Preview(res: res, isOut: widget.isOut),
      );
      if (ok != true || !mounted) return;
      final now = DateTime.now(); // waktu dicatat saat dikonfirmasi
      final saved = widget.isOut ? s.recordCheckOut(at: now) : s.recordCheckIn(at: now);
      if (!saved) {
        _snack('Absensi sudah tercatat hari ini.');
      } else {
        final near = s.scheduleNear(now);
        s.addMemory(Memory(
          id: const Uuid().v4(),
          title: near?.title ?? (widget.isOut ? 'Absen Pulang' : 'Absen Masuk'),
          scheduleId: near?.id,
          photoPath: res.photoPath,
          capturedAt: now,
          lat: res.lat, lng: res.lng, accuracy: res.accuracy, placeName: res.placeName,
          description: widget.isOut ? 'Dokumentasi absen pulang.' : 'Dokumentasi absen masuk.',
        ));
        _snack(widget.isOut ? 'Absen pulang tercatat ${hm(now)}.' : 'Absen masuk tercatat ${hm(now)}.');
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      s.busy = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.isOut ? 'Absensi Pulang' : 'Absensi Masuk'), backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 12),
          const Mascot(size: 150),
          const SizedBox(height: 16),
          Text(widget.isOut ? 'Waktunya pulang!' : 'Ayo absen!', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Pastikan kamu berada di lokasi kerja\ndan aktifkan kamera serta lokasi.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          SnoopCard(color: C.soft, child: Row(children: [
            const Icon(Icons.event_outlined), const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.isOut ? 'Jadwal Pulang' : 'Jadwal Masuk', style: Theme.of(context).textTheme.bodySmall),
              Text(minToHm(widget.isOut ? s.workEndMin : s.workStartMin), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ])),
          const SizedBox(height: 8),
          SnoopCard(color: C.soft, child: Row(children: [
            const Icon(Icons.place_outlined), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lokasi', style: Theme.of(context).textTheme.bodySmall),
              Text(s.company, style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          ])),
          const Spacer(),
          PillButton(icon: Icons.photo_camera_outlined, label: _loading ? 'Memproses...' : 'Mulai Absen', onPressed: _loading ? null : _run),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final CaptureResult res;
  final bool isOut;
  const _Preview({required this.res, required this.isOut});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Tinjau dokumentasi', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 240, width: double.infinity, child: Image.file(File(res.photoPath), fit: BoxFit.cover, cacheWidth: 900))),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.schedule, size: 16, color: C.text2), const SizedBox(width: 6), Text('${hm(now)} WIB', style: Theme.of(context).textTheme.bodyMedium)]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.place_outlined, size: 16, color: C.text2), const SizedBox(width: 6),
            Expanded(child: Text(
              res.lat == null
                  ? (res.locationNote.isEmpty ? 'Lokasi tidak tersedia' : res.locationNote)
                  : '${res.placeName ?? 'Koordinat'} (${res.lat!.toStringAsFixed(5)}, ${res.lng!.toStringAsFixed(5)}) ±${res.accuracy?.round() ?? '?'} m'
                    '${res.locationNote.isEmpty ? '' : '\n${res.locationNote}'}',
              style: Theme.of(context).textTheme.bodyMedium)),
          ]),
          const SizedBox(height: 16),
          PillButton(label: isOut ? 'Konfirmasi Absen Pulang' : 'Konfirmasi Absen Masuk', onPressed: () => Navigator.pop(context, true)),
          const SizedBox(height: 8),
          PillButton(label: 'Ulangi', dark: false, onPressed: () => Navigator.pop(context, false)),
        ]),
      ),
    );
  }
}
