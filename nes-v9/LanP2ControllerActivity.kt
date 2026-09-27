package com.swordfish.lemuroid.app.mobile.feature.lan

import android.os.Bundle
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import com.swordfish.lemuroid.app.mobile.shared.compose.ui.AppTheme
import com.swordfish.lemuroid.app.shared.game.LanP2Host
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.PrintWriter
import java.net.InetSocketAddress
import java.net.Socket

class LanP2ControllerActivity : ComponentActivity() {
    private var socket: Socket? = null
    private var writer: PrintWriter? = null
    private val writeLock = Any()

    private var connectionStatus by mutableStateOf("Not connected")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContent {
            AppTheme {
                LanP2ControllerScreen(
                    status = connectionStatus,
                    onConnect = ::connectToHost,
                    onKeyEvent = ::sendKeyEventToHost,
                )
            }
        }
    }

    private fun connectToHost(host: String) {
        val cleanHost = host.trim()
        if (cleanHost.isBlank()) {
            connectionStatus = "Enter the host phone IP"
            return
        }

        connectionStatus = "Connecting…"

        lifecycleScope.launch(Dispatchers.IO) {
            closeConnection()

            try {
                val newSocket =
                    Socket().apply {
                        tcpNoDelay = true
                        connect(InetSocketAddress(cleanHost, LanP2Host.PORT), 3500)
                    }

                val newWriter = PrintWriter(newSocket.getOutputStream(), true)
                socket = newSocket
                writer = newWriter

                runOnUiThread {
                    connectionStatus = "Connected as Player 2"
                }
            } catch (e: Throwable) {
                closeConnection()
                runOnUiThread {
                    connectionStatus = "Connection failed: ${e.message ?: "unknown error"}"
                }
            }
        }
    }

    private fun sendKeyEventToHost(action: Int, keyCode: Int) {
        val currentWriter = writer ?: return
        synchronized(writeLock) {
            currentWriter.println("K,$action,$keyCode")
            currentWriter.flush()
        }
    }

    private fun closeConnection() {
        runCatching { writer?.close() }
        runCatching { socket?.close() }
        writer = null
        socket = null
    }

    override fun onDestroy() {
        closeConnection()
        super.onDestroy()
    }
}

@Composable
private fun LanP2ControllerScreen(
    status: String,
    onConnect: (String) -> Unit,
    onKeyEvent: (Int, Int) -> Unit,
) {
    var hostIp by rememberSaveable { mutableStateOf("") }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "LAN PLAYER 2",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = "Same Wi‑Fi · Host game stays on Player 1 phone",
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.padding(top = 6.dp, bottom = 18.dp),
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            OutlinedTextField(
                value = hostIp,
                onValueChange = { hostIp = it },
                label = { Text("Host IP") },
                placeholder = { Text("192.168.1.20") },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Button(onClick = { onConnect(hostIp) }) {
                Text("CONNECT")
            }
        }

        Text(
            text = status,
            modifier = Modifier.padding(vertical = 14.dp),
            style = MaterialTheme.typography.bodyLarge,
        )

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            DPad(onKeyEvent)
            ActionPad(onKeyEvent)
        }

        Spacer(modifier = Modifier.height(26.dp))

        Row(
            horizontalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            HoldButton(
                label = "SELECT",
                keyCode = KeyEvent.KEYCODE_BUTTON_SELECT,
                width = 108.dp,
                height = 56.dp,
                shape = RoundedCornerShape(18.dp),
                onKeyEvent = onKeyEvent,
            )
            HoldButton(
                label = "START",
                keyCode = KeyEvent.KEYCODE_BUTTON_START,
                width = 108.dp,
                height = 56.dp,
                shape = RoundedCornerShape(18.dp),
                onKeyEvent = onKeyEvent,
            )
        }
    }
}

@Composable
private fun DPad(onKeyEvent: (Int, Int) -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        HoldButton("▲", KeyEvent.KEYCODE_DPAD_UP, onKeyEvent = onKeyEvent)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            HoldButton("◀", KeyEvent.KEYCODE_DPAD_LEFT, onKeyEvent = onKeyEvent)
            Spacer(modifier = Modifier.size(70.dp))
            HoldButton("▶", KeyEvent.KEYCODE_DPAD_RIGHT, onKeyEvent = onKeyEvent)
        }
        HoldButton("▼", KeyEvent.KEYCODE_DPAD_DOWN, onKeyEvent = onKeyEvent)
    }
}

@Composable
private fun ActionPad(onKeyEvent: (Int, Int) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            HoldButton("B", KeyEvent.KEYCODE_BUTTON_B, onKeyEvent = onKeyEvent)
            HoldButton("TB", KeyEvent.KEYCODE_BUTTON_Y, onKeyEvent = onKeyEvent)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            HoldButton("A", KeyEvent.KEYCODE_BUTTON_A, onKeyEvent = onKeyEvent)
            HoldButton("TA", KeyEvent.KEYCODE_BUTTON_X, onKeyEvent = onKeyEvent)
        }
    }
}

@Composable
private fun HoldButton(
    label: String,
    keyCode: Int,
    width: androidx.compose.ui.unit.Dp = 70.dp,
    height: androidx.compose.ui.unit.Dp = 70.dp,
    shape: androidx.compose.ui.graphics.Shape = CircleShape,
    onKeyEvent: (Int, Int) -> Unit,
) {
    Box(
        modifier =
            Modifier
                .width(width)
                .height(height)
                .background(Color(0xFF252822), shape)
                .pointerInput(keyCode) {
                    detectTapGestures(
                        onPress = {
                            onKeyEvent(KeyEvent.ACTION_DOWN, keyCode)
                            tryAwaitRelease()
                            onKeyEvent(KeyEvent.ACTION_UP, keyCode)
                        },
                    )
                },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = Color.White,
            fontWeight = FontWeight.Bold,
        )
    }
}
