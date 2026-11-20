package app.capgo.pdfviewer

import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import io.legere.pdfiumandroid.PdfDocument
import io.legere.pdfiumandroid.PdfiumCore
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import android.util.Base64

class PdfViewer(private val context: Context) {
    private val pdfium = PdfiumCore(context)

    fun getPluginVersion(): String = "native"

    fun openDocument(
        source: String,
        sourceType: String,
        headers: Map<String, String>?,
        password: String?,
    ): PdfDocument {
        return when (sourceType) {
            "url" -> {
                val file = downloadToCache(source, headers)
                val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                pdfium.newDocument(pfd, password)
            }
            "base64" -> {
                val bytes = decodeBase64(source)
                pdfium.newDocument(bytes, password)
            }
            else -> {
                val file = resolveFile(source)
                val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                pdfium.newDocument(pfd, password)
            }
        }
    }

    private fun downloadToCache(urlString: String, headers: Map<String, String>?): File {
        val connection = (URL(urlString).openConnection() as HttpURLConnection).apply {
            instanceFollowRedirects = true
            connectTimeout = 30_000
            readTimeout = 30_000
            headers?.forEach { (key, value) -> setRequestProperty(key, value) }
        }
        try {
            val code = connection.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("Failed to download PDF ($code)")
            }
            val file = File(context.cacheDir, "capgo-pdf-${System.currentTimeMillis()}.pdf")
            connection.inputStream.use { input ->
                FileOutputStream(file).use { output -> input.copyTo(output) }
            }
            return file
        } finally {
            connection.disconnect()
        }
    }

    private fun decodeBase64(source: String): ByteArray {
        val payload = if (source.startsWith("data:", ignoreCase = true)) {
            source.substringAfter(',')
        } else {
            source
        }.replace("\\s".toRegex(), "")
        return Base64.decode(payload, Base64.DEFAULT)
    }

    private fun resolveFile(source: String): File {
        if (source.startsWith("file:", ignoreCase = true)) {
            val path = Uri.parse(source).path ?: throw IllegalArgumentException("Invalid file URL")
            return File(path)
        }
        return File(source)
    }
}
