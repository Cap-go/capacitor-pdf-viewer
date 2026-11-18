package app.capgo.pdfviewer

internal object PdfViewerHelpers {
    fun inferSourceType(source: String, sourceType: String?): String {
        if (!sourceType.isNullOrBlank()) {
            return sourceType
        }
        val trimmed = source.trim()
        if (trimmed.startsWith("data:", ignoreCase = true)) {
            return "base64"
        }
        if (trimmed.startsWith("http://", ignoreCase = true) ||
            trimmed.startsWith("https://", ignoreCase = true)
        ) {
            return "url"
        }
        if (!trimmed.contains("://") && looksLikeBase64(trimmed)) {
            return "base64"
        }
        return "file"
    }

    fun pageIndex(fromOneBased: Int, pageCount: Int): Int {
        if (pageCount <= 0) return 0
        val clamped = fromOneBased.coerceIn(1, pageCount)
        return clamped - 1
    }

    fun oneBasedPage(fromIndex: Int, pageCount: Int): Int {
        if (pageCount <= 0) return 1
        val clamped = fromIndex.coerceIn(0, pageCount - 1)
        return clamped + 1
    }

    /**
     * Parse `#RRGGBB` or `#AARRGGBB`. Returns `null` when the string is absent or invalid.
     */
    fun parseArgbHex(hex: String?): Int? {
        if (hex.isNullOrBlank()) return null
        var cleaned = hex.trim()
        if (cleaned.startsWith("#")) {
            cleaned = cleaned.substring(1)
        }
        if (cleaned.length != 6 && cleaned.length != 8) return null
        if (!cleaned.all { it.isDigit() || it in 'a'..'f' || it in 'A'..'F' }) return null
        val value = cleaned.toLongOrNull(16) ?: return null
        return when (cleaned.length) {
            6 -> (0xFF000000 or value).toInt()
            8 -> value.toInt()
            else -> null
        }
    }

    private fun looksLikeBase64(value: String): Boolean {
        val compact = value.replace("\\s".toRegex(), "")
        if (compact.length <= 32) return false
        return compact.all { it.isLetterOrDigit() || it == '+' || it == '/' || it == '=' }
    }
}