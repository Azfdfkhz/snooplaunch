# Braun + posisi UI SnoopLaunch lama

Fitur: kode logika (state, services, Android native, Supabase) di snooplaunch-main dan snooplaunch-braun identik (sama-sama 1.3.0+20). Braun hanya skin UI, jadi tidak ada fitur yang hilang; tidak ada yang perlu dipindah.

## Posisi dikembalikan seperti versi lama, detail tetap Braun
- Beranda: panel penuh lebar dengan sudut kanan-bawah terpotong organik; logo + SNOOP kiri-atas, tombol cari kanan-atas, jam besar rata kiri + tanggal di bawahnya, identitas (sapaan + nama) kiri-bawah. Detail: badan plastik, jendela LCD 7-segmen, knob oranye, kisi speaker.
- Navigasi bawah: tinggi dikembalikan (label "snoop 1" di bawah tombol dihapus); tombol timbul + lampu oranye tetap.

## Yang terasa kurang, diperbaiki
- Ikon status bar & navigation bar kini gelap (sebelumnya terang di atas latar terang, hampir tak terlihat, terutama di App Drawer).
- Riak sentuh ikon dock sekarang terlihat (Material transparan di atas badan dock).
- Chip "Ulangi" di dialog Pengingat memakai bentuk tombol Braun.

## Belum diverifikasi
Flutter SDK tidak tersedia di sini: kode belum dikompilasi. Jalankan flutter pub get, flutter analyze, flutter test, lalu cek visual Beranda di HP.
