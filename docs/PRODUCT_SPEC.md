# Kiddotasks Product Specification

## Purpose

Kiddotasks helps families build chore routines that children can understand and
enjoy. Parents create and manage chores, approve completed work, and oversee
rewards. Children use a shared iPad to complete missions, watch points grow,
request rewards, and see their progress.

The app is designed for families who live on their phones: parents use iPhone,
children use a shared iPad, and all family activity stays synchronized.

## Product goals

- Make family setup fast: a parent account plus child names and avatars in under
  two minutes.
- Make chores clear: parents assign daily or weekly routines and point values.
- Make effort visible: children see missions, completion states, points, badges,
  and celebrations.
- Keep parents in control: approvals, rewards, complete activity history, and
  configurable notifications.
- Avoid child accounts: children have profiles and use a shared family PIN.
- Work across the household's devices with reliable real-time synchronization.

## Roles and access

### Parents

- Create and own a family account.
- Both parents have equal management permissions.
- Join the same family from additional parent phones using a family link.
- Receive configurable notifications for family activity.

### Children

- Have a profile with a name and avatar, but no email address or login account.
- Use the shared family PIN once to start a kids-iPad session.
- Can switch profiles on the shared iPad during an active session without
  entering the PIN again.
- Must enter the PIN again only after the family is logged out of the iPad.

## Parent Center

### Today

- Shows pending chore approvals, pending reward requests, and today's activity.
- Lets parents approve or decline chore submissions and reward claims.
- Shows repeat-submission counts and unusual same-day activity for review.

### Tasks

- Create, edit, assign, and archive chores.
- Configure point values, daily/weekly routines, and approval behavior.
- A chore can use the family approval default, always require approval, or
  auto-approve and award points.

### Rewards

- Create, edit, activate, and deactivate rewards.
- Every reward claim requires parent approval.
- Points are deducted only when a parent approves the claim.

### Family

- Add and edit child profiles and avatars.
- Change the shared kids PIN.
- Link parent phones and the kids' iPad.
- Configure notification preferences, seasonal themes, and the default chore
  approval policy.

### History

- Maintains a complete, timestamped family activity record.
- Includes submissions, approvals, declines with reasons, cancellations, point
  awards/deductions, and reward redemptions.

## Kids Station

### Missions

- Shows the selected child's scheduled missions.
- A child may submit a chore more than once in a day; no hard daily completion
  cap is imposed.
- Each submission is recorded separately, with its timestamp and status.
- A declined completion stays in history with the parent's reason and may be
  submitted again.

### Shop

- Shows active rewards that are eligible for the selected child.
- Children can submit and cancel a pending reward request.
- No points are spent until a parent approves the request.

### Badges and history

- Children can see their own achievements and full personal history, including
  declines and parent reasons, for transparency.

## Approval and anti-abuse rules

- The family setting **Require parent approval for chore completions** is enabled
  by default.
- Parents can override it per chore: use the family setting, always require
  approval, or auto-approve and award points.
- Parent approval protects repeatable chores from automatic point farming while
  preserving legitimate repeated submissions.
- History and parent-facing activity indicators make unusual repeat patterns
  visible; they do not silently limit children.

## Notifications and native iOS experience

- Parents receive all event notifications by default: submissions, approvals,
  declines, reward requests, cancellations, and unusual repeat activity.
- Each notification category can be enabled or disabled in settings.
- Home Screen widgets cover pending approvals, family points, and today's
  chores through configurable widget variants.
- Routine timers can be started by parents or children and will support Dynamic
  Island/Live Activity presentation.
- Seasonal themes can change automatically by date or be selected by parents.
- Completing missions can trigger kid-friendly confetti celebrations.

## Implementation roadmap

1. Stabilize the local SwiftUI prototype and complete the agreed parent/kid
   workflows.
2. Add secure Firebase Authentication, Firestore synchronization, family/device
   linking, and server-enforced approval and point transactions.
3. Add configurable notifications and parent activity monitoring.
4. Add widgets, Live Activities/Dynamic Island routine timers, seasonal themes,
   and celebrations.
5. Expand automated tests and validate the flows on parent iPhones and the
   shared kids' iPad.

## Decisions recorded

- Shared family PIN, not individual child PINs.
- Both parents are full managers.
- Children have profiles, not email accounts.
- The iPad session requires the PIN once, until family logout.
- Children may switch profiles without re-entering the PIN during that session.
- Children can cancel pending chore submissions and reward requests.
- Reward claims always require parent approval and deduct points only after
  approval.
- Chore approval uses a family default with individual chore overrides.
