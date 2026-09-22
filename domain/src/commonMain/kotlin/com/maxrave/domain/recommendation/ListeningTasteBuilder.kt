package com.maxrave.domain.recommendation

import com.maxrave.domain.data.entities.SongEntity
import com.maxrave.domain.data.entities.analytics.PlaybackEventEntity
import kotlin.math.max
import kotlin.math.min

/**
 * Builds the local taste snapshot consumed by [PersonalRadioRanker] using data SimpMusic already
 * stores, so Personal Radio needs no database migration.
 */
object ListeningTasteBuilder {
    fun build(
        eventsNewestFirst: List<PlaybackEventEntity>,
        songsById: Map<String, SongEntity>,
        recentWindow: Int = 50,
    ): PersonalRadioRanker.TasteSnapshot {
        val track = mutableMapOf<String, Double>()
        val artist = mutableMapOf<String, Double>()

        eventsNewestFirst.forEach { event ->
            val song = songsById[event.videoId]
            val completion =
                if (event.durationSecond > 0) {
                    (event.listenedSecond.toDouble() / event.durationSecond.toDouble()).coerceIn(0.0, 1.0)
                } else {
                    0.0
                }

            val eventScore =
                when {
                    event.listenedSecond <= 10L && event.durationSecond >= 30L -> -0.70
                    completion >= 0.90 -> 0.55
                    completion >= 0.70 -> 0.35
                    completion >= 0.40 -> 0.12
                    else -> -0.08
                }

            val likedBonus = if (song?.liked == true || song?.likeStatus == "LIKE") 0.60 else 0.0
            val knownDuration = song?.durationSeconds?.takeIf { it > 0 }
            val repeatBonus =
                if (knownDuration != null && ((song?.totalPlayTime ?: 0L) >= knownDuration.toLong() * 2L)) {
                    0.20
                } else {
                    0.0
                }
            val combined = clamp(eventScore + likedBonus + repeatBonus)

            track[event.videoId] = clamp((track[event.videoId] ?: 0.0) + combined * 0.55)

            song?.artistName.orEmpty().forEach { name ->
                val key = normalize(name)
                if (key.isNotBlank()) {
                    artist[key] = clamp((artist[key] ?: 0.0) + combined * 0.20)
                }
            }
        }

        return PersonalRadioRanker.TasteSnapshot(
            trackAffinity = track,
            artistAffinity = artist,
            recentVideoIds =
                eventsNewestFirst
                    .asSequence()
                    .map { it.videoId }
                    .distinct()
                    .take(recentWindow)
                    .toList(),
        )
    }

    private fun normalize(value: String): String = value.lowercase().trim().replace(Regex("\\s+"), " ")

    private fun clamp(value: Double): Double = max(-1.0, min(1.0, value))
}
