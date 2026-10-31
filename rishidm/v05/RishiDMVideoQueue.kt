package com.abdownloadmanager.desktop.media

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import java.io.File
import java.net.URI
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

@Serializable
data class RishiVideoTask(
    val id: String,
    val url: String,
    val state: String = "Queued",
    val quality: String = "4K",
    val percent: Int = 0,
    val message: String = "Select a quality to start"
)

/** Video tasks live in the DESKTOP process, not the short-lived native host. */
object RishiDMVideoQueue {
    private val guard = Any()
    private val json = Json { prettyPrint = true; ignoreUnknownKeys = true }
    private val storage: File by lazy {
        val dir = System.getenv("LOCALAPPDATA")?.takeIf { it.isNotBlank() }
            ?: File(System.getProperty("user.home"), "AppData/Local").absolutePath
        File(dir, "RishiDM/video-tasks.json")
    }
    private fun readSaved(): List<RishiVideoTask> = runCatching {
        if (!storage.isFile) emptyList() else
            json.decodeFromString<List<RishiVideoTask>>(storage.readText())
                .map {
                    if (it.state in setOf("Starting", "Downloading", "Processing"))
                        it.copy(state = "Interrupted", message = "Interrupted: select Resume")
                    else it
                }.takeLast(60)
    }.getOrDefault(emptyList())

    private val state = MutableStateFlow(readSaved())
    val tasks: StateFlow<List<RishiVideoTask>> = state
    private val running = ConcurrentHashMap<String, Process>()
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    private val percentRegex = Regex("""(?<!\d)(\d{1,3}(?:\.\d+)?)%""")

