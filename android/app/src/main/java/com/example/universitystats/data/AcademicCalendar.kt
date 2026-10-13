package com.example.universitystats.data

import java.time.*

object AcademicCalendar {
    const val notificationHour=9
    const val notificationMinute=0
    fun academicYearStart(date:LocalDate=LocalDate.now())=if(date.monthValue>=8)date.year else date.year-1
    fun controlWeeks(academicYear:Int):List<ControlWeek>{
        val starts=listOf(1 to LocalDate.of(academicYear,9,1),2 to LocalDate.of(academicYear+1,2,1));val out=mutableListOf<ControlWeek>()
        for((semester,start) in starts){val firstMonday=start.minusDays((start.dayOfWeek.value-1).toLong());for(w in listOf(7,14)){val d=firstMonday.plusDays((w-1)*7L);val n=if(semester==1){if(w==7)1 else 2}else{if(w==7)3 else 4};out += ControlWeek(semester,n,w,d)}}
        return out.sortedBy{it.startDate}
    }
}
