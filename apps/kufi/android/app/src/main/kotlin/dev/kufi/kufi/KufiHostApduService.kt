package dev.kufi.kufi

import android.nfc.cardemulation.HostApduService
import android.os.Bundle

/**
 * Emulación de tarjeta en Android. Un lector que selecciona el AID recibe
 * el texto que la app dejó en [mensajeActual], más el estado 90 00.
 * iOS no tiene este camino.
 */
class KufiHostApduService : HostApduService() {
    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val cuerpo = mensajeActual.toByteArray(Charsets.UTF_8)
        return cuerpo + byteArrayOf(0x90.toByte(), 0x00.toByte())
    }

    override fun onDeactivated(reason: Int) {}

    companion object {
        var mensajeActual: String = ""
    }
}
