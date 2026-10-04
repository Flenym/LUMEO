/**
 * Lumeo Shared contracts — DTOs.
 * Mirror of Swift Models in iOSApp. Server (NestJS) is source of truth for shapes.
 */
import type {
  BadgeType,
  Locale,
  ParticipantState,
  Presence,
  ReportType,
  SessionRole,
  SessionState,
  SquadRole,
  StatusColor,
  SubscriptionPlan,
  WorkshopState,
} from './enums';

export interface ApiError {
  code: string;
  message: string;
  requestId: string;
}

export interface Paginated<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export interface UserDTO {
  id: string;
  username: string;
  displayName: string;
  avatarUrl?: string | null;
  presence: Presence;
  lastSeenAt?: string | null;
  badges: BadgeType[];
  level: number;
  rank: string;
  xp: number;
  locale: Locale;
  createdAt: string;
}

export interface FriendRequestDTO {
  id: string;
  fromUserId: string;
  toUserId: string;
  state: 'pending' | 'accepted' | 'declined' | 'expired';
  createdAt: string;
  decidedAt?: string | null;
}

export interface StatusDTO {
  userId: string;
  color: StatusColor;
  text: string;
  expiresAt?: string | null;
  updatedAt: string;
}

export interface GameDTO {
  id: string;
  name: string;
  slug: string;
  logoUrl?: string | null;
  iconUrl?: string | null;
  coverUrl?: string | null;
  color?: string | null;
  platforms: string[];
  modes: string[];
  status: 'active' | 'hidden' | 'archived';
}

export interface CreateSessionDTO {
  gameId: string;
  mode: string;
  maxPlayers: number;
  startsAt: string;
  comment?: string;
  invitedUserIds: string[];
}

export interface SessionParticipantDTO {
  userId: string;
  role: SessionRole;
  state: ParticipantState;
  joinedAt?: string | null;
}

export interface SessionDTO {
  id: string;
  gameId: string;
  mode: string;
  maxPlayers: number;
  startsAt: string;
  state: SessionState;
  ownerId: string;
  participants: SessionParticipantDTO[];
  chatId?: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface SquadDTO {
  id: string;
  name: string;
  avatarUrl?: string | null;
  description?: string | null;
  ownerId: string;
  memberCount: number;
  level: number;
  xp: number;
  streak: number;
  myRole?: SquadRole;
  createdAt: string;
}

/**
 * E2EE: server NEVER sees plaintext.
 * Only opaque ciphertext + metadata are transported/stored.
 * Admin App receives id/metadata/delivery/timestamps — never plaintext.
 */
export interface MessageMetadataDTO {
  id: string;
  chatId: string;
  senderId: string;
  /** Opaque E2EE ciphertext (base64). Server must not decrypt. */
  ciphertext: string;
  /** Key id / rotation epoch for device & session keys. */
  keyId: string;
  /** Nonce/IV as string (base64). */
  nonce: string;
  /** E.g. 'text' | 'image' | 'video' | 'voice' | 'system' — type only, no content. */
  kind: 'text' | 'image' | 'video' | 'voice' | 'gif' | 'system' | 'session_invite';
  replyToId?: string | null;
  createdAt: string;
  editedAt?: string | null;
  // NOTE: no `text` / `plaintext` field by design (E2EE).
}

export interface ProfileBlockDTO {
  id: string;
  type: 'identity' | 'text' | 'photo' | 'games' | 'achievements' | 'links' | 'streak' | 'custom';
  order: number;
  payload: Record<string, unknown>;
  removable: boolean;
}

export interface WorkshopItemDTO {
  id: string;
  title: string;
  description: string;
  previewUrl?: string | null;
  screenshots: string[];
  creatorId: string;
  version: string;
  priceEmber: number;
  category: string;
  language: Locale;
  compatibility: string[];
  state: WorkshopState;
  publishedAt?: string | null;
}

export interface WalletDTO {
  userId: string;
  /** Currency display name is configurable (default EMBER), amount is integer minor units. */
  balance: number;
  updatedAt: string;
}

export interface TransactionDTO {
  transactionId: string;
  fromUser?: string | null;
  toUser?: string | null;
  item?: string | null;
  amount: number;
  timestamp: string;
  status: 'pending' | 'completed' | 'failed' | 'refunded';
}

export interface NotificationDTO {
  id: string;
  userId: string;
  kind: string;
  title: string;
  body?: string | null;
  data?: Record<string, unknown>;
  readAt?: string | null;
  createdAt: string;
}

export interface ReportDTO {
  id: string;
  reporterId: string;
  targetUserId?: string | null;
  targetMessageId?: string | null;
  targetWorkshopId?: string | null;
  type: ReportType;
  /** Reports with same target/content are grouped for moderation. */
  clusterId: string;
  comment?: string | null;
  createdAt: string;
}

export interface VerificationDTO {
  userId: string;
  badge: BadgeType;
  grantedBy: string;
  reason?: string | null;
  grantedAt: string;
  revokedAt?: string | null;
}

export interface FeatureFlagDTO {
  key: string;
  enabled: boolean;
  updatedAt: string;
}

export interface SubscriptionDTO {
  userId: string;
  plan: SubscriptionPlan;
  active: boolean;
  expiresAt?: string | null;
}
