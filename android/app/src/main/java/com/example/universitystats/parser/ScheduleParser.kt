package com.example.universitystats.parser

import com.example.universitystats.data.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.*
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.regex.Pattern

class ScheduleParseException(message:String): Exception(message)

object ScheduleParser {
    fun parseHtml(html:String): UniversitySchedule {
        val normalized = html
            .replace("&quot;", "\"")
            .replace("&#34;", "\"")
            .replace("&#39;", "'")
            .replace("&apos;", "'")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
        val templates = extractTemplates(normalized)
        if (templates.isEmpty()) throw ScheduleParseException("В сохранённой странице не найдены данные расписания. Сохрани именно страницу расписания, а не страницу входа.")
        val schedule = buildCalendarDays(templates)
        val lessonCount = schedule.days.sumOf { it.lessons.size }
        if (lessonCount == 0) throw ScheduleParseException("Страница содержит шаблоны, но пары не распознаны. Возможно, Chrome сохранил страницу входа или формат сайта изменился.")
        return schedule
    }

    private fun extractTemplates(html:String): Map<Int,JSONObject> {
        val result=linkedMapOf<Int,JSONObject>()
        val p=Pattern.compile("(?<![A-Za-z0-9_])days\\s*\\[\\s*(\\d{1,2})\\s*]\\s*=\\s*([\'\"])")
        val m=p.matcher(html)
        while(m.find()){
            val idx=m.group(1).toIntOrNull() ?: continue
            if(idx !in 1..14) continue
            val quote = m.group(2)[0]
            val start=m.end(); var i=start; var escaped=false
            while(i<html.length){
                val c=html[i]
                if(escaped){escaped=false;i++;continue}
                if(c=='\\'){escaped=true;i++;continue}
                if(c==quote) break
                i++
            }
            if(i>=html.length) continue
            val raw=html.substring(start,i)
            val decoded=decodeJavaScriptString(raw)
            runCatching{JSONObject(decoded)}.getOrNull()?.let{ if(it.has("ScheduleCell")) result[idx]=it }
        }
        return result
    }

    private fun buildCalendarDays(templates:Map<Int,JSONObject>):UniversitySchedule{
        val today=LocalDate.now()
        val academicYear=if(today.monthValue>=9) today.year else today.year-1
        var date=LocalDate.of(academicYear,9,1)
        val end=LocalDate.of(academicYear+1,8,31)
        val days=mutableListOf<ScheduleDay>()
        while(!date.isAfter(end)){
            if(date.dayOfWeek!=DayOfWeek.SUNDAY){
                val idx=templateIndex(date)
                val t=templates[idx]
                days += ScheduleDay(date.key(), if(t==null) emptyList() else parseTemplate(t))
            }
            date=date.plusDays(1)
        }
        return UniversitySchedule(days)
    }

    private fun templateIndex(date:LocalDate):Int{
        val academicStart=LocalDate.of(if(date.monthValue>=9) date.year else date.year-1,9,2)
        val firstMonday=academicStart.minusDays((academicStart.dayOfWeek.value-1).toLong())
        val monday=date.minusDays((date.dayOfWeek.value-1).toLong())
        val weekNumber=(java.time.temporal.ChronoUnit.DAYS.between(firstMonday,monday)/7).coerceAtLeast(0)
        return ((weekNumber%2)*7 + (date.dayOfWeek.value-1)).toInt()+1
    }

    private fun parseTemplate(t:JSONObject):List<Lesson>{
        val cells=asArray(t.opt("ScheduleCell")); val out=mutableListOf<Lesson>()
        for(i in 0 until cells.length()){
            val cell=asObject(cells.opt(i)) ?: continue
            val start=extractTime(cell.opt("DateBegin")) ?: continue
            val end=extractTime(cell.opt("DateEnd")) ?: continue
            val number=lessonNumber(start)
            val subs=asArray(cell.opt("Subgroup"))
            for(j in 0 until subs.length()){
                val s=asObject(subs.opt(j)) ?: continue
                val name=extractString(s.opt("DISCIPLINE")) ?: "Без названия"
                val teacher=extractString(s.opt("TEACHER")) ?: ""
                val room=extractString(s.opt("CLASSROOM")) ?: ""
                val group=extractString(s.opt("GROUP"))
                val subgroup=extractSubgroup(extractString(s.opt("SUBGROUP")))
                val kind=lessonKind(extractString(s.opt("TYPE_LESSON")))
                out += Lesson.create(number,name,teacher,room,start,end,subgroup,group,kind)
            }
        }
        return out.distinctBy{it.id}.sortedWith(compareBy<Lesson>{it.number}.thenBy{it.startTime}.thenBy{it.name})
    }

    private fun asArray(v:Any?):JSONArray = when(v){is JSONArray->v;is JSONObject->JSONArray().put(v);else->JSONArray()}
    private fun asObject(v:Any?):JSONObject?=v as? JSONObject
    private fun extractString(v:Any?):String?=when(v){null,JSONObject.NULL->null;is String->v;is JSONArray->if(v.length()>0)extractString(v.opt(0)) else null;is JSONObject->if(v.has("value"))extractString(v.opt("value")) else v.toString();else->v.toString()}
    private fun extractTime(v:Any?):String?{
        val s=extractString(v) ?: return null
        val m=Pattern.compile("(\\d{1,2}):(\\d{2})(?::\\d{2})?").matcher(s)
        if(!m.find()) return null
        val h=m.group(1).toIntOrNull()?:return null; val min=m.group(2).toIntOrNull()?:return null
        if(h !in 0..23 || min !in 0..59)return null
        return "%02d:%02d".format(Locale.US,h,min)
    }
    private fun lessonNumber(start:String)=when(start){"08:00"->1;"09:50"->2;"11:40"->3;"13:45"->4;"15:35"->5;"17:25"->6;"19:15"->7;else->0}
    private fun lessonKind(raw:String?):LessonKind{val s=raw?.trim()?.lowercase(Locale("ru"))?:return LessonKind.OTHER;return when{ "лек" in s->LessonKind.LECTURE;"лаб" in s->LessonKind.LABORATORY;"практ" in s||"семинар" in s->LessonKind.PRACTICE;else->LessonKind.OTHER}}
    private fun extractSubgroup(s:String?):Int?=s?.let{Pattern.compile("\\d+").matcher(it).let{m->if(m.find())m.group().toIntOrNull() else null}}
    private fun decodeJavaScriptString(value:String):String{
        val out=StringBuilder();var i=0
        while(i<value.length){val c=value[i];if(c!='\\'){out.append(c);i++;continue};i++;if(i>=value.length)break;when(val e=value[i]){
            '\\'->out.append('\\');'\''->out.append('\'');'"'->out.append('"');'n'->out.append('\n');'r'->out.append('\r');'t'->out.append('\t');'/'->out.append('/')
            'u'->{if(i+4<value.length){val hex=value.substring(i+1,i+5);hex.toIntOrNull(16)?.let{out.append(it.toChar());i+=4}}}
            else->out.append(e)};i++}
        return out.toString()
    }
}
