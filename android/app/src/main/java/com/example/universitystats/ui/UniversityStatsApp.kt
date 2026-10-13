package com.example.universitystats.ui

import android.Manifest
import android.content.Context
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.example.universitystats.data.*
import com.example.universitystats.notifications.AcademicNotificationScheduler
import com.example.universitystats.parser.ScheduleImporter
import com.example.universitystats.parser.ScheduleImporter.Companion.extractUrl
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.*
import java.util.Locale

private val SecondaryBg = Color(0x14000000)

@Composable
fun UniversityStatsApp(sharedText: String? = null) {
    val context = LocalContext.current
    val scheduleStore = remember { ScheduleStore(context.applicationContext) }
    val attendanceStore = remember { AttendanceStore(context.applicationContext) }
    val pointsStore = remember { PointsStore(context.applicationContext) }
    val academicStore = remember { AcademicStore(context.applicationContext) }
    val importer = remember { ScheduleImporter(context, scheduleStore) }

    var tab by remember { mutableIntStateOf(0) }
    var revision by remember { mutableIntStateOf(0) }
    var importUrl by remember { mutableStateOf(extractUrl(sharedText)) }
    var importing by remember { mutableStateOf(false) }
    var webViewUrl by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        AcademicNotificationScheduler.schedule(context)
    }

    val offlineFileLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            importing = true
            scope.launch {
                val result = importer.importOfflineFile(uri)
                importing = false
                result.onSuccess { summary ->
                    revision++
                    Toast.makeText(
                        context,
                        "Импортировано пар: ${summary.lessons}; дней: ${summary.days}",
                        Toast.LENGTH_LONG
                    ).show()
                }.onFailure { error ->
                    Toast.makeText(
                        context,
                        error.message ?: "Не удалось прочитать офлайн-страницу",
                        Toast.LENGTH_LONG
                    ).show()
                }
            }
        }
    }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= 33) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            AcademicNotificationScheduler.schedule(context)
        }
    }

    LaunchedEffect(sharedText) {
        val url = extractUrl(sharedText)
        if (url != null && url != importUrl) {
            importUrl = url
        }
    }

    LaunchedEffect(importUrl) {
        val url = importUrl ?: return@LaunchedEffect

        importUrl = null
        importing = true

        scope.launch {
            val result = importer.importUrl(url)
            importing = false

            if (result.isSuccess) {
                revision++
                Toast.makeText(
                    context,
                    "Расписание обновлено",
                    Toast.LENGTH_SHORT
                ).show()
            } else {
                webViewUrl = url
            }
        }
    }

    if (importing) {
        FullscreenProgress("Загружаю расписание…")
        return
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                val destinations = listOf(
                    Triple(Icons.Default.Home, "Главная", "Главная"),
                    Triple(Icons.Default.PieChart, "Посещаемость", "Посещ."),
                    Triple(Icons.Default.Star, "Баллы", "Баллы"),
                    Triple(Icons.Default.School, "Успеваемость", "Успев."),
                    Triple(Icons.Default.Settings, "Настройки", "Настр.")
                )
                destinations.forEachIndexed { index, (icon, description, label) ->
                    NavigationBarItem(
                        selected = tab == index,
                        onClick = { tab = index },
                        icon = { Icon(icon, contentDescription = description) },
                        label = {
                            Text(
                                text = label,
                                maxLines = 1,
                                softWrap = false,
                                overflow = TextOverflow.Clip,
                                fontSize = 9.sp,
                                letterSpacing = (-0.2).sp
                            )
                        },
                        alwaysShowLabel = true
                    )
                }
            }
        }
    ) { padding ->
        when (tab) {
            0 -> HomeScreen(
                schedule = scheduleStore.schedule,
                attendance = attendanceStore,
                modifier = Modifier.padding(padding),
                revision = revision
            )

            1 -> AttendanceScreen(
                schedule = scheduleStore.schedule,
                store = attendanceStore,
                modifier = Modifier.padding(padding),
                revision = revision
            )

            2 -> PointsScreen(
                schedule = scheduleStore.schedule,
                store = pointsStore,
                modifier = Modifier.padding(padding),
                onChanged = { revision++ }
            )

            3 -> AcademicScreen(
                schedule = scheduleStore.schedule,
                store = academicStore,
                modifier = Modifier.padding(padding),
                onChanged = { revision++ }
            )

            4 -> SettingsScreen(
                schedule = scheduleStore.schedule,
                attendance = attendanceStore,
                modifier = Modifier.padding(padding),
                onImport = { importUrl = it },
                onImportOffline = { offlineFileLauncher.launch(arrayOf("*/*")) },
                onDelete = {
                    scheduleStore.delete()
                    revision++
                },
                onAttendanceDelete = {
                    attendanceStore.deleteAll()
                    revision++
                }
            )
        }

        webViewUrl?.let { url ->
            AlertDialog(
                onDismissRequest = { webViewUrl = null },
                title = { Text("Импорт расписания") },
                text = {
                    Column(Modifier.fillMaxWidth()) {
                        Text(
                            "Сайт требует браузер. Загружаю страницу и забираю расписание автоматически.",
                            style = MaterialTheme.typography.bodySmall
                        )

                        Spacer(Modifier.height(8.dp))

                        AndroidView(
                            factory = {
                                importer.importWithWebView(url) { result ->
                                    if (result.isSuccess) {
                                        webViewUrl = null
                                        revision++
                                        Toast.makeText(
                                            context,
                                            "Расписание обновлено",
                                            Toast.LENGTH_SHORT
                                        ).show()
                                    } else {
                                        Toast.makeText(
                                            context,
                                            "Не удалось распознать расписание",
                                            Toast.LENGTH_LONG
                                        ).show()
                                    }
                                }
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(420.dp)
                        )
                    }
                },
                confirmButton = {
                    TextButton(onClick = { webViewUrl = null }) {
                        Text("Закрыть")
                    }
                }
            )
        }
    }
}


