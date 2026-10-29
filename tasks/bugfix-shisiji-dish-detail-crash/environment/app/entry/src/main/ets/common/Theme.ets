// 全局主题：中性色 token + 四模块品牌注册表（首页宫格 / 各模块页共用）
export interface Colors {
  bg: string;      // 页面底 暖白
  card: string;    // 卡片 白
  title: string;   // 主标题 深墨
  sub: string;     // 次级文字
  deal: string;    // 特惠红
  line: string;    // 分隔线
}

export const NEUTRAL: Colors = {
  bg: '#F7F6F3',
  card: '#FFFFFF',
  title: '#211E1A',
  sub: '#8A837C',
  deal: '#E64545',
  line: '#EFECE7'
};

// 模块品牌注册表：key 唯一、route 是 Navigation 路由名、ready 决定首页是否可进
export interface ModuleTheme {
  key: string;        // dining | hotel | pet | book
  title: string;      // 模块名
  slogan: string;
  emoji: string;
  accent: string;
  accentSoft: string;
  route: string;      // NavDestination 路由名
  ready: boolean;     // 未建好的模块首页先 Toast 占位
}

export const LAUNCHERS: ModuleTheme[] = [
  {
    key: 'dining', title: '餐厅点餐', slogan: '鲜小馆 · 今日特惠', emoji: '🍜',
    accent: '#FF6B35', accentSoft: '#FFF3EB', route: 'DiningList', ready: true
  },
  {
    key: 'hotel', title: '酒店房型', slogan: '云栖酒店 · 全景看房', emoji: '🏨',
    accent: '#1F4E79', accentSoft: '#EAF1F8', route: 'HotelList', ready: true
  },
  {
    key: 'pet', title: '宠物领养', slogan: '暖爪之家 · 给TA一个家', emoji: '🐾',
    accent: '#E86A92', accentSoft: '#FDEFF4', route: 'PetList', ready: true
  },
  {
    key: 'book', title: '书单书架', slogan: '拾光书局 · 每日荐书', emoji: '📚',
    accent: '#2E6B4F', accentSoft: '#ECF5F0', route: 'BookList', ready: true
  }
];