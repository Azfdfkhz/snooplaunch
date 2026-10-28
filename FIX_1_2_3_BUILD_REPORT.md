# Perbaikan build 1.2.3 (assembleRelease gagal)

**Error:** `Platform declaration clash: setAppVisible(Z)V` di `SnoopNotificationListener.kt` (object `IslandBridge`).

**Penyebab:** `var appVisible` otomatis membuat setter JVM `setAppVisible(Boolean)`, sama dengan `fun setAppVisible(v: Boolean)` buatan sendiri.

**Perbaikan:** `appVisible` diberi `private set` sehingga setter otomatis tidak dibuat. Nilai hanya diubah lewat `IslandBridge.setAppVisible()`; pemanggil di `MainActivity.kt` tidak berubah.

**Catatan:** peringatan `share_plus` (Built-in Kotlin) dan `--enable-native-access` hanya warning, tidak menggagalkan build.
