package com.example.snoop

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Update 1.2.9: layanan Aksesibilitas kosong. Satu-satunya tujuannya: memberi SNOOP konteks jendela yang boleh memakai
 * TYPE_ACCESSIBILITY_OVERLAY (di atas status bar sistem). Tidak membaca layar dan mengabaikan semua peristiwa.
 */
class SnoopAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var instance: SnoopAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        IslandBridge.a11yChanged()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) { /* sengaja kosong */ }

    override fun onInterrupt() { /* sengaja kosong */ }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        IslandBridge.a11yChanged()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
