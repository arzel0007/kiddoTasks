/** Shared family model types (aligned with iOS Codable models). */

export type FamilySettings = {
  pointDisplaySymbol: string;
  enableNotifications: boolean;
  celebrationAnimationsEnabled: boolean;
  requireApprovalByDefault: boolean;
  weekStartsOn: number;
  kidsStationPIN: string;
  enableMiniGames: boolean;
  basketballMaxMinutes: number;
  allowanceMode?: "STARS_ONLY" | "FLAT_DAILY" | "PER_CHORE";
  flatDailyAmount?: number;
  weekBonusTitle?: string;
  plan?: string;
};

export type Family = {
  id: string;
  name: string;
  members: string[];
  familyCode: string;
  photoData?: string | null;
  photoURL?: string | null;
  settings: FamilySettings;
  createdAt?: string | null;
  updatedAt?: string | null;
  serverUpdatedAt?: string | null;
};

export type Child = {
  id: string;
  name: string;
  familyId: string;
  avatar: { emoji: string; colorHex: string };
  photoData?: string | null;
  photoURL?: string | null;
  dateOfBirth?: string | null;
  activePoints: number;
  totalPointsEarned: number;
  createdAt?: string;
  updatedAt?: string;
};

export type KiddoTask = {
  id: string;
  familyId: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  pointValue: number;
  requiresApproval: boolean;
  approvalBehavior: string;
  assignedChildIds: string[];
  isActive: boolean;
  createdBy: string;
  createdAt?: string;
  updatedAt?: string;
};

export type TaskCompletion = {
  id: string;
  familyId: string;
  taskId: string;
  childId: string;
  status: "AWAITING_APPROVAL" | "APPROVED" | "REJECTED" | "COMPLETED";
  completedAt?: string;
  approvedAt?: string | null;
  notes?: string | null;
  pointsAwarded?: number | null;
};

export type Reward = {
  id: string;
  familyId: string;
  name: string;
  description: string;
  icon: string;
  pointCost: number;
  eligibleChildIds: string[];
  isActive: boolean;
  createdBy: string;
  createdAt?: string;
  updatedAt?: string;
};

export type RewardClaim = {
  id: string;
  familyId: string;
  rewardId: string;
  childId: string;
  status: "CLAIMED" | "APPROVED" | "REJECTED";
  claimedAt?: string;
  notes?: string | null;
};

export type PointTransaction = {
  id: string;
  familyId: string;
  childId: string;
  amount: number;
  type: string;
  description: string;
  createdAt?: string;
};

export type Entitlements = {
  plan: "free" | "plus" | "pro";
  status: "active" | "trialing" | "past_due" | "canceled" | "none";
  currentPeriodEnd?: string | null;
};

// FREE_LIMITS moved to entitlements.ts (single source of truth).

