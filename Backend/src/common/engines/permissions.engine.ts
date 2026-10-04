// Роли и права сквадов/сессий. Чистая логика для unit-тестов.

export type SquadRole = 'Owner' | 'Admin' | 'Member';

const RANK: Record<SquadRole, number> = { Owner: 3, Admin: 2, Member: 1 };

/** Может ли actor с ролью actorRole выполнить действие, требующее minRole. */
export function hasRole(actorRole: SquadRole, minRole: SquadRole): boolean {
  return (RANK[actorRole] ?? 0) >= (RANK[minRole] ?? 0);
}

/** Может ли кикнуть: кикающий строго старше цели, цель не Owner (кроме само-действий). */
export function canKick(kicker: SquadRole, target: SquadRole): boolean {
  if (target === 'Owner') return false;
  return (RANK[kicker] ?? 0) > (RANK[target] ?? 0);
}

/** Проверка лимита сквада (макс 200 участников). */
export function canJoinSquad(memberCount: number, max = 200): boolean {
  return memberCount < max;
}

export type AdminCapability = 'economy' | 'moderation' | 'content' | 'users' | 'server' | 'beta';

/**
 * Права admin API: grant/revoke экономики и выдача бейджей — только admin.
 * Обычный user на этих эндпоинтах получает 403 (см. AdminGuard + badges 403).
 */
export function canUseAdminApi(isAdmin: boolean): boolean {
  return isAdmin === true;
}

/** Может ли actor выдавать бейджи/награды (только admin). */
export function canAwardBadge(isAdmin: boolean): boolean {
  return isAdmin === true;
}

/** Может ли actor проводить операции экономики (grant/revoke — только admin). */
export function canTouchEconomy(isAdmin: boolean): boolean {
  return isAdmin === true;
}

// ---- Tier1: invite/message/profile с учётом block + privacy ----

export type PrivacyScope = 'everyone' | 'friends' | 'nobody';

export interface InvitePrivacy {
  invites?: PrivacyScope;
}

export interface MessagePrivacy {
  messages?: PrivacyScope;
}

export interface ProfilePrivacy {
  profile?: PrivacyScope;
}

function scopeAllows(scope: PrivacyScope | undefined, areFriends: boolean): boolean {
  const s = scope ?? 'everyone';
  if (s === 'nobody') return false;
  if (s === 'friends') return areFriends === true;
  return true;
}

/** Можно ли приглашать: блок запрещает всё, дальше — privacy цели. */
export function canInvite(opts: {
  blocked?: boolean;
  areFriends?: boolean;
  targetPrivacy?: InvitePrivacy;
}): boolean {
  if (opts.blocked) return false;
  return scopeAllows(opts.targetPrivacy?.invites, opts.areFriends ?? false);
}

/** Можно ли писать: блок запрещает всё, дальше — privacy цели. */
export function canMessage(opts: {
  blocked?: boolean;
  areFriends?: boolean;
  targetPrivacy?: MessagePrivacy;
}): boolean {
  if (opts.blocked) return false;
  return scopeAllows(opts.targetPrivacy?.messages, opts.areFriends ?? false);
}

/** Виден ли профиль: блок скрывает всё, дальше — privacy цели. */
export function canSeeProfile(opts: {
  blocked?: boolean;
  areFriends?: boolean;
  targetPrivacy?: ProfilePrivacy;
}): boolean {
  if (opts.blocked) return false;
  return scopeAllows(opts.targetPrivacy?.profile, opts.areFriends ?? false);
}
