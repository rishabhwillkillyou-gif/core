package com.swordfish.lemuroid.app.mobile.feature.netplay

import android.app.Activity
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
                setPadding(dp(24), dp(30), dp(24), dp(24))
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
                        "1. Put both phones on the same Wi-Fi.\n" +
                        "2. Host arms HOST, then opens the game.\n" +
                        "3. Guest enters the host IP, arms JOIN, then opens the same ROM."
                textSize = 16f
                gravity = Gravity.CENTER
                setPadding(0, dp(16), 0, dp(22))
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        root.addView(
            Button(this).apply {
                text = "HOST NEXT GAME"
                setOnClickListener {
                    NetplayLaunchConfig.armHost()
                    Toast.makeText(
                        this@NetplaySetupActivity,
                        "Host armed. Now open the NES game you want to play.",
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
                dp(24),
            ),
        )

        val hostField =
            EditText(this).apply {
                hint = "Host IP, e.g. 192.168.1.23"
                inputType = InputType.TYPE_CLASS_PHONE
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
                dp(10),
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
                            "Enter the host phone IP first.",
                            Toast.LENGTH_SHORT,
                        ).show()
                    } else {
                        NetplayLaunchConfig.armGuest(host)
                        Toast.makeText(
                            this@NetplaySetupActivity,
                            "Guest armed. Now open the same NES ROM as the host.",
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
                dp(24),
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
                dp(54),
            ),
        )

        setContentView(root)
    }
}
