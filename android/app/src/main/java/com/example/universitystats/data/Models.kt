package com.example.universitystats.data

import java.time.*
import java.time.format.DateTimeFormatter
import java.util.Locale

private val RU = Locale("ru", "RU")
private val DATE_FMT = DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.US)
private val TIME_FMT = DateTimeFormatter.ofPattern("HH:mm")

enum class LessonKind(val title: String) { LECTURE("Лекция"), PRACTICE("Практика"), LABORATORY("Лабораторная"), OTHER("Занятие") }

enum class WeekType(val title: String) { FIRST("Первая неделя"), SECOND("Вторая неделя") }

enum class DayOfWeekRu(val number: Int, val title: String, val shortTitle: String) {
    MONDAY(1,"Понедельник","Пн"), TUESDAY(2,"Вторник","Вт"), WEDNESDAY(3,"Среда","Ср"), THURSDAY(4,"Четверг","Чт"), FRIDAY(5,"Пятница","Пт"), SATURDAY(6,"Суббота","Сб"), SUNDAY(7,"Воскресенье","Вс");
    companion object { fun fromJava(d: java.time.DayOfWeek) = entries[d.value-1] }
}

data class Lesson(
    val id: String,
    val number: Int,
    val name: String,
    val teacher: String,
    val room: String,
    val startTime: String,
    val endTime: String,
    val subgroup: Int? = null,
    val group: String? = null,
    val kind: LessonKind = LessonKind.OTHER
) {
    companion object {
        fun create(number:Int,name:String,teacher:String,room:String,startTime:String,endTime:String,subgroup:Int?,group:String?,kind:LessonKind): Lesson {
            val id = listOf(name,number,startTime,endTime,subgroup ?: 0,group ?: "",kind.name).joinToString("|")
            return Lesson(id,number,name,teacher,room,startTime,endTime,subgroup,group,kind)
        }
    }
}

data class ScheduleDay(val date: String, val lessons: List<Lesson>)

data class UniversitySchedule(val days: List<ScheduleDay> = emptyList()) {
    val latestDate: LocalDate? get() = days.mapNotNull { runCatching { LocalDate.parse(it.date, DATE_FMT) }.getOrNull() }.maxOrNull()
    val earliestDate: LocalDate? get() = days.mapNotNull { runCatching { LocalDate.parse(it.date, DATE_FMT) }.getOrNull() }.minOrNull()
    fun day(date: LocalDate) = days.firstOrNull { it.date == date.format(DATE_FMT) }
    fun subjects() = days.flatMap { it.lessons }.map { it.name }.toSet().sorted()
    fun merging(imported: UniversitySchedule): UniversitySchedule {
        val map = days.associateBy { it.date }.toMutableMap()
        imported.days.forEach { map[it.date] = it }
        return UniversitySchedule(map.values.sortedBy { it.date })
    }
}

fun LocalDate.key() = format(DATE_FMT)
fun LocalDate.displayDayMonth(): String = format(DateTimeFormatter.ofPattern("d MMMM", RU))
fun LocalDate.displayWeekRange(): String = "${format(DateTimeFormatter.ofPattern("d MMMM", RU))} – ${plusDays(6).format(DateTimeFormatter.ofPattern("d MMMM", RU))}"
fun String.toLocalTimeSafe(): LocalTime? = runCatching { LocalTime.parse(this, TIME_FMT) }.getOrNull()
fun LocalDateTime.millis(): Long = atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()

// Attendance

enum class AttendanceStatus { ATTENDED, ABSENT }
data class AttendanceRecord(val id:String,val lessonId:String,val subject:String,val kind:LessonKind,val date:String,val status:AttendanceStatus)
data class AttendanceStatistics(val total:Int,val attended:Int,val absent:Int) { val percentage:Int get()=if(total==0)0 else kotlin.math.round(attended.toDouble()/total*100).toInt() }

data class PointRecord(val id:String,val subject:String,val kind:LessonKind,val points:Double,val date:String,val comment:String)

enum class AcademicAssessmentType { CONTROL_WEEK, SESSION }
data class AcademicAssessment(val type:AcademicAssessmentType,val number:Int,val id:String,val title:String,val subtitle:String) { val allowedGrades:List<Int> get()=if(type==AcademicAssessmentType.CONTROL_WEEK) listOf(0,1,2) else listOf(2,3,4,5) }
data class AcademicGrade(val id:String,val assessmentId:String,val subject:String,val value:Int,val date:Long)

data class ControlWeek(val semester:Int,val number:Int,val semesterWeek:Int,val startDate:LocalDate) { val id="control-$number"; val title="Контрольная неделя $number"; val shortTitle="КН-$number" }
data class AcademicSession(val number:Int,val title:String,val period:String)
