import { useEffect, useRef } from 'react';

const isDebug = typeof (window as any).GetParentResourceName !== 'function';

if (isDebug) {
  document.body.style.background = 'rgba(0, 0, 0, 0.6)';
}

export { isDebug };

export function debugNuiEvent(action: string, data: unknown) {
  window.dispatchEvent(new MessageEvent('message', { data: { action, data } }));
}

export function useNuiEvent<T = unknown>(action: string, handler: (data: T) => void) {
  const savedHandler = useRef(handler);
  useEffect(() => { savedHandler.current = handler; }, [handler]);
  useEffect(() => {
    function eventListener(event: MessageEvent) {
      let payload = event.data;
      if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch {} }
      const { action: eventAction, data } = payload ?? {};
      if (eventAction === action) savedHandler.current((data ?? {}) as T);
    }
    window.addEventListener('message', eventListener);
    return () => window.removeEventListener('message', eventListener);
  }, [action]);
}

export async function fetchNui<T = unknown>(
  eventName: string,
  data: Record<string, unknown> = {},
  mockData?: T
): Promise<T> {
  if (isDebug && mockData !== undefined) {
    console.log(`[NUI Dev] ${eventName}:`, mockData);
    return mockData;
  }
  if (isDebug) {
    console.warn(`[NUI Dev] No mock for '${eventName}'. Pass mockData as 3rd arg.`);
    return {} as T;
  }
  const resourceName = (window as any).GetParentResourceName();
  const response = await fetch(`https://${resourceName}/${eventName}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  const text = await response.text();
  if (!text) return {} as T;
  try {
    return JSON.parse(text) as T;
  } catch {
    return text as T;
  }
}

if (isDebug) {
  setTimeout(() => debugNuiEvent('open', {}), 100);
}
