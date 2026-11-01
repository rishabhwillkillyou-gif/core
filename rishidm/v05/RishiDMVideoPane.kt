package com.abdownloadmanager.desktop.pages.home

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.abdownloadmanager.desktop.media.RishiDMVideoQueue
import com.abdownloadmanager.desktop.media.RishiVideoTask
import com.abdownloadmanager.shared.ui.widget.ActionButton
import com.abdownloadmanager.shared.ui.widget.Text
import com.abdownloadmanager.shared.util.ui.myColors
import java.io.File

// Real RishiDM controls: themed Compose UI backed by the existing video queue.
private val violet = Color(0xFFA275FF)
private val violetDark = Color(0xFF6744D8)
private val cyan = Color(0xFF44D5FA)
private val success = Color(0xFF56D7AB)
private val panel = Color(0xFF1C2033)
private val accentGradient = Brush.horizontalGradient(listOf(Color(0xFF6437D6), Color(0xFF9C5CFF)))

@Composable
fun RishiDMVideoPane() {
    val jobs by RishiDMVideoQueue.tasks.collectAsState()
    var open by remember { mutableStateOf(true) }
    var url by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf("All") }
    val active = jobs.count { it.state in setOf("Starting", "Downloading", "Processing") }
    val complete = jobs.count { it.state == "Completed" }
    val failed = jobs.count { it.state in setOf("Failed", "Cancelled", "Interrupted") }
    val filtered = jobs.asReversed().filter {
        when (filter) {
            "Active" -> it.state in setOf("Starting", "Downloading", "Processing", "Queued")
            "Completed" -> it.state == "Completed"
            "Failed" -> it.state in setOf("Failed", "Cancelled", "Interrupted")
            else -> true
        }
    }
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 10.dp, vertical = 7.dp)
            .clip(RoundedCornerShape(13.dp))
            .background(panel)
            .border(1.dp, violet.copy(alpha = .28f), RoundedCornerShape(13.dp))
    ) {
        Row(
            Modifier.fillMaxWidth().background(
                Brush.horizontalGradient(listOf(Color(0xFF282348), Color(0xFF1B2035))))
                .clickable { open = !open }
                .padding(horizontal = 14.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("▣", color = violet, fontSize = 20.sp)
            Spacer(Modifier.width(9.dp))
            Text("Video Downloads", fontWeight = FontWeight.Bold,
                fontSize = 17.sp, color = Color.White)
            Spacer(Modifier.width(14.dp))
            Text(jobs.size.toString() + " total  •  " + active + " active  •  " +
                complete + " completed", fontSize = 12.sp, color = Color(0xFFB9BBCC))
            Spacer(Modifier.weight(1f))
            Text(if (open) "Hide  ▴" else "Show  ▾", color = violet, fontSize = 12.sp)
        }
        if (open) {
            Column(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 9.dp)) {
                Row(Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                    BasicTextField(
                        value = url,
                        onValueChange = { url = it.take(2048); error = "" },
                        singleLine = true,
                        modifier = Modifier.weight(1f).height(37.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .background(Color(0xFF12182A))
                            .border(1.dp, Color(0xFF454366), RoundedCornerShape(8.dp))
                            .padding(horizontal = 11.dp, vertical = 9.dp),
                        textStyle = TextStyle(color = Color.White, fontSize = 13.sp),
                        cursorBrush = SolidColor(cyan),
                        decorationBox = { inner ->
                            Box {
                                if (url.isBlank()) Text("Paste a video URL or use the browser extension…",
                                    fontSize = 12.sp, color = Color(0xFF858AA6),
                                    maxLines = 1)
                                inner()
                            }
                        }
                    )
                    ActionButton("Paste", onClick = {
                        runCatching {
                            url = (java.awt.Toolkit.getDefaultToolkit().systemClipboard
                                .getData(java.awt.datatransfer.DataFlavor.stringFlavor) as String)
                                .trim().take(2048)
                        }.onFailure { error = "Could not read a URL from clipboard" }
                    }, contentPadding = PaddingValues(horizontal = 11.dp, vertical = 7.dp))
                    ActionButton("＋ Add Video", onClick = {
                        if (RishiDMVideoQueue.enqueue(url.trim())) url = ""
                        else error = "Enter a valid HTTP(S) link."
                    }, backgroundColor = accentGradient,
                        contentColor = Color.White,
                        contentPadding = PaddingValues(horizontal = 13.dp, vertical = 7.dp))
                }
                if (error.isNotBlank()) Text(error, color = Color(0xFFFFB2B2),
                    fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp))
                Spacer(Modifier.height(9.dp))
                Row(Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    FilterChip("All", jobs.size, filter == "All") { filter = "All" }
                    FilterChip("Active", active, filter == "Active") { filter = "Active" }
                    FilterChip("Completed", complete, filter == "Completed") { filter = "Completed" }
                    FilterChip("Failed", failed, filter == "Failed") { filter = "Failed" }
                    Spacer(Modifier.weight(1f))
                    ActionButton("Open Folder", onClick = { RishiDMVideoQueue.openDownloadsFolder() },
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 5.dp))
                    if (complete > 0) {
                        ActionButton("Clear finished", onClick = { RishiDMVideoQueue.clearFinished() },
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 5.dp))
                    }
                }
                Spacer(Modifier.height(7.dp))
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(6.dp))
                    .background(Color(0xFF2B2C42))
                    .padding(horizontal = 11.dp, vertical = 7.dp),
                    verticalAlignment = Alignment.CenterVertically) {
                    Text("NAME / FORMAT", modifier = Modifier.weight(1f),
                        color = Color(0xFFC8CBDB), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    Text("PROGRESS", modifier = Modifier.width(108.dp),
                        color = Color(0xFFC8CBDB), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    Text("STATUS", modifier = Modifier.width(82.dp),
                        color = Color(0xFFC8CBDB), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                }
                Column(Modifier.fillMaxWidth().heightIn(max = 220.dp)
                    .verticalScroll(rememberScrollState())) {
                    if (filtered.isEmpty()) {
                        Box(Modifier.fillMaxWidth().height(55.dp),
                            contentAlignment = Alignment.Center) {
                            Text("No video downloads in this category",
                                color = Color(0xFF999DB6), fontSize = 12.sp)
                        }
                    }
                    filtered.forEach { item -> RishiDMStyledRow(item) }
                }
            }
        }
    }
}

