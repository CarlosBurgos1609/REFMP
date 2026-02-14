package com.music.refmp

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configuración universal del splash screen para todos los fabricantes
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            
            // Para MIUI (Xiaomi/Redmi) - forzar visualización
            if (Build.MANUFACTURER.equals("Xiaomi", ignoreCase = true)) {
                window.clearFlags(WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS)
            }
        }
    }
}
