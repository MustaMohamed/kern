export function applyDiscount(total, percent) {
  return Math.round(total * (1 - percent / 100) * 100) / 100;
}
