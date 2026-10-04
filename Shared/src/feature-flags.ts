/**
 * Lumeo Shared — feature flags.
 * Server (Admin-managed) is source of truth at runtime;
 * these defaults are used for local dev / fallback / tests.
 */

export const FLAGS = [
  'public_player_search',
  'discord_login',
  'apple_login',
  'google_login',
  'phone_auth',
  'premium',
  'workshop_marketplace',
  'currency_purchases',
  'trading',
  'public_profiles',
  'live_activities',
  'widgets',
] as const;

export type FeatureFlagKey = (typeof FLAGS)[number];

export type FeatureFlagMap = Record<FeatureFlagKey, boolean>;

/** Defaults: everything OFF except widgets + live_activities (ТЗ §19–20 core). */
export const FEATURE_FLAG_DEFAULTS: FeatureFlagMap = {
  public_player_search: false,
  discord_login: false,
  apple_login: false,
  google_login: false,
  phone_auth: false,
  premium: false,
  workshop_marketplace: false,
  currency_purchases: false,
  trading: false,
  public_profiles: false,
  live_activities: true,
  widgets: true,
};

export function isFlagEnabled(map: Partial<FeatureFlagMap>, key: FeatureFlagKey): boolean {
  if (key in map && typeof map[key] === 'boolean') return map[key] as boolean;
  return FEATURE_FLAG_DEFAULTS[key];
}