@Composable
private fun FullscreenProgress(text: String) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator()
            Spacer(Modifier.height(14.dp))
            Text(text)
        }
    }
}

@Composable
private fun HomeScreen(
    schedule: UniversitySchedule,
    attendance: AttendanceStore,
    modifier: Modifier,
    revision: Int
) {
    var selectedWeek by remember {
        mutableStateOf(ScheduleDateHelper.currentMonday())
    }

    val weeks = ScheduleDateHelper.availableWeeks(schedule.latestDate)

    Column(modifier.fillMaxSize()) {
        WeekPicker(
            weeks = weeks,
            selected = selectedWeek,
            onSelected = { selectedWeek = it }
        )

        HorizontalDivider()

        LazyColumn(
            Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp)
        ) {
            items(
                DayOfWeekRu.entries.filter { it != DayOfWeekRu.SUNDAY }
            ) { dow ->
                val date = selectedWeek.plusDays((dow.number - 1).toLong())
                val day = schedule.day(date)

                DaySection(
                    dow = dow,
                    date = date,
                    day = day,
                    attendance = attendance
                )
            }
        }
    }
}

@Composable
private fun WeekPicker(
    weeks: List<LocalDate>,
    selected: LocalDate,
    onSelected: (LocalDate) -> Unit
) {
    var open by remember { mutableStateOf(false) }

    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        Surface(
            onClick = { open = true },
            shape = RoundedCornerShape(14.dp),
            color = SecondaryBg,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        selected.displayWeekRange(),
                        fontWeight = FontWeight.SemiBold
                    )
                    Text(
                        ScheduleDateHelper.weekType(selected).title,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Icon(
                    Icons.Default.ExpandMore,
                    contentDescription = "Выбрать неделю"
                )
            }
        }

        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false }
        ) {
            weeks.forEach { week ->
                DropdownMenuItem(
                    text = {
                        Column {
                            Text(week.displayWeekRange())
                            Text(
                                ScheduleDateHelper.weekType(week).title,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    },
                    onClick = {
                        onSelected(week)
                        open = false
                    }
                )
            }
        }
    }
}

