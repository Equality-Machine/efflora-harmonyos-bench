// 书单书架数据模型与假数据：拾光书局。
// 类型安全、星级 0-5 步进 0.5、阅读进度 0-100、视觉用 emoji + 渐变占位。

export interface Book {
  id: string;
  title: string;
  author: string;
  category: string;         // novel | history | tech | life
  rating: number;           // 0-5，0.5 步进
  progress: number;         // 阅读进度 0-100
  tags: string[];
  intro: string;
  quote: string;            // 荐书页一句摘抄
  recommend: boolean;       // 是否进「每日荐书」池
  imageKey: string;         // 视觉占位键
  gradient: number;         // 渐变索引
}

export interface BookCategory {
  id: string;
  name: string;
}

export const BOOK_CATEGORIES: BookCategory[] = [
  { id: 'all', name: '全部' },
  { id: 'novel', name: '小说' },
  { id: 'history', name: '历史' },
  { id: 'tech', name: '科技' },
  { id: 'life', name: '人文' }
];

// 视觉占位：渐变色板（墨绿系 + 点缀）+ emoji 封面意象
export const BOOK_GRADIENTS: string[][] = [
  ['#A8D8C0', '#2E6B4F'], // 墨绿
  ['#C8B6F0', '#6B4FA8'], // 深紫
  ['#E8C9A8', '#B87A4A'], // 陶棕
  ['#A8C8E8', '#4A6FA8'], // 靛蓝
  ['#EFD0A8', '#C97B3A']  // 暖橙
];

export function bookEmoji(key: string): string {
  switch (key) {
    case 'santi': return '🌌';
    case 'huozhe': return '🌾';
    case 'changan': return '🍈';
    case 'hundred': return '🗿';
    case 'wanli': return '🏯';
    case 'renlei': return '🌍';
    case 'wave': return '🌊';
    case 'clean': return '🧹';
    case 'prince': return '⭐';
    case 'moon': return '🌙';
    default: return '📖';
  }
}

export const BOOKS: Book[] = [
  {
    id: 'book-santi', title: '三体', author: '刘慈欣', category: 'novel', rating: 4.6, progress: 62,
    tags: ['科幻', '硬核'], intro: '地球文明向宇宙发出的第一声啼鸣，引来了三体文明的凝视。',
    quote: '给岁月以文明，而不是给文明以岁月。', recommend: true, imageKey: 'santi', gradient: 4
  },
  {
    id: 'book-huozhe', title: '活着', author: '余华', category: 'novel', rating: 4.7, progress: 15,
    tags: ['文学', '经典'], intro: '人是为活着本身而活着，而不是为了活着之外的任何事物。',
    quote: '少年去游荡，中年想掘藏，老年做和尚。', recommend: true, imageKey: 'huozhe', gradient: 1
  },
  {
    id: 'book-changan', title: '长安的荔枝', author: '马伯庸', category: 'novel', rating: 4.4, progress: 100,
    tags: ['历史小说', '职场'], intro: '一骑红尘妃子笑，无人知是荔枝来。基层小吏的转运冲关记。',
    quote: '就算失败，我也想知道，自己倒在距离终点多远的地方。', recommend: false, imageKey: 'changan', gradient: 2
  },
  {
    id: 'book-cmov', title: '百年孤独', author: '加西亚·马尔克斯', category: 'novel', rating: 4.5, progress: 8,
    tags: ['魔幻现实主义'], intro: '布恩迪亚家族七代人的兴衰史，拉丁美洲的百年缩影。',
    quote: '生命中曾经有过的所有灿烂，原来终究，都需要用寂寞来偿还。', recommend: false, imageKey: 'hundred', gradient: 1
  },
  {
    id: 'book-wanli', title: '万历十五年', author: '黄仁宇', category: 'history', rating: 4.4, progress: 45,
    tags: ['明史', '大历史'], intro: '以"大历史观"复盘帝国制度在万历年间如何渐渐失去弹力。',
    quote: '一个社会重提出若干重大问题，必须在过去找到问题的根源。', recommend: false, imageKey: 'wanli', gradient: 2
  },
  {
    id: 'book-renlei', title: '人类简史', author: '尤瓦尔·赫拉利', category: 'history', rating: 4.6, progress: 78,
    tags: ['通识', '文明'], intro: '从认知革命、农业革命到科学革命，人类是怎么一路走来。',
    quote: '历史从无正义可言。', recommend: true, imageKey: 'renlei', gradient: 3
  },
  {
    id: 'book-sa2', title: '浪潮之巅', author: '吴军', category: 'tech', rating: 4.5, progress: 100,
    tags: ['IT 史', '商业'], intro: '从 AT&T 到谷歌，看科技公司的兴衰与规律之巅。',
    quote: '一个公司，从本质上讲，是商业规律、科技规律和人才规律的产物。', recommend: true, imageKey: 'wave', gradient: 3
  },
  {
    id: 'book-clean', title: '代码整洁之道', author: '马丁', category: 'tech', rating: 4.3, progress: 30,
    tags: ['工程', '编程'], intro: '让代码可读、可改、可维护，是工程师一生的功课。',
    quote: '整洁代码总是看起来像是由在乎的人写出来的。', recommend: false, imageKey: 'clean', gradient: 0
  },
  {
    id: 'book-prince', title: '小王子', author: '圣埃克苏佩里', category: 'life', rating: 4.8, progress: 100,
    tags: ['童话', '治愈'], intro: '所有的大人都曾是小孩，虽然只有少数人记得。',
    quote: '重要的东西，用眼睛是看不见的。', recommend: true, imageKey: 'prince', gradient: 1
  },
  {
    id: 'book-moon', title: '山月记', author: '中岛敦', category: 'life', rating: 4.4, progress: 55,
    tags: ['短篇', '思辨'], intro: '我深怕自己本非美玉，故而不敢加以刻苦琢磨。',
    quote: '其实我哪有什么远志，只不过害怕自己非美玉，不敢加以琢磨。', recommend: false, imageKey: 'moon', gradient: 2
  }
];

export function bookById(id: string): Book {
  for (const b of BOOKS) {
    if (b.id === id) {
      return b;
    }
  }
  return BOOKS[0];
}

// 每日荐书池（页面按"天"轮换出当天 1 本 == 列表活条与荐书页"同源联动"）
export function recommendPool(): Book[] {
  return BOOKS.filter((b: Book) => b.recommend === true);
}

// 分类筛选
export function filterBooks(catId: string): Book[] {
  return BOOKS.filter((b: Book) => catId === 'all' || b.category === catId);
}