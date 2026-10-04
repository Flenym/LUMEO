/**
 * Lumeo Shared contracts — enums.
 * TypeScript mirror of Swift Models (iOSApp/Sources).
 * Keep in sync with Swift: add case in both places.
 */

export type StatusColor = 'green' | 'yellow' | 'red';

export type Presence = 'online' | 'away' | 'offline';

export type SessionState =
  | 'Draft'
  | 'Inviting'
  | 'Waiting'
  | 'Ready'
  | 'Live'
  | 'Paused'
  | 'Finished'
  | 'Cancelled';

export type SessionRole = 'owner' | 'participant';

export type ParticipantState =
  | 'invited'
  | 'accepted'
  | 'declined'
  | 'ready'
  | 'not_ready'
  | 'away'
  | 'left';

export type SquadRole = 'Owner' | 'Admin' | 'Member';

export type ReportType =
  | 'spam'
  | 'harassment'
  | 'inappropriate_content'
  | 'impersonation'
  | 'cheating'
  | 'other';

export type BadgeType =
  | 'Developer'
  | 'Official'
  | 'Verified'
  | 'Sponsor'
  | 'BetaTester'
  | 'EarlyUser'
  | 'Founder';

export type WorkshopState =
  | 'Draft'
  | 'PendingModeration'
  | 'Published'
  | 'Rejected'
  | 'Archived';

export type SubscriptionPlan = 'Monthly' | 'SixMonths';

export type Locale = 'ru' | 'en';
