"use client";

import { useState } from "react";
import { firebaseAuth, firestore, isFirebaseConfigured } from "@/lib/firebase";
import { collection, query, where, getDocs } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { firebaseFunctions } from "@/lib/firebase";
import { useRouter } from "next/navigation";

export default function FixMigrationPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleFixMigration = async () => {
    if (!isFirebaseConfigured) {
      setError("Firebase not configured");
      return;
    }

    const user = firebaseAuth().currentUser;
    if (!user) {
      setError("Please sign in first");
      return;
    }

    setLoading(true);
    setStatus(null);
    setError(null);

    try {
      // Get familyId from parent document
      const db = firestore();
      const parentRef = collection(db, "parents");
      const q = query(parentRef, where("email", "==", user.email));
      const querySnapshot = await getDocs(q);

      if (querySnapshot.empty) {
        throw new Error("Parent record not found");
      }

      const familyId = querySnapshot.docs[0].data().familyId;

      // Call the fix migration cloud function
      const functions = firebaseFunctions();
      const fixMigrationDateFormats = httpsCallable(functions, "fixMigrationDateFormats");

      const result = await fixMigrationDateFormats({ familyId });

      setStatus(`✅ ${(result.data as any).message}`);
    } catch (err: any) {
      setError(`❌ ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-page px-4 py-8">
      <div className="mx-auto max-w-2xl">
        <header className="mb-8">
          <h1 className="text-2xl font-bold text-ink">Fix Migration Date Formats</h1>
          <p className="mt-2 text-ink-secondary">
            Repairs date format issues in previously migrated data from iOS app.
          </p>
        </header>

        <div className="mb-6 rounded-xl border border-amber-200 bg-amber-50 p-6">
          <h2 className="text-lg font-semibold text-amber-900">⚠️ What This Does</h2>
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm text-amber-900">
            <li>Converts numeric timestamps to ISO8601 date strings</li>
            <li>Fixes <code>createdAt</code>, <code>updatedAt</code>, and <code>dateOfBirth</code> fields</li>
            <li>Allows iOS app to successfully parse the data</li>
            <li>Preserves all existing data (no data loss)</li>
          </ul>
        </div>

        {status && (
          <div className="mb-6 rounded-xl border border-emerald-200 bg-emerald-50 p-6">
            <p className="text-emerald-900">{status}</p>
          </div>
        )}

        {error && (
          <div className="mb-6 rounded-xl border border-red-200 bg-red-50 p-6">
            <p className="text-red-900">{error}</p>
          </div>
        )}

        <button
          onClick={handleFixMigration}
          disabled={loading}
          className="w-full rounded-xl bg-primary px-6 py-4 font-semibold text-white hover:bg-primary-dark disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? "Fixing..." : "Fix Migration Date Formats"}
        </button>

        <div className="mt-6 rounded-xl border border-blue-200 bg-blue-50 p-6">
          <h3 className="text-lg font-semibold text-blue-900">📋 Next Steps</h3>
          <ol className="mt-2 list-decimal space-y-2 pl-5 text-sm text-blue-900">
            <li>Click the button above to fix date formats</li>
            <li>Wait for success message</li>
            <li>On iOS app: tap Force Sync button ⟳</li>
            <li>Data should now appear correctly on iOS</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
