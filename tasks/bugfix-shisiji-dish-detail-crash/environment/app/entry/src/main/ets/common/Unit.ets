// 通用单位工具：金额/数值格式化（元=分/100，避免各模块重复实现）

// 分 → 元字符串：3500 → "35"，3599 → "35.99"
export function formatPrice(cents: number): string {
  const yuan = cents / 100;
  return Number.isInteger(yuan) ? String(yuan) : yuan.toFixed(2);
}