@Composable
private fun FilterChip(label: String, count: Int, chosen: Boolean, action: () -> Unit) {
    val shape = RoundedCornerShape(7.dp)
    Row(
        Modifier.clip(shape)
            .background(if (chosen) Color(0xFF49316D) else Color(0xFF292A3A))
            .border(1.dp, if (chosen) violet else Color.Transparent, shape)
            .clickable { action() }
            .padding(horizontal = 11.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label + " (" + count + ")", color = if (chosen) Color.White else Color(0xFFB8BACA),
            fontSize = 12.sp, fontWeight = if (chosen) FontWeight.SemiBold else FontWeight.Normal)
    }
}

@Composable
private fun RishiDMStyledRow(job: RishiVideoTask) {
    var expanded by remember(job.id) { mutableStateOf(false) }
    val active = job.state in setOf("Starting", "Downloading", "Processing")
    val done = job.state == "Completed"
    val title = job.title.ifBlank {
        runCatching {
            val uri = java.net.URI(job.url)
            val slug = uri.path.trim('/').substringAfterLast('/')
            if (slug.isNotBlank() && slug != "watch") slug else uri.host ?: "Video"
        }.getOrDefault("Video")
    }
    val isShort = job.url.contains("/shorts/")
    val isInstagram = job.url.contains("instagram.com")
    val typeLabel = when {
        isInstagram -> "Instagram video"
        isShort -> "YouTube Short"
        job.url.contains("youtube.com") -> "YouTube video"
        else -> "Video"
    }
    val fileSize = if (done && job.savedPath.isNotBlank()) runCatching {
        val f = File(job.savedPath)
        if (f.isFile) String.format("%.1f MB", f.length() / 1048576.0)
        else ""
    }.getOrDefault("") else ""
    Column(Modifier.fillMaxWidth()
        .padding(top = 2.dp)
        .clip(RoundedCornerShape(6.dp))
        .background(if (expanded) Color(0xFF292840) else Color(0xFF202337))
        .clickable { expanded = !expanded }
        .padding(horizontal = 8.dp, vertical = 8.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(width = 39.dp, height = 37.dp)
                    .clip(RoundedCornerShape(7.dp))
                    .background(
                        Brush.linearGradient(listOf(Color(0xFF443084), Color(0xFF243B62)))),
                contentAlignment = Alignment.Center
            ) { Text(if (isInstagram) "◎" else "▶", color = cyan, fontSize = 17.sp) }
            Spacer(Modifier.width(8.dp))
            Column(Modifier.weight(1f)) {
                Text(title, fontSize = 13.sp, fontWeight = FontWeight.Medium,
                    color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(typeLabel + "  •  " + job.quality +
                    (if (fileSize.isNotBlank()) "  •  " + fileSize else ""),
                    fontSize = 10.sp, color = Color(0xFFA6A9C1), maxLines = 1)
            }
            Spacer(Modifier.width(10.dp))
            Column(Modifier.width(108.dp)) {
                Box(Modifier.fillMaxWidth().height(6.dp)
                    .clip(RoundedCornerShape(5.dp))
                    .background(Color(0xFF34384F))) {
                    Box(Modifier.fillMaxWidth(job.percent.coerceIn(0,100)/100f).fillMaxHeight()
                        .clip(RoundedCornerShape(5.dp))
                        .background(if (done) success else accentGradient))
                }
                Spacer(Modifier.height(3.dp))
                Text(job.percent.coerceIn(0,100).toString() + "%" +
                    (if (active && job.transferSpeed.isNotBlank()) " • " + job.transferSpeed else ""),
                    color = Color(0xFFD3D4E2), fontSize = 10.sp)
            }
            Spacer(Modifier.width(7.dp))
            Box(Modifier.width(82.dp).clip(RoundedCornerShape(6.dp))
                .background(if (done) Color(0xFF1E473F) else if (job.state == "Failed")
                    Color(0xFF512C43) else Color(0xFF3A315D))
                .padding(horizontal = 4.dp, vertical = 5.dp),
                contentAlignment = Alignment.Center) {
                Text(job.state, fontSize = 10.sp, color = if (done) success else Color.White,
                    maxLines = 1)
            }
        }
        if (expanded) {
            Spacer(Modifier.height(7.dp))
            Text(job.url.substringBefore("?").take(170),
                color = Color(0xFFA9AEC9), fontSize = 11.sp, maxLines = 1)
            Text(job.message.take(180) +
                (if (active && job.eta.isNotBlank()) "  •  ETA " + job.eta else ""),
                color = Color(0xFFCBCCE0), fontSize = 11.sp, maxLines = 2)
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp),
                modifier = Modifier.horizontalScroll(rememberScrollState())) {
                when {
                    active -> ActionButton("Cancel", onClick = { RishiDMVideoQueue.cancel(job.id) },
                        contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                    done -> {
                        if (job.savedPath.isNotBlank()) ActionButton("Open File",
                            onClick = { RishiDMVideoQueue.openFile(job.id) },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                        ActionButton("Open Folder", onClick = { RishiDMVideoQueue.openDownloadsFolder() },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                        ActionButton("Remove", onClick = { RishiDMVideoQueue.remove(job.id) },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                    }
                    else -> {
                        ActionButton(if (job.state in setOf("Failed","Interrupted","Cancelled"))
                            "Resume" else "Start", onClick = {
                                RishiDMVideoQueue.start(job.id, job.quality)
                            }, backgroundColor = accentGradient, contentColor = Color.White,
                            contentPadding = PaddingValues(horizontal = 12.dp, vertical = 5.dp))
                        ActionButton("Best", onClick = { RishiDMVideoQueue.start(job.id,"Best") },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                        ActionButton("4K", onClick = { RishiDMVideoQueue.start(job.id,"4K") },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                        ActionButton("1080p", onClick = { RishiDMVideoQueue.start(job.id,"1080p") },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                        ActionButton("Remove", onClick = { RishiDMVideoQueue.remove(job.id) },
                            contentPadding = PaddingValues(horizontal = 9.dp, vertical = 5.dp))
                    }
                }
            }
        }
    }
}
