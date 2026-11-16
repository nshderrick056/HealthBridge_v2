// Admin pages: what the API's /admin routes return, and the helpers the forms share.

export type ResetRequest = {
  id: string;
  userId: string;
  name: string | null;
  phone: string | null;
  role: string | null;
  createdAt: string | null;
};

export type Centre = { id: string; name: string; district: string | null };

/** 0788 123 456, 250788123456 or +250788123456 → +250788123456; null when it is not a phone number. */
export function normalizePhone(input: string): string | null {
  const s = input.replace(/[\s().-]/g, '');
  const intl = s.startsWith('+') ? s : s.startsWith('250') ? `+${s}` : s.startsWith('0') ? `+250${s.slice(1)}` : s;
  return /^\+\d{9,15}$/.test(intl) ? intl : null;
}

/** The API's admin error codes, in words an admin can act on. */
export const ADMIN_ERRORS: Record<string, string> = {
  sms_failed: 'The SMS could not be sent, so nothing changed. Approve again once SMS works.',
  not_pending: 'Someone already handled this request.',
  user_inactive: 'This account is switched off, so it cannot be reset.',
  not_found: 'This request no longer exists.',
  unknown_health_center: 'That health centre no longer exists. Pick another.',
  phone_or_email_taken: 'An account already uses this phone number or email.',
  invalid_request: 'Some details are missing or not in the right format.',
  forbidden: 'This account is not an admin.',
  api_unreachable: 'Cannot reach the HealthBridge server. Check your connection and try again.',
};

export const errorText = (code: string) => ADMIN_ERRORS[code] ?? 'Could not save. Try again.';
