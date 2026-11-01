package com.abdownloadmanager.resources.icons

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.path
import androidx.compose.ui.unit.dp

/** RishiDM's original R/download-arrow mark, for main window and system tray. */
val ABDMIcons.AppIcon: ImageVector
    get() {
        if (_AppIcon != null) return _AppIcon!!
        _AppIcon = ImageVector.Builder(
            name = "RishiDM App Icon",
            defaultWidth = 48.dp, defaultHeight = 48.dp,
            viewportWidth = 512f, viewportHeight = 512f
        ).apply {
            path(fill = SolidColor(Color(0xFF151B39))) {
                moveTo(126f, 23f)
                lineTo(386f, 23f)
                curveTo(452f, 23f, 488f, 59f, 488f, 125f)
                lineTo(488f, 385f)
                curveTo(488f, 453f, 451f, 487f, 386f, 487f)
                lineTo(126f, 487f)
                curveTo(57f, 487f, 24f, 451f, 24f, 385f)
                lineTo(24f, 125f)
                curveTo(24f, 57f, 61f, 23f, 126f, 23f)
                close()
            }
            path(
                fill = Brush.linearGradient(
                    colors = listOf(Color.White, Color(0xFFA7AAE5)),
                    start = Offset(130f, 125f),
                    end = Offset(360f, 375f)
                ),
                pathFillType = PathFillType.EvenOdd
            ) {
                moveTo(128f, 113f)
                lineTo(248f, 113f)
                curveTo(325f, 113f, 356f, 152f, 356f, 210f)
                curveTo(356f, 250f, 334f, 280f, 302f, 293f)
                lineTo(360f, 376f)
                lineTo(267f, 376f)
                lineTo(215f, 298f)
                lineTo(206f, 298f)
                lineTo(206f, 376f)
                lineTo(128f, 376f)
                close()
                moveTo(206f, 178f)
                lineTo(242f, 178f)
                curveTo(265f, 178f, 281f, 186f, 281f, 208f)
                curveTo(281f, 230f, 265f, 238f, 242f, 238f)
                lineTo(206f, 238f)
                close()
            }
            path(
                fill = Brush.linearGradient(
                    colors = listOf(Color(0xFF48E2FF), Color(0xFFCF4BFF)),
                    start = Offset(348f, 275f),
                    end = Offset(408f, 409f)
                )
            ) {
                moveTo(348f, 267f)
                lineTo(396f, 267f)
                lineTo(396f, 339f)
                lineTo(429f, 339f)
                lineTo(372f, 415f)
                lineTo(316f, 339f)
                lineTo(348f, 339f)
                close()
            }
        }.build()
        return _AppIcon!!
    }

@Suppress("ObjectPropertyName")
private var _AppIcon: ImageVector? = null
