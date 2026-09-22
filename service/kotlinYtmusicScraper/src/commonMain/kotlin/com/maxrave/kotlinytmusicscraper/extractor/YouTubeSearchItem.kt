package com.maxrave.kotlinytmusicscraper.extractor

/**
 * Platform-neutral subset of a standard YouTube search result.
 */
data class YouTubeSearchItem(
    val videoId: String,
    val title: String,
    val uploaderName: String?,
    val durationSeconds: Int?,
    val thumbnailUrl: String?,
    val viewCount: Long?,
)
