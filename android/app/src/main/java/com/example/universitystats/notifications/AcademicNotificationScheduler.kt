package com.example.universitystats.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.universitystats.MainActivity
import com.example.universitystats.R
import com.example.universitystats.data.AcademicCalendar
import java.time.LocalDate
import java.time.ZoneId

object AcademicNotificationScheduler {
    const val CHANNEL_ID = "academic"
    private const val CHANNEL_NAME = "Учёба"
    private const val ACTION_RESCHEDULE = "com.example.universitystats.RESCHEDULE_NOTIFICATIONS"

    fun schedule(context: Context) {
        val appContext = context.applicationContext
        ensureChannel(appContext)
        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val year = AcademicCalendar.academicYearStart()

        AcademicCalendar.controlWeeks(year).forEach { week ->
            scheduleOne(
                appContext,
                alarmManager,
                notificationId(week.semester, week.number, reminder = true),
                week.startDate.minusDays(7),
                "Контрольная неделя через неделю",
                "${week.title} начнётся ${week.startDate.dayOfMonth}.${week.startDate.monthValue}."
            )
            scheduleOne(
                appContext,
                alarmManager,
                notificationId(week.semester, week.number, reminder = false),
                week.startDate,
                "Началась контрольная неделя",
                "${week.title}. Это ${week.semesterWeek}-я неделя ${week.semester}-го семестра."
            )
        }
    }

    private fun notificationId(semester: Int, number: Int, reminder: Boolean): Int =
        semester * 100 + number * 2 + if (reminder) 0 else 1

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT)
            )
        }
    }

    private fun scheduleOne(
        context: Context,
        alarmManager: AlarmManager,
        id: Int,
        date: LocalDate,
        title: String,
        body: String
    ) {
        val triggerAt = date.atTime(AcademicCalendar.notificationHour, AcademicCalendar.notificationMinute)
            .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val intent = Intent(context, NotificationReceiver::class.java)
            .putExtra(NotificationReceiver.EXTRA_TITLE, title)
            .putExtra(NotificationReceiver.EXTRA_BODY, body)
            .putExtra(NotificationReceiver.EXTRA_NOTIFICATION_ID, id)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (triggerAt <= System.currentTimeMillis()) {
            alarmManager.cancel(pendingIntent)
        } else {
            // These are reminders, not time-critical alarms. Inexact alarms avoid asking
            // users for the restricted exact-alarm permission on Android 12+.
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    fun handleSystemChange(context: Context, action: String?) {
        if (action == ACTION_RESCHEDULE || action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_TIME_CHANGED || action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            schedule(context)
        }
    }

    fun rescheduleAction(): String = ACTION_RESCHEDULE
}

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != null) {
            AcademicNotificationScheduler.handleSystemChange(context, intent.action)
            return
        }

        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        val openApp = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, AcademicNotificationScheduler.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(intent.getStringExtra(EXTRA_TITLE) ?: "University Stats")
            .setContentText(intent.getStringExtra(EXTRA_BODY).orEmpty())
            .setContentIntent(openApp)
            .setAutoCancel(true)
            .build()
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0), notification)
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }
}
