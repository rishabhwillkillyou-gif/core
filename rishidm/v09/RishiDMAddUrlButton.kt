package com.abdownloadmanager.shared.ui.widget

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** RishiDM's primary call-to-action; the underlying download logic is unchanged. */
@Composable
fun AddUrlButton(
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(9.dp)
    Row(
        modifier.clip(shape)
            .background(Brush.horizontalGradient(
                listOf(Color(0xFF7B4AE5), Color(0xFFB36BF7))))
            .clickable(onClick = onClick)
            .height(38.dp)
            .padding(horizontal = 15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("＋  Add Download", color = Color.White,
            fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
        Spacer(Modifier.width(11.dp))
        Text("▾", color = Color(0xFFECE1FF), fontSize = 12.sp)
    }
}
