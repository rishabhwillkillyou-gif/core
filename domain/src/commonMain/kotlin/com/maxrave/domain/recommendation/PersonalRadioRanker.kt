package com.maxrave.domain.recommendation

import com.maxrave.domain.data.model.browse.album.Track
import kotlin.math.abs

/**
 * Lightweight, deterministic re-ranker for a radio candidate list.
 *
 * The upstream provider remains responsible for candidate generation. This class decides which
 * short set of tracks should play next and in what order.
 */
class PersonalRadioRanker(
    private val recentWindow: Int = 50,
    private val maxPerArtist: Int = 2,
) {
    data class TasteSnapshot(
        val trackAffinity: Map<String, Double> = emptyMap(),
        val artistAffinity: Map<String, Double> = emptyMap(),
        val recentVideoIds: List<String> = emptyList(),
    )

    data class Candidate(
        val track: Track,
        val providerSimilarity: Double,
        val providerRank: Int,
    )

    data class RankedTrack(
        val track: Track,
        val score: Double,
        val reasons: Set<Reason>,
    )

    enum class Reason {
        STRONG_PROVIDER_MATCH,
        PERSONAL_TRACK_MATCH,
        PERSONAL_ARTIST_MATCH,
        SAME_ARTIST,
        SAME_ERA,
        FRESH_TRACK,
        RECENTLY_PLAYED_PENALTY,
    }

    fun rank(
        seed: Track,
        candidates: List<Candidate>,
        taste: TasteSnapshot = TasteSnapshot(),
        limit: Int = 15,
    ): List<RankedTrack> {
        if (limit <= 0) return emptyList()

        val recentIds = taste.recentVideoIds.take(recentWindow).toSet()
        val seenIds = mutableSetOf(seed.videoId)
        val seenRecordingKeys = mutableSetOf(recordingKey(seed))
        val artistCounts = mutableMapOf<String, Int>()

        val scored =
            candidates
                .asSequence()
                .filter { it.track.videoId != seed.videoId }
                .map { score(seed, it, taste, recentIds) }
                .sortedByDescending { it.score }
                .toList()

        val out = ArrayList<RankedTrack>(limit)
        for (entry in scored) {
            val track = entry.track
            val artistKey = primaryArtist(track)
            val key = recordingKey(track)

            if (!seenIds.add(track.videoId)) continue
            if (!seenRecordingKeys.add(key)) continue
            if ((artistCounts[artistKey] ?: 0) >= maxPerArtist) continue
            if (entry.score <= 0.0) continue

            artistCounts[artistKey] = (artistCounts[artistKey] ?: 0) + 1
            out += entry
            if (out.size >= limit) break
        }
        return out
    }

    private fun score(
        seed: Track,
        candidate: Candidate,
        taste: TasteSnapshot,
        recentIds: Set<String>,
    ): RankedTrack {
        val track = candidate.track
        val reasons = linkedSetOf<Reason>()
        var score = candidate.providerSimilarity.coerceIn(0.0, 1.0) * 0.58

        if (candidate.providerSimilarity >= 0.75) reasons += Reason.STRONG_PROVIDER_MATCH

        val direct = (taste.trackAffinity[track.videoId] ?: 0.0).coerceIn(-1.0, 1.0)
        score += direct * 0.17
        if (direct >= 0.30) reasons += Reason.PERSONAL_TRACK_MATCH

        val artist = primaryArtist(track)
        val artistTaste = (taste.artistAffinity[artist] ?: 0.0).coerceIn(-1.0, 1.0)
        score += artistTaste * 0.10
        if (artistTaste >= 0.30) reasons += Reason.PERSONAL_ARTIST_MATCH

        if (artist.isNotBlank() && artist == primaryArtist(seed)) {
            score += 0.045
            reasons += Reason.SAME_ARTIST
        }

        val era = eraCloseness(seed.year, track.year)
        score += era * 0.055
        if (era >= 0.75) reasons += Reason.SAME_ERA

        score += (1.0 / (1.0 + candidate.providerRank.coerceAtLeast(0))) * 0.035

        if (track.videoId in recentIds) {
            score -= 0.42
            reasons += Reason.RECENTLY_PLAYED_PENALTY
        } else {
            score += 0.08
            reasons += Reason.FRESH_TRACK
        }

        return RankedTrack(track = track, score = score, reasons = reasons)
    }

    private fun primaryArtist(track: Track): String =
        normalize(track.artists?.firstOrNull()?.name.orEmpty())

    private fun recordingKey(track: Track): String =
        normalize(track.title)
            .replace(COMMON_VERSION_WORDS, " ")
            .replace(WHITESPACE, " ")
            .trim() + "|" + primaryArtist(track)

    private fun eraCloseness(seedYear: String?, candidateYear: String?): Double {
        val a = seedYear?.toIntOrNull() ?: return 0.0
        val b = candidateYear?.toIntOrNull() ?: return 0.0
        return when (abs(a - b)) {
            in 0..2 -> 1.0
            in 3..5 -> 0.75
            in 6..10 -> 0.40
            else -> 0.0
        }
    }

    private fun normalize(value: String): String =
        value
            .lowercase()
            .replace(PARENTHETICALS, " ")
            .replace(NON_WORD, " ")
            .replace(WHITESPACE, " ")
            .trim()

    private companion object {
        val PARENTHETICALS = Regex("\\([^)]*\\)|\\[[^]]*]")
        val COMMON_VERSION_WORDS = Regex("\\b(official|video|audio|lyrics?|lyrical|hd|4k|remaster(?:ed)?)\\b")
        val NON_WORD = Regex("[^a-z0-9\\p{L}]+")
        val WHITESPACE = Regex("\\s+")
    }
}
