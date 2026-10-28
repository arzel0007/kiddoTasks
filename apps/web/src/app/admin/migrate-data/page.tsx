"use client";

import { useState } from "react";
import { useFamilyStore } from "@/lib/family-store";
import { firebaseAuth, firestore, isFirebaseConfigured } from "@/lib/firebase";
import { doc, setDoc, updateDoc, collection, getDocs, query, where } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

interface Child {
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
}

interface Task {
  id: string;
  familyId: string;
  name: string;
  description: string;
  icon: string;
  category: string;
  pointValue: number;
  requiresApproval?: boolean;
  approvalBehavior: string;
  assignedChildIds: string[];
  recurrence: { type: string; weekdays?: number[] };
  isActive: boolean;
  createdBy: string;
  createdAt?: string;
  updatedAt?: string;
  version?: number;
}

interface Reward {
  id: string;
  familyId: string;
  name: string;
  description: string;
  icon: string;
  pointCost: number;
  eligibleChildIds: string[];
  requiresApproval?: boolean;
  isActive: boolean;
  createdBy: string;
  createdAt?: string;
  updatedAt?: string;
  version?: number;
}

interface FamilySnapshot {
  family: {
    id: string;
    name: string;
    members: string[];
    familyCode: string;
    settings: Record<string, unknown>;
  };
  children: Child[];
  tasks: Task[];
  rewards: Reward[];
}

