package com.abdownloadmanager.desktop.pages.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.abdownloadmanager.desktop.media.RishiDMVideoQueue
import com.abdownloadmanager.desktop.media.RishiVideoTask
import com.abdownloadmanager.shared.ui.widget.ActionButton
import com.abdownloadmanager.shared.ui.widget.Text
import com.abdownloadmanager.shared.util.ui.myColors

/** A compact, expandable media dashboard above the regular download list. */
@Composable
fun RishiDMVideoPane() {
    val jobs by RishiDMVideoQueue.tasks.collectAsState()
    var expanded by remember { mutableStateOf(true) }
    var inputUrl by remember { mutableStateOf("") }
    var inputError by remember { mutableStateOf("") }
    val active = jobs.count { it.state in setOf("Starting", "Downloading", "Processing") }
    val finished = jobs.count { it.state == "Completed" }
    Column(
        Modifier.fillMaxWidth().background(myColors.surface.copy(alpha = .92f))
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Row(Modifier.fillMaxWidth().clickable { expanded = !expanded },
            verticalAlignment = Alignment.CenterVertically) {
            Text(if (expanded) "▾ Media downloads" else "▸ Media downloads",
                fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(12.dp))
            Text(jobs.size.toString() + " total • " + active +
                " active • " + finished + " finished",
                color = myColors.onBackground.copy(alpha = .65f))
            Spacer(Modifier.weight(1f))
            Text(if (expanded) "Collapse" else "Expand", color = myColors.primary)
        }
        if (expanded) {
            Spacer(Modifier.height(6.dp))
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                BasicTextField(
                    value = inputUrl,
                    onValueChange = { inputUrl = it.take(2048); inputError = "" },
                    modifier = Modifier.weight(1f).height(34.dp)
                        .border(1.dp, myColors.onBackground.copy(alpha = .25f))
                        .padding(horizontal = 8.dp, vertical = 7.dp),
                    singleLine = true,
                    textStyle = TextStyle(color = myColors.onBackground),
                    decorationBox = { inner ->
                        Box {
                            if (inputUrl.isBlank())
                                Text("Paste video URL here…",
                                    color = myColors.onBackground.copy(alpha = .50f), maxLines = 1)
                            inner()
                        }
                    }
                )
                ActionButton("Add Video", onClick = {
                    if (RishiDMVideoQueue.enqueue(inputUrl.trim())) inputUrl = ""
                    else inputError = "Please enter a valid HTTP(S) video URL."
                })
                ActionButton("Paste", onClick = {
                    runCatching {
                        inputUrl = (java.awt.Toolkit.getDefaultToolkit().systemClipboard
                            .getData(java.awt.datatransfer.DataFlavor.stringFlavor) as String).trim()
                    }.onFailure { inputError = "Clipboard is empty or inaccessible." }
                })
            }
            if (inputError.isNotBlank()) Text(inputError)
            Spacer(Modifier.height(5.dp))
            Row(verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ActionButton("Open Downloads", onClick = { RishiDMVideoQueue.openDownloadsFolder() })
                if (finished > 0) ActionButton("Clear finished",
                    onClick = { RishiDMVideoQueue.clearFinished() })
                Text("Click a task to expand its details",
                    color = myColors.onBackground.copy(alpha = .55f), maxLines = 1)
            }
            Spacer(Modifier.height(4.dp))
            Column(Modifier.fillMaxWidth().heightIn(max = 165.dp)
                .verticalScroll(rememberScrollState())) {
                if (jobs.isEmpty()) Text("No video jobs yet. Add a link or use your browser.")
                jobs.asReversed().forEach { job -> RishiDMVideoRow(job) }
            }
        }
    }
}

@Composable
private fun RishiDMVideoRow(job: RishiVideoTask) {
    var details by remember(job.id) { mutableStateOf(false) }
    val active = job.state in setOf("Starting", "Downloading", "Processing")
    val done = job.state == "Completed"
    val title = job.title.ifBlank {
        runCatching {
            val uri = java.net.URI(job.url)
            uri.path.trim('/').substringAfterLast('/').takeIf { it.isNotBlank() && it != "watch" }
                ?: (uri.host ?: "Media")
        }.getOrDefault("Media")
    }
    Column(Modifier.fillMaxWidth().padding(bottom = 3.dp)
        .border(1.dp, myColors.onBackground.copy(alpha = .15f))
        .padding(horizontal = 8.dp, vertical = 5.dp)) {
        Row(Modifier.fillMaxWidth().clickable { details = !details },
            verticalAlignment = Alignment.CenterVertically) {
            Text(if (details) "▾ " else "▸ ")
            Text(title, fontWeight = FontWeight.Medium, maxLines = 1,
                overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Spacer(Modifier.width(6.dp))
            Text(job.percent.coerceIn(0, 100).toString() + "% • " + job.state,
                color = if (done) myColors.primary else myColors.onBackground.copy(alpha = .75f))
        }
        if (active || details) {
            Spacer(Modifier.height(4.dp))
            Box(Modifier.fillMaxWidth().height(3.dp)
                .background(myColors.onBackground.copy(alpha = .15f))) {
                Box(Modifier.fillMaxWidth(job.percent.coerceIn(0,100) / 100f)
                    .fillMaxHeight().background(myColors.primary))
            }
        }
        if (details) {
            Spacer(Modifier.height(5.dp))
            Text(job.url.substringBefore("?").take(160), maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = myColors.onBackground.copy(alpha = .6f))
            val info = job.quality + " • " + job.message.take(150) +
                (if (job.transferSpeed.isNotBlank()) " • " + job.transferSpeed else "") +
                (if (job.eta.isNotBlank()) " • ETA " + job.eta else "")
            Text(info, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(4.dp))
            Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                when {
                    active -> ActionButton("Stop", onClick = { RishiDMVideoQueue.cancel(job.id) })
                    done -> {
                        if (job.savedPath.isNotBlank())
                            ActionButton("Open File", onClick = { RishiDMVideoQueue.openFile(job.id) })
                        ActionButton("Open Folder", onClick = { RishiDMVideoQueue.openDownloadsFolder() })
                        ActionButton("Remove", onClick = { RishiDMVideoQueue.remove(job.id) })
                    }
                    else -> {
                        val action = if (job.state in setOf("Failed", "Cancelled", "Interrupted"))
                            "Resume" else "Download"
                        ActionButton(action, onClick = { RishiDMVideoQueue.start(job.id, job.quality) })
                        ActionButton("Best", onClick = { RishiDMVideoQueue.start(job.id, "Best") })
                        ActionButton("4K", onClick = { RishiDMVideoQueue.start(job.id, "4K") })
                        ActionButton("1080p", onClick = { RishiDMVideoQueue.start(job.id, "1080p") })
                        ActionButton("Remove", onClick = { RishiDMVideoQueue.remove(job.id) })
                    }
                }
            }
        }
    }
}
