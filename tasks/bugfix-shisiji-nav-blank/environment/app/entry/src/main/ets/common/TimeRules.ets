// 时间引擎：四模块共用的"活内容"纯函数调度器（时/天 → 选中项）
// 只做计算、不依赖组件，可被任意页面安全复用；档位表由各模块自行定义（见各 model 文件）。

export interface HourSlot {
  from: number;   // 起始小时（含）
  to: number;     // 结束小时（不含）
  label: string;  // 档位文案，如「午市」「晚市」
}

// 当前小时（0-23）
export function nowHour(): number {
  return new Date().getHours();
}

// 当前小时落在哪个档位；无匹配时回落第一档（档位表应尽量覆盖全天）
export function hourLabel(slots: HourSlot[], hour: number): string {
  for (const s of slots) {
    if (hour >= s.from && hour < s.to) {
      return s.label;
    }
  }
  return slots.length === 0 ? '' : slots[0].label;
}

// 按时段从池子里轮换选出 count 项：偏移量由当前小时驱动，同一小时稳定、跨小时滑动
export function pickHourly<T>(pool: T[], hour: number, count: number): T[] {
  const n = pool.length;
  if (n === 0) {
    return [];
  }
  const off = hour % n;
  const r: T[] = [];
  for (let i = 0; i < count; i++) {
    r.push(pool[(off + i) % n]);
  }
  return r;
}

// 绝对"日"序号（跨年单调递增），供按天轮换使用
export function dayIndex(): number {
  const d = new Date();
  return d.getFullYear() * 366 + d.getMonth() * 31 + d.getDate();
}

// 按天从池子里轮换选出 count 项（宠物之星 / 每日荐书共用）
export function pickDaily<T>(pool: T[], day: number, count: number): T[] {
  const n = pool.length;
  if (n === 0) {
    return [];
  }
  const off = day % n;
  const r: T[] = [];
  for (let i = 0; i < count; i++) {
    r.push(pool[(off + i) % n]);
  }
  return r;
}

// 今天星期几的中文文案（0=周日）
export function weekdayLabel(): string {
  const names: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return names[new Date().getDay()];
}