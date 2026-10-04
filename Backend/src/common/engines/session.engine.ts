// Чистая логика игровых сессий (state machine). Без Nest.

export type SessionState =
  | 'Draft'
  | 'Inviting'
  | 'Waiting'
  | 'Ready'
  | 'Live'
  | 'Paused'
  | 'Finished'
  | 'Cancelled';

const TRANSITIONS: Record<SessionState, SessionState[]> = {
  Draft: ['Inviting', 'Cancelled'],
  Inviting: ['Waiting', 'Cancelled'],
  Waiting: ['Ready', 'Cancelled'],
  Ready: ['Live', 'Cancelled'],
  Live: ['Paused', 'Finished', 'Cancelled'],
  Paused: ['Live', 'Finished', 'Cancelled'],
  Finished: [],
  Cancelled: [],
};

/** Разрешён ли переход from -> to. */
export function canTransition(from: SessionState, to: SessionState): boolean {
  return TRANSITIONS[from]?.includes(to) ?? false;
}

export interface SessionParticipant {
  userId: string;
  /** accepted | declined | pending | ready */
  status: string;
}

/** Сколько участников в статусе ready/accepted. */
export function readyCount(participants: SessionParticipant[]): number {
  return participants.filter((p) => p.status === 'ready' || p.status === 'accepted').length;
}

/** Можно ли стартовать: готовых >= minRequired (по умолчанию 2). */
export function isReadyToStart(participants: SessionParticipant[], minRequired = 2): boolean {
  return readyCount(participants) >= minRequired;
}
