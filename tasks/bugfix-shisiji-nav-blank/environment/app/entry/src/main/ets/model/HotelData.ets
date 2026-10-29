// 酒店房型数据模型与假数据：云栖酒店。
// 类型安全、金额以「分」存整数；视觉用 emoji + 渐变占位（可后续替换真实房型照）。

import { HourSlot } from '../common/TimeRules';

export type RoomType = 'standard' | 'deluxe' | 'suite';

export interface Room {
  id: string;
  name: string;            // 湖景大床房 / 山景标准间…
  type: RoomType;
  priceCents: number;      // 门市价（分）
  special: boolean;        // 是否进「今日特价」池（是否被今天的特价轮换选中由页面用 TimeRules 算）
  area: number;            // ㎡
  floor: string;           // 楼层/朝向：5F 朝湖
  beds: string;            // 1.8m×1 / 1.5m×2…
  capacity: number;        // 可住人数
  breakfast: boolean;      // 是否含早
  tags: string[];          // 湖景 / 落地窗 / 浴缸…
  sales: number;           // 近 30 日售出
  imageKey: string;        // 视觉占位键
  gradient: number;        // 渐变索引
}

// 筛选维度：房型 / 价格档
export interface PriceBand {
  id: string;
  name: string;
  minCents: number;
  maxCents: number;        // 不含上限
}

// 房型筛选选项（"全部"走 'all'）
export interface TypeFilter {
  id: string;
  name: string;
}

export const TYPE_FILTERS: TypeFilter[] = [
  { id: 'all', name: '全部' },
  { id: 'standard', name: '标准' },
  { id: 'deluxe', name: '豪华' },
  { id: 'suite', name: '套房' }
];

export const PRICE_BANDS: PriceBand[] = [
  { id: 'all', name: '全部', minCents: 0, maxCents: Number.MAX_SAFE_INTEGER },
  { id: 'p-lite', name: '¥600以下', minCents: 0, maxCents: 60000 },
  { id: 'p-mid', name: '¥600-1000', minCents: 60000, maxCents: 100000 },
  { id: 'p-lux', name: '¥1000+', minCents: 100000, maxCents: Number.MAX_SAFE_INTEGER }
];

// 视觉占位：渐变底 + 大号 emoji（深蓝系，贴合"湖畔山居"调性）
export const HOTEL_GRADIENTS: string[][] = [
  ['#B8D8F0', '#2A5F9E'], // 湖蓝
  ['#A7C6E8', '#3C78B7'], // 天蓝
  ['#8FC0D8', '#2E6E9E'], // 深湖
  ['#A9D8C8', '#3E8F7A']  // 庭院青
];

export function roomEmoji(key: string): string {
  switch (key) {
    case 'mountain': return '🏞️';
    case 'lakewave': return '🛏️';
    case 'garden': return '🌳';
    case 'lakeview': return '🌅';
    case 'alpine': return '🏔️';
    case 'family': return '👨‍👩‍👧‍👦';
    case 'lounge': return '🛋️';
    case 'cloud': return '☁️';
    case 'courtyard': return '🏡';
    default: return '🏨';
  }
}