@Composable
private fun DaySection(
    dow: DayOfWeekRu,
    date: LocalDate,
    day: ScheduleDay?,
    attendance: AttendanceStore
) {
    Column(
        Modifier.padding(top = 14.dp, bottom = 4.dp)
    ) {
        Text(dow.title, fontWeight = FontWeight.Bold)

        Text(
            date.displayDayMonth(),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(Modifier.height(8.dp))

        when {
            day == null -> {
                Text(
                    "Расписание за этот день не загружено",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            day.lessons.isEmpty() -> {
                Text(
                    "Пар нет",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            else -> {
                day.lessons.forEach { lesson ->
                    LessonCard(
                        lesson = lesson,
                        date = date,
                        attendance = attendance
                    )
                }
            }
        }
    }
}

@Composable
private fun LessonCard(
    lesson: Lesson,
    date: LocalDate,
    attendance: AttendanceStore
) {
    var timer by remember { mutableStateOf(false) }
    var tick by remember { mutableLongStateOf(System.currentTimeMillis()) }

    var status by remember(lesson.id, date) {
        mutableStateOf(attendance.status(lesson, date))
    }

    LaunchedEffect(timer) {
        while (timer) {
            delay(1000)
            tick = System.currentTimeMillis()
        }
    }

    Card(
        Modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp),
        shape = RoundedCornerShape(18.dp)
    ) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text(
                        "${lesson.startTime} – ${lesson.endTime}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Text(
                        lesson.name,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Box(
                    Modifier
                        .size(28.dp)
                        .clip(CircleShape)
                        .background(SecondaryBg),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "${lesson.number}",
                        fontWeight = FontWeight.SemiBold,
                        style = MaterialTheme.typography.labelMedium
                    )
                }
            }

            Spacer(Modifier.height(10.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Tag(lesson.kind.title)
                lesson.subgroup?.let { Tag("гр.$it") }
            }

            if (lesson.teacher.isNotBlank() && lesson.teacher != "—") {
                InfoLine(Icons.Default.Person, lesson.teacher)
            }

            if (lesson.room.isNotBlank() && lesson.room != "—") {
                InfoLine(Icons.Default.Room, lesson.room)
            }

            Spacer(Modifier.height(10.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = {
                        attendance.set(
                            AttendanceStatus.ATTENDED,
                            lesson,
                            date
                        )
                        status = AttendanceStatus.ATTENDED

                        // Start the timer view immediately. Before the lesson starts it
                        // shows a countdown; the 45/5/45 lesson phases begin at startTime.
                        timer = true
                    },
                    modifier = Modifier.weight(1f),
                    colors = if (status == AttendanceStatus.ATTENDED) {
                        ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primaryContainer,
                            contentColor = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    } else {
                        ButtonDefaults.buttonColors()
                    }
                ) {
                    Icon(Icons.Default.CheckCircle, null)
                    Spacer(Modifier.width(5.dp))
                    Text("Я на паре")
                }

                OutlinedButton(
                    onClick = {
                        timer = false
                        attendance.set(
                            AttendanceStatus.ABSENT,
                            lesson,
                            date
                        )
                        status = AttendanceStatus.ABSENT
                    },
                    modifier = Modifier.weight(1f),
                    colors = if (status == AttendanceStatus.ABSENT) {
                        ButtonDefaults.outlinedButtonColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer,
                            contentColor = MaterialTheme.colorScheme.onErrorContainer
                        )
                    } else {
                        ButtonDefaults.outlinedButtonColors()
                    },
                    border = if (status == AttendanceStatus.ABSENT) {
                        BorderStroke(1.dp, MaterialTheme.colorScheme.error)
                    } else {
                        BorderStroke(1.dp, MaterialTheme.colorScheme.outline)
                    }
                ) {
                    Icon(Icons.Default.Cancel, null)
                    Spacer(Modifier.width(5.dp))
                    Text("Не был")
                }
            }

            if (timer && status == AttendanceStatus.ATTENDED) {
                TimerCard(date, lesson, tick)
            }
        }
    }
}

@Composable
private fun Tag(text: String) {
    Surface(
        shape = RoundedCornerShape(50),
        color = SecondaryBg
    ) {
        Text(
            text,
            Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun InfoLine(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(top = 5.dp)
    ) {
        Icon(
            icon,
            null,
            Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.width(8.dp))
        Text(
            text,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun TimerCard(
    date: LocalDate,
    lesson: Lesson,
    nowMs: Long
) {
    val start = ScheduleDateHelper
        .lessonDate(date, lesson.startTime)
        ?.atZone(ZoneId.systemDefault())
        ?.toInstant()
        ?.toEpochMilli()
        ?: return

    val phase = if (nowMs < start) {
        val secondsUntilStart = ((start - nowMs + 999) / 1000).toInt()
        "До начала пары" to secondsUntilStart
    } else {
        val elapsed = (nowMs - start) / 1000
        when {
            elapsed < 2700 -> "До перерыва" to (2700 - elapsed).toInt()
            elapsed < 3000 -> "Перерыв" to (3000 - elapsed).toInt()
            elapsed < 5700 -> "До конца пары" to (5700 - elapsed).toInt()
            else -> "Пара закончилась" to 0
        }
    }

    run {
        val seconds = phase.second
        val mins = seconds / 60
        val sec = seconds % 60

        Surface(
            shape = RoundedCornerShape(14.dp),
            color = SecondaryBg,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 10.dp)
        ) {
            Column(Modifier.padding(12.dp)) {
                Text(
                    phase.first,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Text(
                    "%02d:%02d".format(mins, sec),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun AttendanceScreen(
    schedule: UniversitySchedule,
    store: AttendanceStore,
    modifier: Modifier,
    revision: Int
) {
    val subjects = schedule.subjects()

    if (subjects.isEmpty()) {
        EmptyState(
            "Нет предметов",
            "Загрузите расписание.",
            Icons.Default.PieChart,
            modifier
        )
        return
    }

    var subject by remember(subjects) {
        mutableStateOf(subjects.first())
    }

    val all = store.statistics(subject)
    val lec = store.statistics(subject, LessonKind.LECTURE)
    val prac = store.statistics(subject, LessonKind.PRACTICE)
    val lab = store.statistics(subject, LessonKind.LABORATORY)

    LazyColumn(
        modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        item {
            SubjectMenu(subjects, subject) {
                subject = it
            }
        }

        item { AttendanceCard("Общая", all) }
        item { AttendanceCard("Лекции", lec) }
        item { AttendanceCard("Практики", prac) }

        if (lab.total > 0) {
            item { AttendanceCard("Лабораторные", lab) }
        }
    }
}

@Composable
private fun SubjectMenu(
    subjects: List<String>,
    selected: String,
    onSelected: (String) -> Unit
) {
    var open by remember { mutableStateOf(false) }

    Box {
        Surface(
            onClick = { open = true },
            shape = RoundedCornerShape(14.dp),
            color = SecondaryBg,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(selected, Modifier.weight(1f))
                Icon(Icons.Default.ExpandMore, null)
            }
        }

        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false }
        ) {
            subjects.forEach { subject ->
                DropdownMenuItem(
                    text = { Text(subject) },
                    onClick = {
                        onSelected(subject)
                        open = false
                    }
                )
            }
        }
    }
}

@Composable
private fun AttendanceCard(
    title: String,
    s: AttendanceStatistics
) {
    Card(
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                Text(
                    if (s.total > 0) "${s.percentage}%" else "—",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold
                )
            }

            if (s.total == 0) {
                Text(
                    "Пока нет отметок",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                LinearProgressIndicator(
                    progress = { s.attended.toFloat() / s.total },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(9.dp),
                    trackColor = SecondaryBg
                )

                Row(Modifier.fillMaxWidth()) {
                    Text(
                        "Был: ${s.attended}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.weight(1f))
                    Text(
                        "Не был: ${s.absent}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun PointsScreen(
    schedule: UniversitySchedule,
    store: PointsStore,
    modifier: Modifier,
    onChanged: () -> Unit
) {
    val subjects = schedule.subjects()

    if (subjects.isEmpty()) {
        EmptyState(
            "Нет предметов",
            "Загрузите расписание.",
            Icons.Default.Star,
            modifier
        )
        return
    }

    var subject by remember(subjects) {
        mutableStateOf(subjects.first())
    }

    var add by remember { mutableStateOf(false) }

    var threshold by remember(subject) {
        mutableStateOf(
            store.threshold(subject)
                ?.toString()
                ?.replace('.', ',')
                ?: ""
        )
    }

    val total = store.total(subject)
    val records = store.records(subject)

    LazyColumn(
        modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item {
            SubjectMenu(subjects, subject) {
                subject = it
                threshold = store.threshold(it)
                    ?.toString()
                    ?.replace('.', ',')
                    ?: ""
            }
        }

        item {
            Card(shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Text(
                        "Всего баллов",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Text(
                        fmt(total),
                        fontSize = 38.sp,
                        fontWeight = FontWeight.Bold
                    )

                    Spacer(Modifier.height(10.dp))

                    Button(onClick = { add = true }) {
                        Icon(Icons.Default.Add, null)
                        Spacer(Modifier.width(6.dp))
                        Text("Добавить баллы")
                    }
                }
            }
        }

        item {
            Card(shape = RoundedCornerShape(18.dp)) {
                Column(
                    Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("Автомат", fontWeight = FontWeight.Bold)

                    OutlinedTextField(
                        value = threshold,
                        onValueChange = { threshold = it },
                        label = { Text("Количество баллов") },
                        singleLine = true
                    )

                    Button(
                        onClick = {
                            val value = threshold
                                .replace(',', '.')
                                .toDoubleOrNull()

                            if (value == null && threshold.isNotBlank()) return@Button

                            store.setThreshold(subject, value)
                            onChanged()
                        }
                    ) {
                        Text("Сохранить количество")
                    }

                    store.threshold(subject)?.let { target ->
                        val remaining = maxOf(0.0, target - total)

                        Row {
                            Text(
                                if (remaining > 0)
                                    "Осталось набрать"
                                else
                                    "Автомат набран"
                            )

                            Spacer(Modifier.weight(1f))

                            Text(
                                fmt(remaining),
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }
                }
            }
        }

        item {
            Text("История", fontWeight = FontWeight.Bold)
        }

        if (records.isEmpty()) {
            item {
                Text(
                    "Баллов пока нет",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            items(
                records,
                key = { it.id }
            ) { record ->
                Card(
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            store.delete(record.id)
                            onChanged()
                        }
                ) {
                    Row(
                        Modifier.padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                record.kind.title,
                                fontWeight = FontWeight.SemiBold
                            )

                            Text(
                                if (record.comment.isBlank())
                                    "Без комментария"
                                else
                                    record.comment,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1
                            )
                        }

                        Text(
                            "+${fmt(record.points)}",
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }

    if (add) {
        AddPointDialog(
            subject = subject,
            store = store,
            onSaved = {
                add = false
                onChanged()
            },
            onCancel = { add = false }
        )
    }
}

@Composable
private fun AddPointDialog(
    subject: String,
    store: PointsStore,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    var kind by remember { mutableStateOf(LessonKind.PRACTICE) }
    var points by remember { mutableStateOf("") }
    var comment by remember { mutableStateOf("") }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var showDate by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text("Добавить баллы") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                SubjectKindMenu(kind) {
                    kind = it
                }

                OutlinedTextField(
                    value = points,
                    onValueChange = { points = it },
                    label = { Text("Количество") },
                    singleLine = true
                )

                OutlinedButton(
                    onClick = { showDate = true }
                ) {
                    Icon(Icons.Default.CalendarMonth, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Дата: ${date.displayDayMonth()}")
                }

                OutlinedTextField(
                    value = comment,
                    onValueChange = { comment = it },
                    label = { Text("Комментарий") },
                    minLines = 3
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val value = points
                        .replace(',', '.')
                        .toDoubleOrNull()
                        ?: return@TextButton

                    if (value >= 0) {
                        store.add(
                            subject,
                            kind,
                            value,
                            date,
                            comment
                        )
                        onSaved()
                    }
                }
            ) {
                Text("Добавить")
            }
        },
        dismissButton = {
            TextButton(onClick = onCancel) {
                Text("Отмена")
            }
        }
    )

    if (showDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = date
                .atStartOfDay(ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli()
        )

        DatePickerDialog(
            onDismissRequest = { showDate = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        state.selectedDateMillis?.let {
                            date = Instant
                                .ofEpochMilli(it)
                                .atZone(ZoneId.systemDefault())
                                .toLocalDate()
                        }

                        showDate = false
                    }
                ) {
                    Text("Готово")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDate = false }) {
                    Text("Отмена")
                }
            }
        ) {
            DatePicker(state)
        }
    }
}

@Composable
private fun SubjectKindMenu(
    selected: LessonKind,
    onSelected: (LessonKind) -> Unit
) {
    var open by remember { mutableStateOf(false) }

    Box {
        OutlinedButton(onClick = { open = true }) {
            Text(selected.title)
            Icon(Icons.Default.ExpandMore, null)
        }

        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false }
        ) {
            listOf(
                LessonKind.LECTURE,
                LessonKind.PRACTICE,
                LessonKind.LABORATORY
            ).forEach { kind ->
                DropdownMenuItem(
                    text = { Text(kind.title) },
                    onClick = {
                        onSelected(kind)
                        open = false
                    }
                )
            }
        }
    }
}

@Composable
private fun AcademicScreen(
    schedule: UniversitySchedule,
    store: AcademicStore,
    modifier: Modifier,
    onChanged: () -> Unit
) {
    val subjects = schedule.subjects()

    if (subjects.isEmpty()) {
        EmptyState(
            "Нет предметов",
            "Сначала загрузите расписание.",
            Icons.Default.School,
            modifier
        )
        return
    }

    var assessmentId by remember {
        mutableStateOf(store.assessments.first().id)
    }

    val assessment = store.assessments.first {
        it.id == assessmentId
    }

    LazyColumn(
        modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        item {
            Card(shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Text("Период", fontWeight = FontWeight.Bold)

                    AssessmentMenu(
                        all = store.assessments,
                        selected = assessment,
                        onSelected = { assessmentId = it.id }
                    )

                    Text(
                        assessment.subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        item {
            Text(
                "Оценки по предметам",
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(subjects) { subject ->
            GradeRow(
                subject = subject,
                assessment = assessment,
                store = store,
                onChanged = onChanged
            )
        }

        item {
            val completed = store.completed(assessment, subjects)

            Text(
                "Статистика",
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp)
            )

            Text(
                "Заполнено $completed / ${subjects.size}",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            if (completed < subjects.size) {
                Text(
                    "Заполните оценки по всем предметам.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        item {
            Text(
                "По предметам",
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(subjects) { subject ->
            Card(
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(Modifier.padding(14.dp)) {
                    Text(
                        subject,
                        fontWeight = FontWeight.SemiBold
                    )

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(14.dp)
                    ) {
                        store.assessments.forEach { item ->
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    if (item.type == AcademicAssessmentType.CONTROL_WEEK) {
                                        "КН-${item.number}"
                                    } else {
                                        "Сессия ${item.number}"
                                    },
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )

                                Text(
                                    store.grade(item, subject)
                                        ?.value
                                        ?.toString()
                                        ?: "—",
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AssessmentMenu(
    all: List<AcademicAssessment>,
    selected: AcademicAssessment,
    onSelected: (AcademicAssessment) -> Unit
) {
    var open by remember { mutableStateOf(false) }

    Box {
        OutlinedButton(onClick = { open = true }) {
            Text(selected.title)
            Icon(Icons.Default.ExpandMore, null)
        }

        DropdownMenu(
            expanded = open,
            onDismissRequest = { open = false }
        ) {
            all.forEach { assessment ->
                DropdownMenuItem(
                    text = { Text(assessment.title) },
                    onClick = {
                        onSelected(assessment)
                        open = false
                    }
                )
            }
        }
    }
}

@Composable
private fun GradeRow(
    subject: String,
    assessment: AcademicAssessment,
    store: AcademicStore,
    onChanged: () -> Unit
) {
    val grade = store.grade(assessment, subject)
    var open by remember { mutableStateOf(false) }

    Card(
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 3.dp)
    ) {
        Row(
            Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text(subject)

                Text(
                    if (assessment.type == AcademicAssessmentType.CONTROL_WEEK) {
                        "0 / 1 / 2"
                    } else {
                        "2 / 3 / 4 / 5"
                    },
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Box {
                OutlinedButton(onClick = { open = true }) {
                    Text(
                        grade?.value?.toString() ?: "—",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                DropdownMenu(
                    expanded = open,
                    onDismissRequest = { open = false }
                ) {
                    assessment.allowedGrades.forEach { value ->
                        DropdownMenuItem(
                            text = { Text(value.toString()) },
                            onClick = {
                                store.set(
                                    assessment,
                                    subject,
                                    value
                                )
                                open = false
                                onChanged()
                            }
                        )
                    }

                    if (grade != null) {
                        HorizontalDivider()

                        DropdownMenuItem(
                            text = {
                                Text(
                                    "Удалить оценку",
                                    color = MaterialTheme.colorScheme.error
                                )
                            },
                            onClick = {
                                store.delete(
                                    assessment,
                                    subject
                                )
                                open = false
                                onChanged()
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SettingsScreen(
    schedule: UniversitySchedule,
    attendance: AttendanceStore,
    modifier: Modifier,
    onImport: (String) -> Unit,
    onImportOffline: () -> Unit,
    onDelete: () -> Unit,
    onAttendanceDelete: () -> Unit
) {
    var importDialog by remember { mutableStateOf(false) }
    var url by remember { mutableStateOf("") }
    var deleteSchedule by remember { mutableStateOf(false) }
    var deleteAttendance by remember { mutableStateOf(false) }

    LazyColumn(
        modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item {
            Text(
                "Настройки",
                fontSize = 30.sp,
                fontWeight = FontWeight.Bold
            )
        }

        item {
            SectionCard("Расписание") {
                Button(onClick = { importDialog = true }) {
                    Icon(Icons.Default.CloudDownload, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Импортировать из сайта")
                }

                StatRow(
                    "Загружено дней",
                    schedule.days.size.toString()
                )

                schedule.earliestDate?.let {
                    StatRow("Первый день", it.displayDayMonth())
                }

                schedule.latestDate?.let {
                    StatRow("Последний день", it.displayDayMonth())
                }
            }
        }

        item {
            SectionCard("Посещаемость") {
                OutlinedButton(
                    onClick = { deleteAttendance = true }
                ) {
                    Icon(Icons.Default.PersonOff, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Удалить присутствие")
                }
            }
        }

        item {
            SectionCard("Данные") {
                Button(
                    onClick = { deleteSchedule = true },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Icon(Icons.Default.Delete, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Удалить всё расписание")
                }
            }
        }

        item {
            SectionCard("Приложение") {
                StatRow("UniversityStats", "1.0")
            }
        }
    }

    if (importDialog) {
        AlertDialog(
            onDismissRequest = { importDialog = false },
            title = { Text("Импорт расписания") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = url,
                        onValueChange = { url = it },
                        label = { Text("Ссылка на страницу") },
                        placeholder = {
                            Text("https://my.sibsutis.ru/students/schedule/…")
                        }
                    )
                    OutlinedButton(
                        onClick = {
                            importDialog = false
                            onImportOffline()
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Icon(Icons.Default.FolderOpen, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text("Выбрать офлайн-страницу Chrome")
                    }
                    Text(
                        "Поддерживаются сохранённые файлы .mhtml и .html. Сохрани именно страницу расписания, а не страницу входа.",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        extractUrl(url)?.let {
                            onImport(it)
                            importDialog = false
                        }
                    }
                ) {
                    Text("Импортировать")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { importDialog = false }
                ) {
                    Text("Отмена")
                }
            }
        )
    }

    if (deleteSchedule) {
        AlertDialog(
            onDismissRequest = { deleteSchedule = false },
            title = { Text("Удалить расписание?") },
            text = {
                Text("Будут удалены все загруженные пары.")
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        deleteSchedule = false
                        onDelete()
                    }
                ) {
                    Text(
                        "Удалить",
                        color = MaterialTheme.colorScheme.error
                    )
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { deleteSchedule = false }
                ) {
                    Text("Отмена")
                }
            }
        )
    }

    if (deleteAttendance) {
        DeleteAttendanceDialog(
            schedule = schedule,
            store = attendance,
            onDone = {
                deleteAttendance = false
                onAttendanceDelete()
            }
        )
    }
}

@Composable
private fun SectionCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        shape = RoundedCornerShape(18.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(title, fontWeight = FontWeight.Bold)
            content()
        }
    }
}

@Composable
private fun StatRow(
    title: String,
    value: String
) {
    Row(Modifier.fillMaxWidth()) {
        Text(title)
        Spacer(Modifier.weight(1f))
        Text(
            value,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun DeleteAttendanceDialog(
    schedule: UniversitySchedule,
    store: AttendanceStore,
    onDone: () -> Unit
) {
    var date by remember { mutableStateOf(LocalDate.now()) }
    var lessonId by remember { mutableStateOf("") }

    val lessons = schedule.day(date)?.lessons ?: emptyList()

    LaunchedEffect(lessons) {
        if (lessons.none { it.id == lessonId }) {
            lessonId = lessons.firstOrNull()?.id ?: ""
        }
    }

    AlertDialog(
        onDismissRequest = onDone,
        title = { Text("Удалить присутствие") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text("Дата: ${date.displayDayMonth()}")

                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Button(onClick = { date = date.minusDays(1) }) {
                        Text("‹")
                    }

                    Button(onClick = { date = date.plusDays(1) }) {
                        Text("›")
                    }
                }

                if (lessons.isEmpty()) {
                    Text(
                        "На эту дату пар нет",
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    var open by remember { mutableStateOf(false) }

                    Box {
                        OutlinedButton(
                            onClick = { open = true }
                        ) {
                            Text(
                                lessons
                                    .firstOrNull { it.id == lessonId }
                                    ?.let {
                                        "${it.number}. ${it.name}"
                                    }
                                    ?: "Выберите пару"
                            )
                        }

                        DropdownMenu(
                            expanded = open,
                            onDismissRequest = { open = false }
                        ) {
                            lessons.forEach { lesson ->
                                DropdownMenuItem(
                                    text = {
                                        Text(
                                            "${lesson.number}. " +
                                                    "${lesson.startTime} — " +
                                                    lesson.name
                                        )
                                    },
                                    onClick = {
                                        lessonId = lesson.id
                                        open = false
                                    }
                                )
                            }
                        }
                    }

                    val selected = lessons.firstOrNull {
                        it.id == lessonId
                    }

                    Text(
                        if (selected != null) {
                            when (store.status(selected, date)) {
                                AttendanceStatus.ATTENDED ->
                                    "Текущая отметка: Был"

                                AttendanceStatus.ABSENT ->
                                    "Текущая отметка: Не был"

                                null ->
                                    "Отметки нет"
                            }
                        } else {
                            ""
                        }
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    lessons
                        .firstOrNull { it.id == lessonId }
                        ?.let { store.delete(it, date) }

                    onDone()
                }
            ) {
                Text(
                    "Удалить",
                    color = MaterialTheme.colorScheme.error
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDone) {
                Text("Готово")
            }
        }
    )
}

@Composable
private fun EmptyState(
    title: String,
    text: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    modifier: Modifier
) {
    Box(
        modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                icon,
                null,
                Modifier.size(50.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(Modifier.height(10.dp))

            Text(
                title,
                fontWeight = FontWeight.Bold
            )

            Text(
                text,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private fun fmt(value: Double): String {
    return if (value % 1.0 == 0.0) {
        value.toInt().toString()
    } else {
        String.format(Locale.US, "%.1f", value)
    }
}

object ScheduleDateHelper {

    fun currentMonday(): LocalDate {
        val today = LocalDate.now()
        return today.minusDays(
            (today.dayOfWeek.value - 1).toLong()
        )
    }

    fun academicStart(date: LocalDate): LocalDate {
        return LocalDate.of(
            if (date.monthValue >= 9) date.year else date.year - 1,
            9,
            2
        )
    }

    fun weekType(date: LocalDate): WeekType {
        val start = academicStart(date)
        val firstMonday = start.minusDays(
            (start.dayOfWeek.value - 1).toLong()
        )

        val monday = date.minusDays(
            (date.dayOfWeek.value - 1).toLong()
        )

        val weeks = java.time.temporal.ChronoUnit.WEEKS.between(
            firstMonday,
            monday
        )

        return if (weeks % 2L == 0L) {
            WeekType.FIRST
        } else {
            WeekType.SECOND
        }
    }

    fun availableWeeks(latest: LocalDate?): List<LocalDate> {
        val start = academicStart(LocalDate.now())
        val firstMonday = start.minusDays(
            (start.dayOfWeek.value - 1).toLong()
        )

        val last = (latest ?: LocalDate.now())
            .coerceAtLeast(LocalDate.now())

        val lastMonday = last.minusDays(
            (last.dayOfWeek.value - 1).toLong()
        )

        val count = java.time.temporal.ChronoUnit.WEEKS.between(
            firstMonday,
            lastMonday
        ).toInt()

        return (0..count.coerceAtLeast(0)).map {
            firstMonday.plusWeeks(it.toLong())
        }
    }

    fun lessonDate(
        day: LocalDate,
        time: String
    ): LocalDateTime? {
        return runCatching {
            LocalDateTime.of(
                day,
                LocalTime.parse(time)
            )
        }.getOrNull()
    }

    fun isCurrentLesson(
        day: LocalDate,
        lesson: Lesson
    ): Boolean {
        val now = LocalDateTime.now()
        val start = lessonDate(day, lesson.startTime)
            ?: return false
        val end = lessonDate(day, lesson.endTime)
            ?: return false

        return !now.isBefore(start) && now.isBefore(end)
    }
}
