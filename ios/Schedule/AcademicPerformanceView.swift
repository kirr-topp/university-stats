import SwiftUI

struct AcademicPerformanceView:
    View {
    
    let schedule:
    UniversitySchedule
    
    @ObservedObject
    var academicStore:
    AcademicStore
    
    @State
    private var selectedAssessmentID:
    String?
    
    private var assessments:
    [AcademicAssessment] {
        
        academicStore.allAssessments
    }
    
    private var subjects:
    [String] {
        
        schedule
            .subjects()
            .sorted()
    }
    
    private var selectedAssessment:
    AcademicAssessment? {
        
        guard
            let selectedAssessmentID
                else {
            return assessments.first
        }
        
        return assessments.first {
            $0.id ==
            selectedAssessmentID
        }
    }
    
    var body: some View {
        Group {
            if subjects.isEmpty {
                ContentUnavailableView(
                    "Нет предметов",
                    systemImage: "graduationcap",
                    description: Text("Сначала загрузите расписание.")
                )
            } else {
                List {
                    Section("Период") {
                        Picker(
                            "Период",
                            selection: Binding(
                                get: {
                                    selectedAssessmentID ?? assessments.first?.id ?? ""
                                },
                                set: {
                                    selectedAssessmentID = $0
                                }
                            )
                        ) {
                            ForEach(assessments) { assessment in
                                Text(assessment.title)
                                    .tag(assessment.id)
                            }
                        }
                        
                        if let assessment = selectedAssessment {
                            Text(assessment.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let assessment = selectedAssessment {
                        Section("Оценки по предметам") {
                            ForEach(subjects, id: \.self) { subject in
                                SubjectGradeRow(
                                    subject: subject,
                                    assessment: assessment,
                                    academicStore: academicStore
                                )
                            }
                        }
                    }
                    
                    if let assessment = selectedAssessment {
                        Section("Статистика") {
                            let completed = academicStore.completedCount(
                                for: assessment,
                                subjects: subjects
                            )
                            
                            HStack {
                                Text("Заполнено")
                                
                                Spacer()
                                
                                Text("\(completed) / \(subjects.count)")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if completed < subjects.count {
                                Text("Заполните оценки по всем предметам.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section("По предметам") {
                        ForEach(subjects, id: \.self) { subject in
                            SubjectSummaryRow(
                                subject: subject,
                                assessments: assessments,
                                academicStore: academicStore
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Успеваемость")
        .onAppear {
            if selectedAssessmentID == nil {
                selectedAssessmentID = assessments.first?.id
            }
        }
    }
    
    // MARK: - Строка оценки
    
    private struct SubjectGradeRow:
        View {
        
        let subject:
        String
        
        let assessment:
        AcademicAssessment
        
        @ObservedObject
        var academicStore:
        AcademicStore
        
        var body:
        some View {
            
            HStack(
                spacing:
                    12
            ) {
                
                VStack(
                    alignment:
                            .leading,
                    spacing:
                        3
                ) {
                    
                    Text(
                        subject
                    )
                    .font(
                        .body
                    )
                    
                    Text(
                        assessment.type ==
                            .controlWeek
                        ? "0 / 1 / 2"
                        : "2 / 3 / 4 / 5"
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
                
                Spacer()
                
                let currentGrade =
                academicStore.grade(
                    for:
                        assessment,
                    subject:
                        subject
                )
                
                Menu {
                    
                    ForEach(
                        assessment.allowedGrades,
                        id:
                            \.self
                    ) { grade in
                        
                        Button {
                            
                            academicStore
                                .setGrade(
                                    grade,
                                    for:
                                        assessment,
                                    subject:
                                        subject
                                )
                            
                        } label: {
                            
                            HStack {
                                
                                Text(
                                    "\(grade)"
                                )
                                
                                if currentGrade?.value ==
                                    grade {
                                    
                                    Spacer()
                                    
                                    Image(
                                        systemName:
                                            "checkmark"
                                    )
                                }
                            }
                        }
                    }
                    
                    if currentGrade != nil {
                        
                        Divider()
                        
                        Button(
                            "Удалить оценку",
                            role:
                                    .destructive
                        ) {
                            
                            academicStore
                                .deleteGrade(
                                    for:
                                        assessment,
                                    subject:
                                        subject
                                )
                        }
                    }
                    
                } label: {
                    
                    if let currentGrade {
                        
                        Text(
                            "\(currentGrade.value)"
                        )
                        .font(
                            .system(
                                size:
                                    24,
                                weight:
                                        .bold,
                                design:
                                        .rounded
                            )
                        )
                        .frame(
                            minWidth:
                                40
                        )
                        
                    } else {
                        
                        Text(
                            "—"
                        )
                        .font(
                            .system(
                                size:
                                    24,
                                weight:
                                        .medium,
                                design:
                                        .rounded
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .frame(
                            minWidth:
                                40
                        )
                    }
                }
                .buttonStyle(
                    .bordered
                )
            }
            .padding(
                .vertical,
                4
            )
        }
    }
    
    // MARK: - Сводка предмета
    
    private struct SubjectSummaryRow:
        View {
        
        let subject:
        String
        
        let assessments:
        [AcademicAssessment]
        
        @ObservedObject
        var academicStore:
        AcademicStore
        
        var body:
        some View {
            
            VStack(
                alignment:
                        .leading,
                spacing:
                    8
            ) {
                
                Text(
                    subject
                )
                .font(
                    .headline
                )
                
                HStack(
                    spacing:
                        10
                ) {
                    
                    ForEach(
                        assessments
                    ) { assessment in
                        
                        let grade =
                        academicStore.grade(
                            for:
                                assessment,
                            subject:
                                subject
                        )
                        
                        VStack(
                            spacing:
                                3
                        ) {
                            
                            Text(
                                shortTitle(
                                    assessment
                                )
                            )
                            .font(
                                .caption2
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            
                            Text(
                                grade.map {
                                    "\($0.value)"
                                } ?? "—"
                            )
                            .font(
                                .headline
                            )
                        }
                        .frame(
                            minWidth:
                                42
                        )
                    }
                }
            }
            .padding(
                .vertical,
                4
            )
        }
        
        private func shortTitle(
            _ assessment:
            AcademicAssessment
        ) -> String {
            
            switch assessment.type {
                
            case .controlWeek:
                return "КН-\(assessment.number)"
                
            case .session:
                return "Сессия \(assessment.number)"
            }
        }
    }
}
