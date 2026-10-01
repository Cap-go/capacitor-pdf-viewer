export type PdfSourceKind = 'file' | 'path' | 'url' | 'base64';

/**
 * Infer how a PDF `source` string should be interpreted when the caller omits `sourceType`.
 */
export function inferSourceType(source: string): PdfSourceKind {
  const trimmed = source.trim();
  if (trimmed.toLowerCase().startsWith('data:')) {
    return 'base64';
  }
  if (/^https?:\/\//i.test(trimmed)) {
    return 'url';
  }
  if (!trimmed.includes('://') && looksLikeBase64(trimmed)) {
    return 'base64';
  }
  return 'file';
}

/**
 * Heuristic check for raw base64 payloads (not `data:` URIs).
 */
export function looksLikeBase64(value: string): boolean {
  const compact = value.replace(/\s+/g, '');
  return compact.length > 32 && /^[A-Za-z0-9+/=]+$/.test(compact);
}

/**
 * Resolve a PDF source to a browser blob URL. Call `revoke` when the viewer closes.
 */
export async function sourceToBlobUrl(
  source: string,
  sourceType: PdfSourceKind,
  headers?: Record<string, string>,
): Promise<{ blobUrl: string; revoke: () => void }> {
  if (sourceType === 'url') {
    const response = await fetch(source, { headers });
    if (!response.ok) {
      throw new Error(`Failed to download PDF (${response.status})`);
    }
    const blob = await response.blob();
    const blobUrl = URL.createObjectURL(blob);
    return { blobUrl, revoke: () => URL.revokeObjectURL(blobUrl) };
  }

  if (sourceType === 'base64') {
    const base64 = source.startsWith('data:') ? (source.split(',')[1] ?? '') : source.replace(/\s+/g, '');
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    const blob = new Blob([bytes], { type: 'application/pdf' });
    const blobUrl = URL.createObjectURL(blob);
    return { blobUrl, revoke: () => URL.revokeObjectURL(blobUrl) };
  }

  return { blobUrl: source, revoke: () => undefined };
}
