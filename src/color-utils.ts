/**
 * Parse `#RRGGBB` or `#AARRGGBB` hex. Returns `null` when missing, invalid, or empty.
 */
export function parseCssHexColor(input: string | undefined): string | null {
  if (input == null) return null;
  const trimmed = input.trim();
  if (!trimmed) return null;
  const hex = trimmed.startsWith('#') ? trimmed.slice(1) : trimmed;
  if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(hex)) {
    return null;
  }
  return `#${hex.toLowerCase()}`;
}
