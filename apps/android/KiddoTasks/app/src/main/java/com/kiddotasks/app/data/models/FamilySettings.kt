package com.kiddotasks.app.data.models

data class AllowanceMode(value: String) {
    companion object {
        val STARS_ONLY = AllowanceMode("starsOnly")
        val FLAT_DAILY = AllowanceMode("flatDaily")
    }
}

data class FamilySettings(
    var pointDisplaySymbol: String = "⭐",
    var enableNotifications: Boolean = true,
    var celebrationAnimationsEnabled: Boolean = true,
    var requireApprovalByDefault: Boolean = true,
    var weekStartsOn: Int = 1,
    var kidsStationPin: String = generateRandomPin(),
    var enableMiniGames: Boolean = true,
    var basketballMaxMinutes: Int = 0,
    var allowanceMode: AllowanceMode = AllowanceMode.STARS_ONLY,
    var flatDailyAmount: Double = 1.0,
    var weekBonusTitle: String = "Full week!",
    var plan: String = "free",
    var enableWishlist: Boolean = false
) {
    companion object {
        fun generateRandomPin(): String {
            val r = java.util.Random()
            return "%06d".format(r.nextInt(1_000_000))
        }
    }
}

data class Family(
    val id: String,
    var name: String,
    var memberIds: List<String> = emptyList(),
    var familyCode: String = generateFamilyCode(),
    var photoData: ByteArray? = null,
    var photoUrl: String? = null,
    var settings: FamilySettings = FamilySettings(),
    val createdAt: Date = Date(),
    var updatedAt: Date = Date(),
    var serverUpdatedAt: Date? = null
) {
    companion object {
        fun generateFamilyCode(): String {
            val r = java.util.Random()
            val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
            return (0..5).joinToString("") { chars.elementAt(r.nextInt(chars.length)) }
        }
    }
}