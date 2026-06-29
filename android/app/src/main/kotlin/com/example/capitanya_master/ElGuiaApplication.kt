package com.example.capitanya_master

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build

/**
 * Crea el canal de alertas con sonido custom ANTES de que llegue cualquier push FCM.
 * Android no permite cambiar el sonido de un canal ya creado.
 */
class ElGuiaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        crearCanalAlertas()
    }

    private fun crearCanalAlertas() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channelId = "elguia_alertas_v4"
        val nm = getSystemService(NotificationManager::class.java) ?: return

        listOf(
            "capitanya_mensajes",
            "elguia_alertas",
            "elguia_alertas_v2",
            "elguia_alertas_v3",
        ).forEach { nm.deleteNotificationChannel(it) }

        val soundUri =
            Uri.parse("android.resource://$packageName/${R.raw.elguia_alertas}")
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val channel = NotificationChannel(
            channelId,
            "Alertas El Guia YA",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Cotizaciones, viajes y alertas con sonido"
            setSound(soundUri, audioAttributes)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 400, 200, 400)
            setShowBadge(true)
        }
        nm.createNotificationChannel(channel)
    }
}
