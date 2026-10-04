// Pre-registered admin deviceIds: ENV ADMIN_DEVICE_IDS (comma-separated)
// + in-memory реестр (POST /admin/devices под X-Admin-Token).

const memory = new Set<string>();

export function registeredDeviceIds(): string[] {
  const fromEnv = (process.env.ADMIN_DEVICE_IDS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return [...new Set([...fromEnv, ...memory])];
}

export function isDeviceRegistered(deviceId: unknown): boolean {
  if (typeof deviceId !== 'string' || !deviceId) return false;
  return registeredDeviceIds().includes(deviceId);
}

export function registerDevice(deviceId: string): { deviceId: string; registered: boolean } {
  if (!deviceId || typeof deviceId !== 'string') throw new Error('deviceId required');
  memory.add(deviceId);
  return { deviceId, registered: true };
}
