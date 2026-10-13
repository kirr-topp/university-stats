package com.example.universitystats

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.example.universitystats.notifications.AcademicNotificationScheduler
import com.example.universitystats.ui.UniversityStatsApp
import com.example.universitystats.ui.theme.UniversityStatsTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        AcademicNotificationScheduler.schedule(this)

        showApp(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showApp(intent)
    }

    private fun showApp(intent: Intent?) {
        val sharedText =
            intent?.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent?.dataString

        setContent(
            content = {
                UniversityStatsTheme(
                    content = {
                        UniversityStatsApp(
                            sharedText = sharedText
                        )
                    }
                )
            }
        )
    }
}
