'use client';
import { useCallback, useEffect, useRef, useState } from 'react';
import { api } from '@/lib/client';

type State<T> = { path: string; data?: T; error?: string; updatedAt?: Date };

/**
 * Loads `path` now and every `intervalMs` while the tab is visible. A failed refresh keeps the last
 * data on screen and sets `error` until the next success. State is kept per path, so switching the
 * inbox filter never shows the previous filter's rows.
 */
export function usePolling<T>(path: string, intervalMs: number) {
  const [state, setState] = useState<State<T>>({ path });
  const current = useRef(path);

  const load = useCallback(async () => {
    try {
      const data = await api<T>(path);
      if (current.current === path) setState({ path, data, updatedAt: new Date() });
    } catch (e) {
      const error = e instanceof Error ? e.message : 'request_failed';
      if (current.current === path) setState((s) => ({ ...(s.path === path ? s : { path }), error }));
    }
  }, [path]);

  useEffect(() => {
    current.current = path;
    void load();
    const timer = setInterval(() => {
      if (!document.hidden) void load();
    }, intervalMs);
    return () => clearInterval(timer);
  }, [path, intervalMs, load]);

  const mine: State<T> = state.path === path ? state : { path };
  return { data: mine.data, error: mine.error, updatedAt: mine.updatedAt, reload: load };
}
