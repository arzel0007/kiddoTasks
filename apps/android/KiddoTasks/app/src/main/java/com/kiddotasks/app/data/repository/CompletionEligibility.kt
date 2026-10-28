package com.kiddotasks.app.data.repository

import com.kiddotasks.app.data.models.*
import java.util.Date

/**
 * Mirrors the iOS `CompletionEligibility` logic so task completion rules
 * are consistent across iOS, web, and Android.
 */
object CompletionEligibility {

    /**
     * Whether a child can submit a completion for this task right now.
     */
    fun canSubmit(task: KiddoTask, childId: String): Boolean {
        if (!task.isActive) return false
        return task.isAssignedTo(childId)
    }

    /**
     * Whether a completion needs parent approval based on task behavior + family default.
     */
    fun requiresApproval(task: KiddoTask, settings: FamilySettings): Boolean =
        task.requiresParentApproval(settings.requireApprovalByDefault)

    /**
     * Whether points can be awarded immediately (auto-approve) or must wait for approval.
     */
    fun awardsPointsImmediately(task: KiddoTask, settings: FamilySettings): Boolean =
        !requiresApproval(task, settings)

    /**
     * Whether a reward claim can be submitted by this child.
     */
    fun canClaimReward(reward: Reward, childId: String): Boolean =
        reward.isActive && reward.isEligibleFor(childId)

    /**
     * Whether the child has enough active points for a reward.
     */
    fun hasEnoughPoints(child: Child, reward: Reward): Boolean =
        child.activePoints >= reward.pointCost

    /**
     * Weekly streak check: did the child complete every due task for 7 consecutive days?
     * (Mirrored from WeekBonus logic on iOS.)
     */
    fun isOnWeeklyStreak(completions: List<TaskCompletion>, dueDates: List<Date>): Boolean {
        if (dueDates.isEmpty()) return false
        val completedDates = completions
            .filter { it.status == CompletionStatus.APPROVED }
            .map { it.completedAt }
            .toSet()
        return dueDates.all { completedDates.contains(it) }
    }
}