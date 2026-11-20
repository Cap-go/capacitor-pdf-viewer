/**
 * Parse plugin `#RRGGBB` or `#AARRGGBB` hex into a CSS color.
 * Eight-digit input uses Android or iOS ARGB order; CSS expects `#RRGGBBAA` or `rgba()`.
 * Returns `null` when missing, invalid, or empty.
 */
export function parseCssHexColor(input: string | undefined): string | null {
  if (input == null) return null;
  const trimmed = input.trim();
  if (!trimmed) return null;
  const hex = trimmed.startsWith('#') ? trimmed.slice(1) : trimmed;
  if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(hex)) {
    return null;
  }
  const lower = hex.toLowerCase();
  if (lower.length === 6) {
    return `#${lower}`;
  }
  const aa = lower.slice(0, 2);
  const rr = lower.slice(2, 4);
  const gg = lower.slice(4, 6);
  const bb = lower.slice(6, 8);
  return `#${rr}${gg}${bb}${aa}`;
}
