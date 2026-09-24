package com.maxrave.data.dataStore

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import com.maxrave.common.SETTINGS_FILENAME
import com.maxrave.data.io.getHomeFolderPath
import createDataStore
import java.io.File

/**
 * Process-wide desktop DataStore singleton.
 *
 * DataStore requires exactly one instance per backing file in a process. Koin already binds this
 * as a singleton, but desktop startup/reload paths can cause the provider function to be resolved
 * more than once. Keeping the JVM instance here makes that invariant unconditional.
 */
private val desktopDataStore: DataStore<Preferences> by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
    createDataStore(
        producePath = {
            val file =
                File(
                    getHomeFolderPath(listOf(".rishify")),
                    "$SETTINGS_FILENAME.preferences_pb",
                )
            file.parentFile?.mkdirs()
            file.absolutePath
        },
    )
}

actual fun createDataStoreInstance(): DataStore<Preferences> = desktopDataStore
