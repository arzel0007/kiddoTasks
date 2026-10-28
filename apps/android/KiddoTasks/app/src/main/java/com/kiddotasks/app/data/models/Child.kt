package com.kiddotasks.app.data.models

import java.util.Date

enum class AgeGroup {
    PRESCHOOL, EARLY_SCHOOL, MIDDLE_SCHOOL, TEEN;

    companion object {
        fun fromAge(age: Int): AgeGroup = when {
            age in 0..5 -> PRESCHOOL
            age in 6..8 -> EARLY_SCHOOL
            age in 9..11 -> MIDDLE_SCHOOL
            else -> TEEN
        }
    }
}

data class ChildAvatar(
    val emoji: String = "👧",
    val colorHex: String = "#3978A8"
) {
    companion object {
        val DEFAULT = ChildAvatar()
        val PRESETS = listOf(
            ChildAvatar("👧", "#3978A8"),
            ChildAvatar("👦", "#6F9FBD"),
            ChildAvatar("🦁", "#D59A3A"),
            ChildAvatar("🐢", "#3F8B70"),
            ChildAvatar("🦄", "#285B82"),
            ChildAvatar("🦋", "#647487"),
            ChildAvatar("🐸", "#3F8B70"),
            ChildAvatar("🦊", "#D97868")
        )
    }
}

data class Child(
    val id: String,
    var name: String,
    val familyId: String,
    var avatar: ChildAvatar = ChildAvatar.DEFAULT,
    var photoData: ByteArray? = null,
    var photoUrl: String? = null,
    var dateOfBirth: Date? = null,
    var activePoints: Int = 0,
    var totalPointsEarned: Int = 0,
    val createdAt: Date = Date(),
    var updatedAt: Date = Date()
) {
    val age: Int?
        get() = dateOfBirth?.let { dob ->
            java.time.Period.between(
                dob.toInstant().atZone(java.time.ZoneId.systemDefault()).toLocalDate(),
                java.time.LocalDate.now()
            ).years
        }

    val ageGroup: AgeGroup?
        get() = age?.let { AgeGroup.fromAge(it) }
}