export const ROOMS: Room[] = [
  {
    id: 'room-mountain-std', name: '山景标准间', type: 'standard', priceCents: 68800,
    special: false, area: 32, floor: '3-6F · 朝山', beds: '1.8m × 1', capacity: 2, breakfast: false,
    tags: ['山景', '独立卫浴'], sales: 320, imageKey: 'mountain', gradient: 2
  },
  {
    id: 'room-lake-big', name: '湖景大床房', type: 'standard', priceCents: 78800,
    special: true, area: 38, floor: '5-9F · 朝湖', beds: '1.8m × 1', capacity: 2, breakfast: true,
    tags: ['湖景', '落地窗'], sales: 410, imageKey: 'lakewave', gradient: 0
  },
  {
    id: 'room-garden-twin', name: '园景双床房', type: 'standard', priceCents: 58800,
    special: false, area: 30, floor: '2F · 朝园', beds: '1.2m × 2', capacity: 2, breakfast: false,
    tags: ['园景', '安静'], sales: 230, imageKey: 'garden', gradient: 3
  },
  {
    id: 'room-lake-lux', name: '湖景豪华大床房', type: 'deluxe', priceCents: 98800,
    special: true, area: 45, floor: '10-12F · 朝湖', beds: '1.8m × 1', capacity: 2, breakfast: true,
    tags: ['湖景', '智能客房', '浴缸'], sales: 300, imageKey: 'lakeview', gradient: 0
  },
  {
    id: 'room-alpine-twin', name: '山景尊享双床房', type: 'deluxe', priceCents: 88800,
    special: false, area: 42, floor: '7-11F · 朝山', beds: '1.35m × 2', capacity: 3, breakfast: true,
    tags: ['山景', '观景阳台'], sales: 210, imageKey: 'alpine', gradient: 1
  },
  {
    id: 'room-family', name: '家庭亲子房', type: 'deluxe', priceCents: 108800,
    special: true, area: 52, floor: '3-4F · 朝园', beds: '1.8m + 1.2m', capacity: 4, breakfast: true,
    tags: ['亲子', '儿童床', '可加床'], sales: 180, imageKey: 'family', gradient: 3
  },
  {
    id: 'room-suite', name: '行政套房', type: 'suite', priceCents: 158800,
    special: false, area: 68, floor: '12F · 朝湖', beds: '1.8m × 1', capacity: 2, breakfast: true,
    tags: ['客厅分离', '行政酒廊'], sales: 95, imageKey: 'lounge', gradient: 0
  },
  {
    id: 'room-cloud', name: '云顶观景套房', type: 'suite', priceCents: 208800,
    special: true, area: 80, floor: '顶层 · 全景', beds: '1.8m × 1', capacity: 2, breakfast: true,
    tags: ['顶层', '全景落地窗', '双浴缸'], sales: 60, imageKey: 'cloud', gradient: 1
  },
  {
    id: 'room-courtyard', name: '湖畔独栋小院', type: 'suite', priceCents: 268800,
    special: false, area: 120, floor: '湖岸边', beds: '1.8m × 2', capacity: 4, breakfast: true,
    tags: ['独栋', '私家院子', '温泉'], sales: 35, imageKey: 'courtyard', gradient: 3
  }
];

export function roomById(id: string): Room {
  for (const r of ROOMS) {
    if (r.id === id) {
      return r;
    }
  }
  return ROOMS[0];
}

// 今日特价池：所有标记 special 的房型（页面再按小时轮换出其中 2 间作为"当前特价"）
export function specialPool(): Room[] {
  return ROOMS.filter((r: Room) => r.special === true);
}

// 筛选：房型 + 价格档 → 过滤结果（纯函数，页面维护两个选中态即可复用）
export function filterRooms(typeId: string, bandId: string): Room[] {
  let band: PriceBand = PRICE_BANDS[0];
  for (const b of PRICE_BANDS) {
    if (b.id === bandId) {
      band = b;
    }
  }
  return ROOMS.filter((r: Room) =>
    (typeId === 'all' || r.type === typeId) &&
    r.priceCents >= band.minCents && r.priceCents < band.maxCents);
}

// 今日特价档位表（覆盖全天）
export const HOTEL_SLOTS: HourSlot[] = [
  { from: 0, to: 6, label: '深夜价' },
  { from: 6, to: 11, label: '晨间价' },
  { from: 11, to: 17, label: '日间价' },
  { from: 17, to: 22, label: '傍晚价' },
  { from: 22, to: 24, label: '夜用价' }
];

// 当前"全景看房"目标房型 id：页面跳转时先写入再 push（渲染只读），
// 避免 NavPathStack 参数数组在 ArkTS 严格模式下的类型转换开销。
export let tourRoomId: string = '';

export function setTourRoomId(id: string): void {
  tourRoomId = id;
}