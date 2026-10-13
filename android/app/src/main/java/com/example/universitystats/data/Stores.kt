package com.example.universitystats.data

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.util.UUID

private const val PREFS = "university_stats"
private fun Context.prefs(): SharedPreferences = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

class ScheduleStore(context: Context) {
    private val p=context.prefs(); private val key="schedule_v2"
    var schedule: UniversitySchedule = load(); private set
    private fun load(): UniversitySchedule {
        val raw=p.getString(key,null) ?: return UniversitySchedule()
        return runCatching { JsonStore.decodeSchedule(JSONArray(raw)) }.getOrElse { UniversitySchedule() }
    }
    fun merge(imported:UniversitySchedule){ schedule=schedule.merging(imported); p.edit().putString(key,JsonStore.encodeSchedule(schedule).toString()).apply() }
    fun delete(){ schedule=UniversitySchedule(); p.edit().remove(key).apply() }
}

class AttendanceStore(context:Context){
    private val p=context.prefs(); private val key="attendance_v2"; private val records=mutableMapOf<String,AttendanceRecord>()
    init { load() }
    private fun k(lesson:Lesson,date:LocalDate)="${date.key()}|${lesson.id}"
    fun status(lesson:Lesson,date:LocalDate)=records[k(lesson,date)]?.status
    fun set(status:AttendanceStatus,lesson:Lesson,date:LocalDate){ val r=AttendanceRecord(k(lesson,date),lesson.id,lesson.name,lesson.kind,date.key(),status); records[r.id]=r; save() }
    fun delete(lesson:Lesson,date:LocalDate){records.remove(k(lesson,date));save()}
    fun deleteAll(){records.clear();save()}
    fun statistics(subject:String,kind:LessonKind?=null):AttendanceStatistics{val x=records.values.filter{it.subject==subject&&(kind==null||it.kind==kind)};return AttendanceStatistics(x.size,x.count{it.status==AttendanceStatus.ATTENDED},x.count{it.status==AttendanceStatus.ABSENT})}
    private fun save(){p.edit().putString(key,JsonStore.encodeAttendance(records.values).toString()).apply()}
    private fun load(){runCatching{JsonStore.decodeAttendance(JSONArray(p.getString(key,"[]"))).forEach{records[it.id]=it}}}
}

class PointsStore(context:Context){
    private val p=context.prefs(); private val records=mutableListOf<PointRecord>(); private val conditions=mutableMapOf<String,String>(); private val thresholds=mutableMapOf<String,Double>()
    init{load()}
    fun records(subject:String)=records.filter{it.subject==subject}.sortedByDescending{it.date}
    fun add(subject:String,kind:LessonKind,points:Double,date:LocalDate,comment:String){records += PointRecord(UUID.randomUUID().toString(),subject,kind,points,date.key(),comment.trim());save()}
    fun delete(id:String){records.removeAll{it.id==id};save()}
    fun total(subject:String)=records.filter{it.subject==subject}.sumOf{it.points}
    fun condition(subject:String)=conditions[subject]?:""
    fun setCondition(subject:String,v:String){if(v.trim().isEmpty())conditions.remove(subject) else conditions[subject]=v.trim();save()}
    fun threshold(subject:String)=thresholds[subject]
    fun setThreshold(subject:String,v:Double?){if(v==null||v<0)thresholds.remove(subject) else thresholds[subject]=v;save()}
    private fun save(){
        val c=JSONObject();conditions.forEach{(k,v)->c.put(k,v)}
        val t=JSONObject();thresholds.forEach{(k,v)->t.put(k,v)}
        p.edit().putString("points",JsonStore.encodePoints(records).toString()).putString("conditions",c.toString()).putString("thresholds",t.toString()).apply()
    }
    private fun load(){runCatching{JsonStore.decodePoints(JSONArray(p.getString("points","[]"))).also{records.addAll(it)}};runCatching{val o=JSONObject(p.getString("conditions","{}"));o.keys().forEach{conditions[it]=o.getString(it)}};runCatching{val o=JSONObject(p.getString("thresholds","{}"));o.keys().forEach{thresholds[it]=o.getDouble(it)}}}
}

