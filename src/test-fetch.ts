/**
 * Replace `globalThis.fetch` in tests while satisfying Bun's `fetch` type (includes `preconnect`).
 */
export function mockFetch(impl: (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>): typeof fetch {
  return impl as typeof fetch;
}
