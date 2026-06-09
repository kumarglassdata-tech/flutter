package com.smartglass.ai.smartglass_flutter

import android.app.Application
import com.meta.wearable.dat.core.Wearables

class SmartGlassApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Wearables.initialize(this)
    }
}
