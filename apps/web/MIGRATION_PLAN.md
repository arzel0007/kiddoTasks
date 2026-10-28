# Data Sync Migration Plan

## Objective

Sync data between web app and iOS app with the following requirements:

- **Points**: Keep webapp version (more updated)
- **Tasks**: Keep iOS app version (has updated tasks/icons/etc.)
- **Retain all other data**: Completions, rewards, claims, transactions, children

## Data Conflict Resolution Strategy

| Data Type | Source of Truth | Strategy |
|-----------|----------------|----------|
| **Points (Child.activePoints)** | Webapp | Copy from webapp Firestore |
| **Points Earned (Child.totalPointsEarned)** | Webapp | Copy from webapp Firestore |
| **Transactions** | Webapp | Copy from webapp Firestore |
| **Tasks** | iOS App | Copy from iOS app (has latest icons/descriptions) |
| **Task Completions** | Webapp | Keep webapp version (authoritative) |
| **Rewards** | iOS App | Copy from iOS app (latest state) |
| **Reward Claims** | Webapp | Keep webapp version |
| **Children** | iOS App | Copy from iOS app (latest icons/avatars) |

## Migration Steps

### Step 1: Backup Current Data

Before making any changes, export current data from Firestore:

```bash
# Export webapp data
gcloud firestore export gs://kiddotasks-app.appspot.com/backup/web-app-data --project=kiddotasks-app

# Export iOS app data (if accessible separately)
gcloud firestore export gs://kiddotasks-app.appspot.com/backup/ios-app-data --project=kiddotasks-app
```

### Step 2: Identify Data Sources

You need to determine which app has the most current data for each collection:

1. **Webapp data**: Check Firestore console for `children` collections - look at `updatedAt` timestamps
2. **iOS app data**: Export from iOS app using `LocalFamilyDataStore.currentSnapshot()` method

### Step 3: Migration Script

Run this script to merge data correctly:

```typescript
// apps/web/src/lib/migrate-data.ts
// This script should be run once in a controlled environment

export async function mergeDataFromIOS(
  iosSnapshot: FamilySnapshot
): Promise<void> {
  // Step 1: Preserve webapp points and transactions
  const webappChildren = await getWebappChildren();
  const webappTransactions = await getWebappTransactions();
  
  // Step 2: Import iOS tasks (overwrite webapp tasks)
  const iosTasks = iosSnapshot.tasks;
  
  // Step 3: Import iOS rewards (overwrite webapp rewards)
  const iosRewards = iosSnapshot.rewards;
  
  // Step 4: Import iOS children icons/avatars (but keep points from webapp)
  const iosChildrenMap = new Map(iosSnapshot.children.map(c => [c.id, c]));
  
  // Step 5: Merge into Firestore
  const db = firestore();
  await db.runTransaction(async (tx) => {
    // Update tasks
    for (const task of iosTasks) {
      tx.set(doc(db, "tasks", task.id), {
        ...task,
        updatedAt: new Date().toISOString()
      });
    }
    
    // Update rewards
    for (const reward of iosRewards) {
      tx.set(doc(db, "rewards", reward.id), {
        ...reward,
        updatedAt: new Date().toISOString()
      });
    }
    
    // Update children - keep webapp points, update icons
    for (const child of webappChildren) {
      const iosChild = iosChildrenMap.get(child.id);
      if (iosChild) {
        tx.update(doc(db, "children", child.id), {
          avatar: iosChild.avatar,
          photoData: iosChild.photoData,
          photoURL: iosChild.photoURL,
          updatedAt: new Date().toISOString()
        });
      }
    }
    
    // Update tasks that have new recurrence configurations
    // (e.g., weekdays field)
  });
}
```

### Step 4: Run Manual Merge

1. **Export iOS data**:
   - Open iOS app
   - Go to developer console/debug mode
   - Call `store.currentSnapshot()` to export family data
   - Copy the JSON output

2. **Create migration admin page**:
   - Add a new route `/admin/migrate-data` in the webapp
   - Paste the iOS JSON data
   - Click "Merge Data" button
   - Script will merge according to the strategy above

3. **Verify migration**:
   - Check webapp shows correct points
   - Check webapp shows iOS tasks with icons
   - Check iOS app pulls updated tasks
   - Verify no data loss

## Implementation Details

### Firestore Collections to Update

1. **tasks**: Replace with iOS version (preserves icons, descriptions)
2. **rewards**: Replace with iOS version (preserves latest state)
3. **children**: Update avatar/photo fields only, keep points
4. **taskCompletions**: Keep webapp version (authoritative)
5. **pointTransactions**: Keep webapp version (authoritative)
6. **rewardClaims**: Keep webapp version

### Post-Migration Steps

1. **Test on both platforms**:
   - Webapp: Verify tasks, points, completions all correct
   - iOS: Sync and verify data matches

2. **Monitor for 24 hours**:
   - Check Firestore for any sync conflicts
   - Verify notifications fire correctly

3. **Rollback plan** (if needed):
   - Use the backup created in Step 1
   - Run: `gcloud firestore restore gs://kiddotasks-app.appspot.com/backup/web-app-data`

## Code Changes Made

### Type Alignment

Updated `apps/web/src/lib/types.ts` to match iOS models:

```typescript
// KiddoTask - recurrence is now required (matches iOS default)
recurrence: { type: TaskRecurrenceType; weekdays?: number[] };

// TaskCompletion - added missing fields
approvedBy?: string | null;
pointTransactionId?: string | null;

// RewardClaim - added missing fields
REDEEMED status;
approvedBy?: string | null;
pointDeductionTransactionId?: string | null;

// PointTransaction - added audit trail fields
relatedId?: string;
createdBy?: string;
isReversed?: boolean;
reversalTransactionId?: string;
```

## Testing Checklist

- [ ] Webapp points match current balance
- [ ] iOS tasks appear in webapp with correct icons
- [ ] Webapp tasks appear in iOS with correct recurrence
- [ ] Completions sync correctly across platforms
- [ ] Rewards can be claimed from both platforms
- [ ] Points deduction works on both platforms
- [ ] Notifications fire on both platforms
