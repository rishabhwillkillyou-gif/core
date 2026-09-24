package com.maxrave.data.dataStore

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.PreferencesSerializer
import com.maxrave.common.SETTINGS_FILENAME
import com.maxrave.data.io.getHomeFolderPath
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okio.FileSystem
import okio.Path.Companion.toPath
import okio.buffer

/**
 * Windows/JVM preferences store.
 *
 * Upstream SimpMusic can crash on Windows inside AndroidX DataStore's FileStorageConnection while
 * renaming settings.preferences_pb.tmp over settings.preferences_pb. The failure has been reported
 * upstream and reproduces even with a single app process.
 *
 * RishiFy keeps the exact same Preferences protobuf format by using Google's public
 * [PreferencesSerializer], but owns the small amount of desktop file IO itself:
 *  - one process-wide instance;
 *  - all reads/writes serialized by one Mutex;
 *  - temp-file replacement retried on transient Windows locks;
 *  - direct overwrite fallback if Windows refuses the final rename.
 *
 * Android/iOS continue to use the normal DataStore implementation.
 */
private class WindowsSafePreferencesDataStore(
    private val file: File,
) : DataStore<Preferences> {
    private val mutex = Mutex()
    private val state = MutableStateFlow(PreferencesSerializer.defaultValue)

    @Volatile
    private var loaded = false

    override val data: Flow<Preferences> =
        flow {
            ensureLoaded()
            emitAll(state)
        }

    override suspend fun updateData(transform: suspend (t: Preferences) -> Preferences): Preferences =
        mutex.withLock {
            loadLocked()
            val updated = transform(state.value)
            persistLocked(updated)
            state.value = updated
            updated
        }

    private suspend fun ensureLoaded() {
        if (loaded) return
        mutex.withLock { loadLocked() }
    }

    private suspend fun loadLocked() {
        if (loaded) return

        val loadedValue =
            withContext(Dispatchers.IO) {
                if (!file.exists() || file.length() == 0L) {
                    PreferencesSerializer.defaultValue
                } else {
                    try {
                        FileSystem.SYSTEM
                            .source(file.absolutePath.toPath())
                            .buffer()
                            .use { source ->
                                PreferencesSerializer.readFrom(source)
                            }
                    } catch (e: Exception) {
                        // Do not repeatedly crash on a partially written/corrupt file. Preserve it
                        // beside the live file for inspection and start from defaults.
                        runCatching {
                            val backup =
                                File(
                                    file.parentFile,
                                    file.name + ".corrupt-" + System.currentTimeMillis(),
                                )
                            Files.copy(
                                file.toPath(),
                                backup.toPath(),
                                StandardCopyOption.REPLACE_EXISTING,
                            )
                        }
                        PreferencesSerializer.defaultValue
                    }
                }
            }

        state.value = loadedValue
        loaded = true
    }

    private suspend fun persistLocked(value: Preferences) {
        withContext(Dispatchers.IO) {
            file.parentFile?.mkdirs()

            val tmp =
                File(
                    file.parentFile,
                    file.name + ".rishify-" + ProcessHandle.current().pid() + ".tmp",
                )

            FileSystem.SYSTEM
                .sink(tmp.absolutePath.toPath())
                .buffer()
                .use { sink ->
                    PreferencesSerializer.writeTo(value, sink)
                    sink.flush()
                }

            var moved = false
            var lastFailure: Exception? = null

            repeat(8) { attempt ->
                if (moved) return@repeat
                try {
                    try {
                        Files.move(
                            tmp.toPath(),
                            file.toPath(),
                            StandardCopyOption.ATOMIC_MOVE,
                            StandardCopyOption.REPLACE_EXISTING,
                        )
                    } catch (_: Exception) {
                        Files.move(
                            tmp.toPath(),
                            file.toPath(),
                            StandardCopyOption.REPLACE_EXISTING,
                        )
                    }
                    moved = true
                } catch (e: Exception) {
                    lastFailure = e
                    // Indexers/AV can hold a Windows file briefly after close.
                    Thread.sleep(40L * (attempt + 1))
                }
            }

            if (!moved) {
                // Last-resort Windows path: avoid rename entirely. Since every writer in RishiFy
                // is serialized by [mutex], a direct replacement is safe from app-level races.
                try {
                    FileSystem.SYSTEM
                        .sink(file.absolutePath.toPath())
                        .buffer()
                        .use { sink ->
                            PreferencesSerializer.writeTo(value, sink)
                            sink.flush()
                        }
                    tmp.delete()
                } catch (directFailure: Exception) {
                    directFailure.addSuppressed(lastFailure)
                    throw directFailure
                }
            }
        }
    }
}

private val desktopDataStore: DataStore<Preferences> by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
    val file =
        File(
            getHomeFolderPath(listOf(".rishify")),
            "$SETTINGS_FILENAME.preferences_pb",
        )
    file.parentFile?.mkdirs()
    WindowsSafePreferencesDataStore(file)
}

actual fun createDataStoreInstance(): DataStore<Preferences> = desktopDataStore
