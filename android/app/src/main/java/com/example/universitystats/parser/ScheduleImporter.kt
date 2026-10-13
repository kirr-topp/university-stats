package com.example.universitystats.parser

import android.content.Context
import android.net.Uri
import android.util.Base64
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import com.example.universitystats.data.ScheduleStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONTokener
import java.net.HttpURLConnection
import java.net.URL
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset

class ScheduleImporter(
    private val context: Context,
    private val store: ScheduleStore
) {
    suspend fun importUrl(url: String): Result<ImportSummary> {
        val clean = extractUrl(url)
            ?: return Result.failure(IllegalArgumentException("Не удалось найти ссылку на расписание."))
        return withContext(Dispatchers.IO) {
            runCatching {
                val html = download(clean)
                importHtmlText(html)
            }
        }
    }

    suspend fun importOfflineFile(uri: Uri): Result<ImportSummary> = withContext(Dispatchers.IO) {
        runCatching {
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: error("Не удалось открыть файл. Попробуй выбрать его ещё раз.")
            val text = decodeOfflineDocument(bytes)
            val summary = importHtmlText(text)
            summary
        }
    }

    private fun importHtmlText(source: String): ImportSummary {
        val parsed = ScheduleParser.parseHtml(source)
        val lessons = parsed.days.sumOf { it.lessons.size }
        if (lessons == 0) error("В файле не распознано ни одной пары. Сохрани страницу расписания, а не страницу входа.")
        store.merge(parsed)
        return ImportSummary(parsed.days.count { it.lessons.isNotEmpty() }, lessons)
    }

    private fun decodeOfflineDocument(bytes: ByteArray): String {
        // Chrome's saved offline page is usually MHTML (multipart MIME); plain HTML is supported too.
        val probe = bytes.toString(Charsets.ISO_8859_1)
        if (probe.contains("Content-Type: multipart/related", ignoreCase = true) ||
            probe.contains("Content-Transfer-Encoding:", ignoreCase = true)) {
            val boundary = Regex("boundary=\"?([^;\"\r\n]+)", RegexOption.IGNORE_CASE)
                .find(probe)?.groupValues?.getOrNull(1)
            if (boundary != null) {
                val parts = probe.split("--$boundary")
                for (part in parts) {
                    if (!part.contains("Content-Type:", ignoreCase = true)) continue
                    val headerEnd = part.indexOf("\r\n\r\n").takeIf { it >= 0 }
                        ?: part.indexOf("\n\n").takeIf { it >= 0 } ?: continue
                    val headers = part.substring(0, headerEnd)
                    if (!headers.contains("text/html", ignoreCase = true)) continue
                    val body = part.substring(headerEnd).trimEnd('-', '\r', '\n')
                    val charsetName = Regex("charset=\"?([^;\"\\s]+)", RegexOption.IGNORE_CASE)
                        .find(headers)?.groupValues?.getOrNull(1) ?: "UTF-8"
                    val charset = runCatching { Charset.forName(charsetName) }.getOrDefault(Charsets.UTF_8)
                    val encoding = Regex("Content-Transfer-Encoding:\\s*([^\r\n]+)", RegexOption.IGNORE_CASE)
                        .find(headers)?.groupValues?.getOrNull(1)?.trim()?.lowercase()
                    val decoded = when (encoding) {
                        "base64" -> runCatching { Base64.decode(body.filterNot { it.isWhitespace() }, Base64.DEFAULT).toString(charset) }.getOrNull()
                        "quoted-printable" -> decodeQuotedPrintable(body, charset)
                        else -> body
                    }
                    if (decoded != null && (decoded.contains("days[") || decoded.contains("ScheduleCell"))) return decoded
                }
            }
        }
        // If MIME decoding did not apply, use the original text and let the parser report a useful error.
        return bytes.toString(Charsets.UTF_8)
    }

    private fun decodeQuotedPrintable(body: String, charset: Charset): String {
        val clean = body.replace("=\r\n", "").replace("=\n", "")
        val out = ByteArrayOutputStream(clean.length)
        var i = 0
        while (i < clean.length) {
            if (clean[i] == '=' && i + 2 < clean.length) {
                val hex = clean.substring(i + 1, i + 3).toIntOrNull(16)
                if (hex != null) { out.write(hex); i += 3; continue }
            }
            val cp = clean.codePointAt(i)
            val charText = String(Character.toChars(cp))
            out.write(charText.toByteArray(Charsets.ISO_8859_1))
            i += Character.charCount(cp)
        }
        return out.toByteArray().toString(charset)
    }

    private suspend fun download(url: String): String = withContext(Dispatchers.IO) {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            instanceFollowRedirects = true
            connectTimeout = 15_000
            readTimeout = 20_000
            setRequestProperty(
                "User-Agent",
                "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/155 Mobile Safari/537.36"
            )
            setRequestProperty("Accept", "text/html,application/xhtml+xml")
        }
        try {
            if (connection.responseCode !in 200..399) {
                error("Сайт вернул HTTP ${connection.responseCode}")
            }
            connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    fun importWithWebView(url: String, onResult: (Result<Int>) -> Unit): WebView {
        val webView = WebView(context)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.userAgentString =
            "Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 Chrome/155 Mobile Safari/537.36"
        CookieManager.getInstance().setAcceptCookie(true)
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, loadedUrl: String) {
                view.evaluateJavascript("document.documentElement.outerHTML") { quotedHtml ->
                    val html = decodeJsResult(quotedHtml)
                    CoroutineScope(Dispatchers.Main).launch {
                        val result = withContext(Dispatchers.Default) {
                            runCatching {
                                val parsed = ScheduleParser.parseHtml(html)
                                val count = parsed.days.sumOf { it.lessons.size }
                                if (count == 0) error("В странице не распознаны пары")
                                store.merge(parsed)
                                parsed.days.size
                            }
                        }
                        onResult(result)
                    }
                }
            }

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean = false
        }
        webView.loadUrl(url)
        return webView
    }

    private fun decodeJsResult(value: String): String =
        runCatching { JSONTokener(value).nextValue().toString() }.getOrDefault(value)

    data class ImportSummary(val days: Int, val lessons: Int)

    companion object {
        fun extractUrl(text: String?): String? {
            if (text.isNullOrBlank()) return null
            val match = Regex("https?://[^\\s<>\\\"']+").find(text) ?: return null
            return match.value.trimEnd('.', ',', ')', ']', '}', ';')
        }
    }
}
