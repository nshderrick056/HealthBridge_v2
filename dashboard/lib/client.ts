// Browser side: every call goes to this app's /api/*, which adds the session token (lib/proxy.ts).

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api/${path}`, {
    ...init,
    headers: { 'content-type': 'application/json', ...init?.headers },
    cache: 'no-store',
  });
  if (res.status === 401) {
    window.location.assign('/login');
    throw new ApiError(401, 'unauthorized');
  }
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(res.status, (body as { error?: string }).error ?? 'request_failed');
  return body as T;
}
