# Pemulihan 1.2.5 (ditulis ulang dari laporan + IslandOverlay.kt)

BELUM dikompilasi/dijalankan. Perubahan 1.2.5 asli hilang (tertimpa), jadi bagian ini ditulis ulang dan bisa sedikit berbeda dari aslinya.

- Tab Fokus/Musik/Info: tombol bulat 54 dp mengambang di bawah (`_bottomTabs`, `_BottomTabBtn` di `dynamic_island.dart`); baris tab lama di dalam hub dihapus. Tersembunyi saat keyboard terbuka.
- Pil native di atas aplikasi lain: Flutter mengirim spesifikasi pil lewat `SystemBridge.pushIsland` (channel `snoop/system`, metode `island`); `IslandBridge.setIsland/syncOverlay` menampilkan `IslandOverlay` saat SNOOP tidak di layar. Kartu panggilan menimpa pil.
- Ketuk pil -> `IslandBridge.pendingHub`; saat SNOOP muncul, `IslandController` memanggil `SystemBridge.consumeHub()` lalu membuka hub.
- Island di seluruh aplikasi (MaterialApp.builder) sudah ada di proyek Anda dan tidak diubah.
File yang berubah: SnoopNotificationListener.kt, MainActivity.kt, dynamic_island.dart, island_service.dart, system_bridge.dart.