    private fun persist(items: List<RishiVideoTask>) {
        runCatching {
            storage.parentFile.mkdirs()
            val tmp = File(storage.parentFile, "video-tasks.json.tmp")
            tmp.writeText(json.encodeToString(items))
            try {
                Files.move(tmp.toPath(), storage.toPath(),
                    StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
            } catch (_: Exception) {
                Files.move(tmp.toPath(), storage.toPath(), StandardCopyOption.REPLACE_EXISTING)
            }
        }
    }

    private fun change(id: String, fn: (RishiVideoTask) -> RishiVideoTask) {
        synchronized(guard) {
            val updated = state.value.map { if (it.id == id) fn(it) else it }
            state.value = updated
            persist(updated)
        }
    }

    fun enqueue(requested: String): Boolean {
        val url = runCatching {
            require(requested.length in 8..2048)
            val uri = URI(requested)
            require(uri.scheme?.lowercase() in setOf("http", "https"))
            require(!uri.host.isNullOrBlank() && uri.rawUserInfo == null)
            require(requested.none { it.isISOControl() })
            uri.toString()
        }.getOrNull() ?: return false
        synchronized(guard) {
            if (state.value.any {
                    it.url == url && it.state in setOf("Queued", "Starting", "Downloading", "Processing")
                }) return true
            val updated = (state.value + RishiVideoTask(UUID.randomUUID().toString(), url)).takeLast(60)
            state.value = updated
            persist(updated)
        }
        return true
    }

    fun remove(id: String) {
        if (running.containsKey(id)) return
        synchronized(guard) {
            val updated = state.value.filterNot { it.id == id }
            state.value = updated
            persist(updated)
        }
    }

    fun cancel(id: String) {
        cancelled.add(id)
        running[id]?.destroyForcibly()
        change(id) { it.copy(state = "Cancelled", message = "Cancelled (partial file may resume)") }
    }

    fun start(id: String, quality: String) {
        val job = synchronized(guard) {
            val found = state.value.find { it.id == id } ?: return
            if (found.state in setOf("Starting", "Downloading", "Processing")) return
            change(id) { it.copy(state = "Starting", quality = quality, message = "Preparing media") }
            found
        }
        cancelled.remove(id)
        thread(isDaemon = true, name = "rishidm-video-$id") {
            var last = ""
            var lastError = ""
            try {
                val install = com.abdownloadmanager.desktop.utils.AppInfo.installationFolder
                val folder = install?.let { File(it) } ?: File(System.getProperty("user.dir"))
                val yt = File(folder, "VideoTools/yt-dlp.exe")
                val ff = File(folder, "VideoTools/FFmpeg")
                val deno = File(folder, "VideoTools/deno.exe")
                require(yt.isFile && File(ff, "ffmpeg.exe").isFile && deno.isFile) {
                    "Media tools are missing: reinstall the complete RishiDM package"
                }
                val output = File(System.getProperty("user.home"), "Downloads")
                output.mkdirs()
                val fmt = when (quality) {
                    "8K" -> "bv[height<=4320]+ba/b[height<=4320]"
                    "4K" -> "bv[height<=2160]+ba/b[height<=2160]"
                    "1440p" -> "bv[height<=1440]+ba/b[height<=1440]"
                    "1080p" -> "bv[height<=1080]+ba/b[height<=1080]"
                    "720p" -> "bv[height<=720]+ba/b[height<=720]"
                    else -> "bv+ba/b"
                }
                val arguments = listOf(
                    yt.absolutePath, "--no-config", "--no-playlist", "--windows-filenames",
                    "--continue", "--no-overwrites", "--newline",
                    "--retries", "10", "--fragment-retries", "10", "--retry-sleep", "2",
                    "--concurrent-fragments", "4",
                    "--ffmpeg-location", ff.absolutePath, "--js-runtimes", "deno:" + deno.absolutePath,
                    "--format", fmt, "--merge-output-format", "mkv",
                    "-o", File(output, "%(title).150B [%(id)s].%(ext)s").absolutePath,
                    "--", job.url
                )
                val proc = ProcessBuilder(arguments).directory(folder).redirectErrorStream(true).start()
                running[id] = proc
                if (id in cancelled) proc.destroyForcibly()
                else change(id) { it.copy(state = "Downloading", message = "Downloading video and audio") }
                proc.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line ->
                        last = line.take(320)
                        val percent = percentRegex.find(line)?.groupValues?.get(1)?.toDoubleOrNull()?.toInt()
                        when {
                            id in cancelled -> Unit
                            line.startsWith("[Merger]") || line.startsWith("[ExtractAudio]") ->
                                change(id) { it.copy(state = "Processing", message = "Merging media tracks") }
                            percent != null && percent in 0..100 ->
                                change(id) { if (it.state == "Downloading" && it.percent == percent) it
                                    else it.copy(state = "Downloading", percent = percent, message = last) }
                            line.startsWith("ERROR:") -> {
                                lastError = last
                                change(id) { it.copy(message = lastError) }
                            }
                        }
                    }
                }
                val code = proc.waitFor()
                when {
                    cancelled.remove(id) ->
                        change(id) { it.copy(state = "Cancelled", message = "Cancelled") }
                    code == 0 ->
                        change(id) { it.copy(state = "Completed", percent = 100, message = "Saved to Downloads") }
                    else -> {
                        val reason = lastError.ifBlank { last.ifBlank { "Extractor exit code $code" } }
                        val guidance = when {
                            reason.contains("login", ignoreCase = true) ||
                                reason.contains("sign in", ignoreCase = true) ||
                                reason.contains("authentication", ignoreCase = true) ->
                                "Login may be required. RishiDM does not read browser cookies automatically. " + reason
                            reason.contains("403", ignoreCase = true) ->
                                "Source denied access (HTTP 403). Check access rights. " + reason
                            reason.contains("404", ignoreCase = true) ->
                                "Source returned HTTP 404; changing quality will not repair this URL. " + reason
                            else -> reason
                        }
                        change(id) { it.copy(state = "Failed", message = guidance.take(500)) }
                    }
                }
            } catch (e: Exception) {
                if (cancelled.remove(id)) change(id) { it.copy(state = "Cancelled", message = "Cancelled") }
                else change(id) { it.copy(state = "Failed", message = e.message?.take(300) ?: "Video download failed") }
            } finally {
                running.remove(id)
            }
        }
    }
}
