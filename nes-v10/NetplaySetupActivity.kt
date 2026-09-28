package com.swordfish.lemuroid.app.mobile.feature.netplay

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView
import android.widget.Toast

class NetplaySetupActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        val root =
            LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(24), dp(26), dp(24), dp(24))
            }

        root.addView(
            TextView(this).apply {
                text = "NES LAN NETPLAY"
                textSize = 26f
                gravity = Gravity.CENTER
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        root.addView(
            TextView(this).apply {
                text =
                    "Both phones run the same ROM locally.\n" +
                        "Use the same Wi-Fi and the exact same ROM on both phones."
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(0, dp(12), 0, dp(18))
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        val localIp = NetplayDiscovery.localAddress() ?: "Unavailable"

        val hostIpLabel =
            TextView(this).apply {
                text = "THIS PHONE: $localIp"
                textSize = 18f
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(8))
            }

        root.addView(
            hostIpLabel,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        root.addView(
            Button(this).apply {
                text = "COPY THIS PHONE IP"
                isEnabled = localIp != "Unavailable"
                setOnClickListener {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("NES host IP", localIp))
                    Toast.makeText(
                        this@NetplaySetupActivity,
                        "IP copied: $localIp",
                        Toast.LENGTH_SHORT,
                    ).show()
                }
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(50),
            ),
        )

        root.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(10),
            ),
        )

        root.addView(
            Button(this).apply {
                text = "HOST NEXT GAME"
                setOnClickListener {
                    NetplayLaunchConfig.armHost()
                    Toast.makeText(
                        this@NetplaySetupActivity,
                        "Host armed. Open the NES game. Player 2 can then use FIND HOST.",
                        Toast.LENGTH_LONG,
                    ).show()
                    finish()
                }
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(58),
            ),
        )

        root.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(22),
            ),
        )

        val discoveryStatus =
            TextView(this).apply {
                text = "PLAYER 2"
                textSize = 17f
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(8))
            }

        root.addView(
            discoveryStatus,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        val hostField =
            EditText(this).apply {
                hint = "Host IP (manual fallback)"
                inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                isSingleLine = true
            }

        root.addView(
            hostField,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(58),
            ),
        )

        root.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(8),
            ),
        )

        root.addView(
            Button(this).apply {
                text = "FIND HOST AUTOMATICALLY"
                setOnClickListener {
                    isEnabled = false
                    discoveryStatus.text = "Searching this Wi-Fi…"

                    Thread {
                        val found = NetplayDiscovery.discoverHost()
                        runOnUiThread {
                            isEnabled = true
                            if (found != null) {
                                hostField.setText(found)
                                discoveryStatus.text = "Host found: $found"
                                Toast.makeText(
                                    this@NetplaySetupActivity,
                                    "Host found automatically.",
                                    Toast.LENGTH_SHORT,
                                ).show()
                            } else {
                                discoveryStatus.text =
                                    "No host found yet. Start the host game first, then retry."
                            }
                        }
                    }.start()
                }
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(54),
            ),
        )

        root.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(8),
            ),
        )

        root.addView(
            Button(this).apply {
                text = "JOIN NEXT GAME"
                setOnClickListener {
                    val host = hostField.text.toString().trim()
                    if (host.isBlank()) {
                        Toast.makeText(
                            this@NetplaySetupActivity,
                            "Use FIND HOST or enter the host IP.",
                            Toast.LENGTH_SHORT,
                        ).show()
                    } else {
                        NetplayLaunchConfig.armGuest(host)
                        Toast.makeText(
                            this@NetplaySetupActivity,
                            "Guest armed. Open the exact same NES ROM as the host.",
                            Toast.LENGTH_LONG,
                        ).show()
                        finish()
                    }
                }
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(58),
            ),
        )

        root.addView(
            Space(this),
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(18),
            ),
        )

        root.addView(
            Button(this).apply {
                text = "CANCEL NETPLAY"
                setOnClickListener {
                    NetplayLaunchConfig.clear()
                    Toast.makeText(
                        this@NetplaySetupActivity,
                        "Next game will launch normally.",
                        Toast.LENGTH_SHORT,
                    ).show()
                    finish()
                }
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(50),
            ),
        )

        setContentView(root)
    }
}