export default function MigrateDataPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [jsonData, setJsonData] = useState("");
  const [preview, setPreview] = useState<{
    children: number;
    tasks: number;
    rewards: number;
  } | null>(null);

  const handleParseJSON = () => {
    try {
      const data: FamilySnapshot = JSON.parse(jsonData);
      setPreview({
        children: data.children.length,
        tasks: data.tasks.length,
        rewards: data.rewards.length,
      });
      toast.success("JSON parsed successfully!");
    } catch (error) {
      toast.error("Invalid JSON format");
      setPreview(null);
    }
  };

  const handleMigrate = async () => {
    if (!isFirebaseConfigured) {
      toast.error("Firebase is not configured");
      return;
    }

    if (!jsonData) {
      toast.error("Please paste the iOS JSON data first");
      return;
    }

    const user = firebaseAuth().currentUser;
    if (!user) {
      toast.error("Please sign in first");
      return;
    }

    setLoading(true);

    try {
      const data: FamilySnapshot = JSON.parse(jsonData);

      const db = firestore();
      const auth = getAuth();

      // Start transaction
      const tasksRef = collection(db, "tasks");
      const rewardsRef = collection(db, "rewards");
      const childrenRef = collection(db, "children");

      // Get current familyId from user
      const usersRef = collection(db, "parents");
      const q = query(usersRef, where("email", "==", user.email));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        throw new Error("Parent record not found");
      }

      const parentDoc = querySnapshot.docs[0];
      const familyId = parentDoc.data().familyId;

      // 1. Copy tasks from iOS (overwrite webapp tasks)
      // This preserves iOS task icons, descriptions, recurrence settings
      for (const task of data.tasks) {
        await setDoc(doc(db, "tasks", task.id), {
          ...task,
          familyId,
          updatedAt: new Date().toISOString(),
        });
      }

      // 2. Copy rewards from iOS (overwrite webapp rewards)
      // This preserves iOS reward icons, configurations
      for (const reward of data.rewards) {
        await setDoc(doc(db, "rewards", reward.id), {
          ...reward,
          familyId,
          updatedAt: new Date().toISOString(),
        });
      }

      // 3. Update children icons/avatars but KEEP webapp points
      // Get current webapp children points first
      const childrenSnapshot = await getDocs(
        query(childrenRef, where("familyId", "==", familyId))
      );

      for (const childDoc of childrenSnapshot.docs) {
        const iosChild = data.children.find((c) => c.id === childDoc.id);
        if (iosChild) {
          // Update only avatar/photo fields, keep points from webapp
          await updateDoc(childDoc.ref, {
            avatar: iosChild.avatar,
            photoData: iosChild.photoData,
            photoURL: iosChild.photoURL,
            dateOfBirth: iosChild.dateOfBirth,
            updatedAt: new Date().toISOString(),
          });
        }
      }

      // 4. Update task recurrence with weekdays field for recurring tasks
      // This ensures iOS tasks with weekdays recurrence work correctly
      for (const task of data.tasks) {
        if (
          task.recurrence.type === "weekdays" &&
          Array.isArray(task.recurrence.weekdays)
        ) {
          await updateDoc(doc(db, "tasks", task.id), {
            "recurrence.weekdays": task.recurrence.weekdays,
          });
        }
      }

      toast.success("Migration completed! Please refresh both apps.");
      router.push("/parent/family");

    } catch (error: any) {
      console.error("Migration error:", error);
      toast.error(
        `Migration failed: ${error.message || "Unknown error"}`
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-page px-4 py-8">
      <div className="mx-auto max-w-2xl">
        <header className="mb-8">
          <h1 className="text-2xl font-bold text-ink">Data Migration Tool</h1>
          <p className="mt-2 text-ink-secondary">
            Merge data from iOS app into webapp while preserving webapp points.
          </p>
        </header>

        <div className="mb-6 rounded-xl border border-border bg-card p-6">
          <h2 className="text-lg font-semibold text-ink">Instructions</h2>
          <ol className="mt-2 list-decimal space-y-2 pl-5 text-sm text-ink-secondary">
            <li>Export family data from iOS app</li>
            <li>Paste the JSON data below</li>
            <li>Click "Parse JSON" to preview</li>
            <li>Click "Migrate Data" to merge</li>
          </ol>
        </div>

        <div className="mb-6 rounded-xl border border-border bg-card p-6">
          <label className="mb-2 block text-sm font-medium text-ink">
            iOS JSON Data
          </label>
          <textarea
            className="w-full min-h-[300px] rounded-lg border border-border bg-background px-4 py-3 font-mono text-sm text-ink focus:border-primary focus:outline-none"
            placeholder='{"family": {...}, "children": [...], "tasks": [...], "rewards": [...]}'
            value={jsonData}
            onChange={(e) => setJsonData(e.target.value)}
          />
          <button
            onClick={handleParseJSON}
            className="mt-4 rounded-lg bg-primary px-4 py-2 font-medium text-white hover:bg-primary-dark"
          >
            Parse JSON
          </button>
        </div>

        {preview && (
          <div className="mb-6 rounded-xl border border-border bg-card p-6">
            <h2 className="text-lg font-semibold text-ink">Data Preview</h2>
            <div className="mt-4 grid gap-4 sm:grid-cols-3">
              <div className="rounded-lg bg-primary/10 p-4">
                <div className="text-3xl font-bold text-primary">
                  {preview.children}
                </div>
                <div className="text-sm text-ink-secondary">Children</div>
              </div>
              <div className="rounded-lg bg-primary/10 p-4">
                <div className="text-3xl font-bold text-primary">
                  {preview.tasks}
                </div>
                <div className="text-sm text-ink-secondary">Tasks</div>
              </div>
              <div className="rounded-lg bg-primary/10 p-4">
                <div className="text-3xl font-bold text-primary">
                  {preview.rewards}
                </div>
                <div className="text-sm text-ink-secondary">Rewards</div>
              </div>
            </div>
          </div>
        )}

        <button
          onClick={handleMigrate}
          disabled={loading || !jsonData}
          className="w-full rounded-xl bg-primary px-6 py-4 font-semibold text-white hover:bg-primary-dark disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? "Migrating Data..." : "Migrate Data"}
        </button>

        <div className="mt-6 rounded-xl border border-amber-200 bg-amber-50 p-6">
          <h3 className="text-lg font-semibold text-amber-900">
            ⚠️ Important Notes
          </h3>
          <ul className="mt-2 list-disc space-y-2 pl-5 text-sm text-amber-900">
            <li>
              <strong>Points will be preserved</strong> from the webapp
            </li>
            <li>
              <strong>Tasks from iOS</strong> will overwrite webapp tasks (icons,
              descriptions, recurrence)
            </li>
            <li>
              <strong>Children avatars</strong> will be updated with iOS versions
            </li>
            <li>
              <strong>Completions and claims</strong> will remain from webapp
            </li>
            <li>
              <strong>Refresh both apps</strong> after migration to see updates
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