class AcademicStore(context:Context){
    private val p=context.prefs(); private val grades=mutableMapOf<String,AcademicGrade>(); init{load()}
    val assessments=listOf(
        AcademicAssessment(AcademicAssessmentType.CONTROL_WEEK,1,"control-1","Контрольная неделя 1","1 семестр · 7-я неделя"),
        AcademicAssessment(AcademicAssessmentType.CONTROL_WEEK,2,"control-2","Контрольная неделя 2","1 семестр · 14-я неделя"),
        AcademicAssessment(AcademicAssessmentType.CONTROL_WEEK,3,"control-3","Контрольная неделя 3","2 семестр · 7-я неделя"),
        AcademicAssessment(AcademicAssessmentType.CONTROL_WEEK,4,"control-4","Контрольная неделя 4","2 семестр · 14-я неделя"),
        AcademicAssessment(AcademicAssessmentType.SESSION,1,"session-1","Сессия 1","Декабрь — январь"),
        AcademicAssessment(AcademicAssessmentType.SESSION,2,"session-2","Сессия 2","Июнь")
    )
    fun grade(a:AcademicAssessment,s:String)=grades["${a.id}|$s"]
    fun set(a:AcademicAssessment,s:String,v:Int){if(v !in a.allowedGrades)return;val id="${a.id}|$s";grades[id]=AcademicGrade(id,a.id,s,v,System.currentTimeMillis());save()}
    fun delete(a:AcademicAssessment,s:String){grades.remove("${a.id}|$s");save()}
    fun completed(a:AcademicAssessment,subjects:List<String>)=subjects.count{grade(a,it)!=null}
    private fun save(){p.edit().putString("academic",JsonStore.encodeGrades(grades.values).toString()).apply()}
    private fun load(){runCatching{JsonStore.decodeGrades(JSONArray(p.getString("academic","[]"))).forEach{grades[it.id]=it}}}
}

object JsonStore{
    fun encodeSchedule(s:UniversitySchedule)=JSONArray().apply{s.days.forEach{d->put(JSONObject().apply{put("date",d.date);put("lessons",JSONArray().apply{d.lessons.forEach{l->put(JSONObject().apply{put("id",l.id);put("number",l.number);put("name",l.name);put("teacher",l.teacher);put("room",l.room);put("startTime",l.startTime);put("endTime",l.endTime);put("subgroup",l.subgroup);put("group",l.group);put("kind",l.kind.name)})}})})}}
    fun decodeSchedule(a:JSONArray)=UniversitySchedule((0 until a.length()).map{d->val o=a.getJSONObject(d);val ls=o.getJSONArray("lessons");ScheduleDay(o.getString("date"),(0 until ls.length()).map{val x=ls.getJSONObject(it);Lesson(x.getString("id"),x.getInt("number"),x.getString("name"),x.optString("teacher"),x.optString("room"),x.getString("startTime"),x.getString("endTime"),if(x.isNull("subgroup"))null else x.getInt("subgroup"),if(x.isNull("group"))null else x.getString("group"),runCatching{LessonKind.valueOf(x.getString("kind"))}.getOrDefault(LessonKind.OTHER))})})
    fun encodeAttendance(rs:Collection<AttendanceRecord>)=JSONArray().apply{rs.forEach{put(JSONObject().apply{put("id",it.id);put("lessonId",it.lessonId);put("subject",it.subject);put("kind",it.kind.name);put("date",it.date);put("status",it.status.name)})}}
    fun decodeAttendance(a:JSONArray)=(0 until a.length()).map{val o=a.getJSONObject(it);AttendanceRecord(o.getString("id"),o.getString("lessonId"),o.getString("subject"),LessonKind.valueOf(o.getString("kind")),o.getString("date"),AttendanceStatus.valueOf(o.getString("status")))}
    fun encodePoints(rs:Collection<PointRecord>)=JSONArray().apply{rs.forEach{put(JSONObject().apply{put("id",it.id);put("subject",it.subject);put("kind",it.kind.name);put("points",it.points);put("date",it.date);put("comment",it.comment)})}}
    fun decodePoints(a:JSONArray)=(0 until a.length()).map{val o=a.getJSONObject(it);PointRecord(o.getString("id"),o.getString("subject"),LessonKind.valueOf(o.getString("kind")),o.getDouble("points"),o.getString("date"),o.optString("comment"))}
    fun encodeGrades(rs:Collection<AcademicGrade>)=JSONArray().apply{rs.forEach{put(JSONObject().apply{put("id",it.id);put("assessmentId",it.assessmentId);put("subject",it.subject);put("value",it.value);put("date",it.date)})}}
    fun decodeGrades(a:JSONArray)=(0 until a.length()).map{val o=a.getJSONObject(it);AcademicGrade(o.getString("id"),o.getString("assessmentId"),o.getString("subject"),o.getInt("value"),o.getLong("date"))}
}
