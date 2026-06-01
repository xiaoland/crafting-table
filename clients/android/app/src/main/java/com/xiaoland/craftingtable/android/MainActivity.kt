package com.xiaoland.craftingtable.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.xiaoland.craftingtable.android.codexremote.CodexRemoteApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            CodexRemoteApp()
        }
    }
}
