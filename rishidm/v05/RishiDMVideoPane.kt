package com.abdownloadmanager.desktop.pages.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.abdownloadmanager.desktop.media.RishiDMVideoQueue
import com.abdownloadmanager.shared.ui.widget.ActionButton
import com.abdownloadmanager.shared.ui.widget.Text
import com.abdownloadmanager.shared.util.ui.myColors

/** Inline video queue in the main application, independent from HTTP transfers. */
@Composable
fun RishiDMVideoPane() {
    val jobs by RishiDMVideoQueue.tasks.collectAsState()
    if (jobs.isEmpty()) return
    Column(
        Modifier.fillMaxWidth().heightIn(max = 245.dp)
            .background(myColors.surface.copy(alpha = 0.9f))
            .verticalScroll(rememberScrollState())
            .padding(vertical = 8.dp, horizontal = 12.dp)
    ) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Video downloads", fontWeight = FontWeight.Bold)
            Spacer(Modifier.width(12.dp))
            Text("RishiDM • yt-dlp + FFmpeg • Downloads folder",
                color = myColors.onBackground.copy(alpha = 0.65f))
        }
        Spacer(Modifier.height(6.dp))
        jobs.asReversed().forEach { job ->
            Column(
                Modifier.fillMaxWidth().padding(bottom = 5.dp)
                    .border(1.dp, myColors.onBackground.copy(alpha = 0.16f))
                    .padding(8.dp)
            ) {
                Text(
                    job.url.substringBefore("?").take(150),
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    fontWeight = FontWeight.Medium
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    job.state + " • " + job.quality + " • " + job.percent +
                        "% — " + job.message.take(140),
                    maxLines = 2, overflow = TextOverflow.Ellipsis
                )
                Spacer(Modifier.height(4.dp))
                Box(Modifier.fillMaxWidth().height(4.dp)
                    .background(myColors.onBackground.copy(alpha = 0.15f))) {
                    Box(Modifier.fillMaxWidth(job.percent.coerceIn(0, 100) / 100f)
                        .fillMaxHeight().background(myColors.primary))
                }
                Spacer(Modifier.height(4.dp))
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val active = job.state in listOf("Starting", "Downloading", "Processing")
                    if (!active) {
                        ActionButton("Best", onClick = { RishiDMVideoQueue.start(job.id, "Best") })
                        ActionButton("4K", onClick = { RishiDMVideoQueue.start(job.id, "4K") })
                        ActionButton("1080p", onClick = { RishiDMVideoQueue.start(job.id, "1080p") })
                        ActionButton("720p", onClick = { RishiDMVideoQueue.start(job.id, "720p") })
                        ActionButton(
                            if (job.state in listOf("Interrupted", "Failed", "Cancelled")) "Resume" else "Start",
                            onClick = { RishiDMVideoQueue.start(job.id, job.quality) })
                        ActionButton("Remove", onClick = { RishiDMVideoQueue.remove(job.id) })
                    } else {
                        ActionButton("Cancel", onClick = { RishiDMVideoQueue.cancel(job.id) })
                    }
                }
            }
        }
    }
}
