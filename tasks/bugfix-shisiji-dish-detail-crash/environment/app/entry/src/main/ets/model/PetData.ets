// 宠物领养数据模型与假数据：暖爪之家救助站。
// 类型安全、瀑布流卡片高度用 heightFactor 区分、视觉用 emoji + 渐变占位。

export type PetSpecies = 'dog' | 'cat' | 'other';

export interface Pet {
  id: string;
  name: string;            // 团团 / 豆包…
  species: PetSpecies;
  breed: string;           // 中华田园犬 / 布偶猫…
  ageMonths: number;
  gender: '公' | '母';
  vaccinated: boolean;     // 已接种
  neutered: boolean;       // 已绝育
  tags: string[];          // 亲人 / 活泼 / 会握手…
  story: string;           // 一小段身世故事
  location: string;        // 救助站分站
  heightFactor: number;    // 瀑布流卡片图片高度系数（1.0 / 1.22 / 1.44 错落）
  star: boolean;           // 是否进「本周领养之星」池
  imageKey: string;        // 视觉占位键
  gradient: number;        // 渐变索引
}

export interface SpeciesFilter {
  id: string;
  name: string;
}

export const SPECIES_FILTERS: SpeciesFilter[] = [
  { id: 'all', name: '全部' },
  { id: 'dog', name: '狗狗' },
  { id: 'cat', name: '猫咪' },
  { id: 'other', name: '异宠' }
];

// 视觉占位：渐变色板（桃粉系 + 暖灰/青绿点缀）+ emoji
export const PET_GRADIENTS: string[][] = [
  ['#FFC9D8', '#E86A92'], // 桃粉
  ['#FFD9A8', '#F0A24B'], // 暖橘
  ['#C8B6F0', '#8A6BE8'], // 淡紫
  ['#A8D8C8', '#3E8F7A'], // 青绿
  ['#B8C8E8', '#5B7AB8']  // 雾蓝
];

export function petEmoji(key: string): string {
  switch (key) {
    case 'xhuang': return '🐕';
    case 'ragdoll': return '🐱';
    case 'orange': return '🐈';
    case 'lab': return '🦮';
    case 'calico': return '🐈‍⬛';
    case 'samoyed': return '🐕‍🦺';
    case 'shorthair': return '🐱';
    case 'poodle': return '🐩';
    case 'rabbit': return '🐰';
    default: return '🐾';
  }
}

export const PETS: Pet[] = [
  {
    id: 'pet-xhuang', name: '小黄', species: 'dog', breed: '中华田园犬', ageMonths: 10, gender: '公',
    vaccinated: true, neutered: true, tags: ['亲人', '活泼', '护家'], story: '被遗弃在桥洞下，捡到时冻得发抖；现在追着球能跑一下午，看家护院一把好手。',
    location: '暖爪之家 · 南站分站', heightFactor: 1.22, star: true, imageKey: 'xhuang', gradient: 1
  },
  {
    id: 'pet-ragdoll', name: '团团', species: 'cat', breed: '布偶猫', ageMonths: 14, gender: '母',
    vaccinated: true, neutered: true, tags: ['安静', '黏人', '已剪指甲'], story: '主人出国后寄养未归，性格温顺，喜欢趴在人腿上打呼噜，适合安静家庭。',
    location: '暖爪之家 · 中心站', heightFactor: 1.0, star: true, imageKey: 'ragdoll', gradient: 0
  },
  {
    id: 'pet-orange', name: '橘座', species: 'cat', breed: '橘猫', ageMonths: 24, gender: '公',
    vaccinated: true, neutered: true, tags: ['能吃', '胆大', '会开门'], story: '小区团宠，靠一身膘打遍三猫；胖归胖，身手还是可以的。',
    location: '暖爪之家 · 东城站', heightFactor: 1.44, star: true, imageKey: 'orange', gradient: 1
  },
  {
    id: 'pet-lab', name: '可乐', species: 'dog', breed: '拉布拉多', ageMonths: 20, gender: '母',
    vaccinated: true, neutered: false, tags: ['温和', '训练过', '小孩子友好'], story: '原主人病故，部队退休犬训导员救下；握手坐卧都会，是理想的家庭犬。',
    location: '暖爪之家 · 中心站', heightFactor: 1.0, star: true, imageKey: 'lab', gradient: 3
  },
  {
    id: 'pet-calico', name: '三花', species: 'cat', breed: '三花猫', ageMonths: 8, gender: '母',
    vaccinated: true, neutered: true, tags: ['机灵', '活泼'], story: '路边捡到的小流浪，眼睛大大的，最爱玩逗猫棒。',
    location: '暖爪之家 · 南站分站', heightFactor: 1.22, star: true, imageKey: 'calico', gradient: 0
  },
  {
    id: 'pet-samoyed', name: '年糕', species: 'dog', breed: '萨摩耶', ageMonths: 30, gender: '公',
    vaccinated: true, neutered: false, tags: ['微笑天使', '掉毛预警'], story: '微笑天使的笑脸背后是被再次弃养的心酸；它值得一个不抛弃的家。',
    location: '暖爪之家 · 北郊站', heightFactor: 1.44, star: false, imageKey: 'samoyed', gradient: 4
  },
  {
    id: 'pet-shorthair', name: '煤球', species: 'cat', breed: '英国短毛猫', ageMonths: 16, gender: '母',
    vaccinated: true, neutered: true, tags: ['短毛', '安静', '低敏'], story: '原家搬离被留下；适应快、不掉毛严重，适合第一次养猫的人。',
    location: '暖爪之家 · 中心站', heightFactor: 1.0, star: false, imageKey: 'shorthair', gradient: 2
  },
  {
    id: 'pet-poodle', name: '豆包', species: 'dog', breed: '泰迪', ageMonths: 36, gender: '公',
    vaccinated: true, neutered: true, tags: ['聪明', '黏人', '不掉毛'], story: '听话懂事的小卷毛，会做许多小把戏，想要一个可靠的养老家庭。',
    location: '暖爪之家 · 东城站', heightFactor: 1.22, star: true, imageKey: 'poodle', gradient: 0
  },
  {
    id: 'pet-rabbit', name: '芝麻', species: 'other', breed: '垂耳兔', ageMonths: 12, gender: '公',
    vaccinated: true, neutered: true, tags: ['安静', '吃草很乖'], story: '被合租室友弃养；性格温驯，笼养即可，散养需看好电线。',
    location: '暖爪之家 · 北郊站', heightFactor: 1.0, star: false, imageKey: 'rabbit', gradient: 3
  }
];

export function petById(id: string): Pet {
  for (const p of PETS) {
    if (p.id === id) {
      return p;
    }
  }
  return PETS[0];
}

// 本周之星池：标记 star 的宠物（页面按"天"轮换出当天的主推）
export function starPool(): Pet[] {
  return PETS.filter((p: Pet) => p.star === true);
}

// 物种筛选
export function filterPets(speciesId: string): Pet[] {
  return PETS.filter((p: Pet) => speciesId === 'all' || p.species === speciesId);
}

// 当前"领养申请表"意向宠物 id（页面跳转前写入，同理 hotel 的 tourRoomId）
export let adoptPetId: string = '';

export function setAdoptPetId(id: string): void {
  adoptPetId = id;
}