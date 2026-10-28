package com.kiddotasks.app.data.models

import java.util.Date

enum class TaskCategory {
    HOUSEHOLD, LEARNING, HEALTH, PERSONAL, PETS, OTHER;

    val displayName: String
        get() = when (this) {
            HOUSEHOLD -> "Household"
            LEARNING -> "Learning"
            HEALTH -> "Health"
            PERSONAL -> "Personal care"
            PETS -> "Pet care"
            OTHER -> "Other"
        }
}

enum class RecurrenceType {
    ONE_TIME, DAILY, WEEKDAYS, WEEKLY, CUSTOM;

    val displayName: String
        get() = when (this) {
            ONE_TIME -> "One time"
            DAILY -> "Every day"
            WEEKDAYS -> "Weekdays"
            WEEKLY -> "Weekly"
            CUSTOM -> "Custom"
        }
}

data class TaskRecurrence(
    val type: RecurrenceType = RecurrenceType.ONE_TIME,
    val weekdays: List<Int>? = null
)

enum class TaskApprovalBehavior {
    USE_FAMILY_DEFAULT, ALWAYS_REQUIRE_APPROVAL, AUTO_APPROVE;

    val displayName: String
        get() = when (this) {
            USE_FAMILY_DEFAULT -> "Use family setting"
            ALWAYS_REQUIRE_APPROVAL -> "Always require approval"
            AUTO_APPROVE -> "Auto-approve and award points"
        }
}

data class KiddoTask(
    val id: String,
    val familyId: String,
    var name: String,
    var description: String = "",
    var icon: String = "checkmark.circle",
    var category: TaskCategory = TaskCategory.HOUSEHOLD,
    var pointValue: Int = 10,
    var requiresApproval: Boolean = true,
    var approvalBehavior: TaskApprovalBehavior = TaskApprovalBehavior.USE_FAMILY_DEFAULT,
    var assignedChildIds: List<String> = emptyList(),
    var recurrence: TaskRecurrence = TaskRecurrence(),
    var isActive: Boolean = true,
    val createdBy: String,
    val createdAt: Date = Date(),
    var updatedAt: Date = Date(),
    var version: Int = 1
) {
    fun isAssignedTo(childId: String): Boolean =
        assignedChildIds.isEmpty() || assignedChildIds.contains(childId)

    fun requiresParentApproval(requireApprovalByDefault: Boolean): Boolean =
        when (approvalBehavior) {
            TaskApprovalBehavior.USE_FAMILY_DEFAULT -> requireApprovalByDefault
            TaskApprovalBehavior.ALWAYS_REQUIRE_APPROVAL -> true
            TaskApprovalBehavior.AUTO_APPROVE -> false
        }

    fun isDue(on date: Date = Date()): Boolean {
        val cal = java.util.Calendar.getInstance()
        cal.time = date
        val targetDay = cal.get(java.util.Calendar.DAY_OF_WEEK)
        cal.time = createdAt
        val createdDay = cal.get(java.util.Calendar.DAY_OF_WEEK)
        return when (recurrence.type) {
            RecurrenceType.ONE_TIME -> cal.timeInMillis <= date.time || java.util.Calendar.getInstance().isDate(createdAt, inSameDayAs: date)
            RecurrenceType.DAILY -> true
            RecurrenceType.WEEKDAYS -> targetDay != java.util.Calendar.SUNDAY && targetDay != java.util.Calendar.SATURDAY
            RecurrenceType.WEEKLY -> targetDay == createdDay
            RecurrenceType.CUSTOM -> true
        }
    }

    override fun equals(other: Any?): Boolean =
        other is KiddoTask && other.id == id

    override fun hashCode(): Int = id.hashCode()
}

// Calendar helper (not standard in Kotlin/JVM, inline for clarity)
private fun java.util.Calendar.isDate(d1: Date, inSameDayAs d2: Date): Boolean {
    val c1 = java.util.Calendar.getInstance(); c1.time = d1
    val c2 = java.util.Calendar.getInstance(); c2.time = d2
    return c1.get(java.util.Calendar.YEAR) == c2.get(java.util.Calendar.YEAR) &&
        c1.get(java.util.Calendar.DAY_OF_YEAR) == c2.get(java.util.Calendar.DAY_OF_YEAR)
}