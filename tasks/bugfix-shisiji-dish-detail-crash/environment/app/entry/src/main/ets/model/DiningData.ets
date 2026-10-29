// 菜单数据模型与假数据：类型安全、金额以「分」存整数、展示与逻辑分离。
// 菜单元服务纯前端，无网络请求；菜品视觉用 emoji + 渐变占位（可后续替换真实照片）。
import { HourSlot } from '../common/TimeRules';

export interface Dish {
  id: string;
  name: string;            // 菜名
  price: number;           // 现价（分）；3500 = ¥35.00
  originalPrice?: number;  // 原价（分）；有则列表/详情显示划线，制造促销感
  intro: string;           // 一句话介绍
  tags: string[];          // 招牌 / 辣 / 新品 / 素 等
  spicy: number;           // 辣度 0-3
  sales: number;           // 月售
  image: string;           // 视觉占位键（对应 DISH_EMOJI）
  gradient: number;        // 渐变配色索引（对应 DISH_GRADIENTS）
  isTodayDeal?: boolean;   // 是否进今日特惠池
  options?: DishOptionGroup[];  // 可选规格：一组组选项（单选/多选、可带加价）
}

// 菜品选项：一个具体的可选项，如「加一份米线」
export interface DishOption {
  id: string;
  label: string;          // 选项文案
  price?: number;         // 加价（分）；缺省 0
  defaultValue?: boolean; // 单选组的默认预选项
}

// 选项组：一组互相关联的选项，单选（radio）或多选（checkbox）
export interface DishOptionGroup {
  id: string;
  title: string;          // 组标题，如「上桌方式」「加份」
  multi: boolean;         // true=多选；false=单选（必选一项）
  options: DishOption[];
}

export interface DishCategory {
  id: string;
  name: string;            // 菜系名
  dishes: Dish[];
}

export interface Banner {
  id: string;
  title: string;           // 如「招牌必点 · 汽锅鸡」
  subtitle: string;
  dishId: string;          // 指向 Dish，点轮播进详情
  gradient: number;
}

export interface StoreInfo {
  name: string;
  slogan: string;
  hours: string;
}

export class ViewDataSource implements IDataSource {
  private items: Dish[];

  constructor(items: Dish[]) {
    this.items = items;
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): Dish {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    // 首版数据静态不增删，无需向监听器推送变更
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    // 同上，静态数据无需解绑逻辑
  }
}

// 店铺信息
export const STORE: StoreInfo = {
  name: '鲜小馆',
  slogan: '开业十二年 · 只做一锅汤',
  hours: '11:00 - 22:00'
};

// 视觉占位：渐变底 + 大号 emoji（免版权、体积小、秒开）
export const DISH_GRADIENTS: string[][] = [
  ['#FFB07C', '#FF6B35'], // 暖橙（招牌）
  ['#FFD97E', '#F5A623'], // 明黄（主食）
  ['#7ED6A3', '#2E7D5B'], // 青绿（素/养生）
  ['#FF9FB2', '#F56476'], // 玫粉（甜品饮品）
  ['#8EC5FC', '#6A8CFF'], // 蓝紫（凉菜）
  ['#C7B3FF', '#8A6BE8']  // 深紫（特色）
];

// 菜品视觉占位 emoji：按 image 键查询（ArkTS 严格模式不允许未声明类型的对象字面量，用函数替代）
export function dishEmoji(key: string): string {
  switch (key) {
    case 'crossing': return '🍜';
    case 'chicken': return '🍲';
    case 'fish': return '🐟';
    case 'beef': return '🥩';
    case 'veg': return '🥬';
    case 'pork': return '🍖';
    case 'cucumber': return '🥒';
    case 'pigear': return '🐷';
    case 'bao': return '🥟';
    case 'rice': return '🍚';
    case 'bingfen': return '🍧';
    case 'suanjiao': return '🍹';
    case 'tea': return '🍵';
    default: return '🍽️';
  }
}

// 菜品主图资源：AI 生成写实摄影（见《菜品图AI生成清单.md》）。
// 替换规则：把 media/dish_<key>.png 占位删除，放入同名的 dish_<key>.jpg/.webp 即可。
// 有照片时 Image 覆盖 emoji；照片缺失或占位透明时，底层 emoji+渐变自动透出兜底。
export function dishMedia(key: string): Resource {
  switch (key) {
    case 'crossing': return $r('app.media.dish_crossing');
    case 'chicken': return $r('app.media.dish_chicken');
    case 'fish': return $r('app.media.dish_fish');
    case 'beef': return $r('app.media.dish_beef');
    case 'veg': return $r('app.media.dish_veg');
    case 'pork': return $r('app.media.dish_pork');
    case 'cucumber': return $r('app.media.dish_cucumber');
    case 'pigear': return $r('app.media.dish_pigear');
    case 'bao': return $r('app.media.dish_bao');
    case 'rice': return $r('app.media.dish_rice');
    case 'bingfen': return $r('app.media.dish_bingfen');
    case 'suanjiao': return $r('app.media.dish_suanjiao');
    case 'tea': return $r('app.media.dish_tea');
    default: return $r('app.media.icon');
  }
}

// 菜系：招牌 / 热菜 / 凉菜 / 主食 / 甜品饮品
export const CATEGORIES: DishCategory[] = [
  {
    id: 'cat-signature',
    name: '招牌',
    dishes: [
      {
        id: 'dish-crossing',
        name: '过桥米线',
        price: 2800,
        intro: '滚烫鸡汤现浇，先荤后素一口鲜。',
        tags: ['招牌'],
        spicy: 0,
        sales: 1280,
        image: 'crossing',
        gradient: 0,
        isTodayDeal: false,
        options: [
          {
            id: 'g-serving',
            title: '吃法',
            multi: false,
            options: [
              { id: 'svc-mix', label: '配好端出', defaultValue: true },
              { id: 'svc-diy', label: '热汤自涮' }
            ]
          },
          {
            id: 'g-mushroom',
            title: '菌菇',
            multi: false,
            options: [
              { id: 'mush-yes', label: '要菌菇', defaultValue: true },
              { id: 'mush-no', label: '不要' }
            ]
          },
          {
            id: 'g-meat',
            title: '鲜肉',
            multi: false,
            options: [
              { id: 'meat-yes', label: '要鲜肉片', defaultValue: true },
              { id: 'meat-no', label: '不要' }
            ]
          },
          {
            id: 'g-extra',
            title: '加菜',
            multi: true,
            options: [
              { id: 'ext-noodle', label: '加一份米线', price: 200 },
              { id: 'ext-egg', label: '加溏心蛋', price: 150 },
              { id: 'ext-soup', label: '加汤', price: 100 },
              { id: 'ext-beef', label: '加肥牛', price: 400 },
              { id: 'ext-luncheon', label: '加午餐肉', price: 300 },
              { id: 'ext-veg', label: '蔬菜拼盘', price: 300 }
            ]
          }
        ]
      },
      {
        id: 'dish-chicken',
        name: '汽锅鸡',
        price: 6800,
        originalPrice: 7800,
        intro: '土陶汽锅蒸足四小时，原汤化原食。',
        tags: ['招牌', '养生'],
        spicy: 0,
        sales: 460,
        image: 'chicken',
        gradient: 0,
        isTodayDeal: true,
        options: [
          {
            id: 'g-chicken-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'chk-original', label: '原汤原味', defaultValue: true },
              { id: 'chk-mild', label: '微辣' }
            ]
          },
          {
            id: 'g-chicken-extra',
            title: '加菜',
            multi: true,
            options: [
              { id: 'chk-more', label: '加一份鸡块', price: 500 },
              { id: 'chk-herb', label: '加虫草花', price: 300 },
              { id: 'chk-morel', label: '加羊肚菌', price: 600 },
              { id: 'chk-bamboo', label: '加竹荪', price: 500 },
              { id: 'chk-yam', label: '加山药', price: 300 },
              { id: 'chk-rice', label: '加一份杂粮饭', price: 200 }
            ]
          }
        ]
      }
    ]
  },
  {
    id: 'cat-hot',
    name: '热菜',
    dishes: [
      {
        id: 'dish-fish',
        name: '香茅烤鱼',
        price: 5800,
        originalPrice: 6800,
        intro: '傣味香茅腌制，现点明火现烤。',
        tags: ['香辣', '招牌'],
        spicy: 2,
        sales: 350,
        image: 'fish',
        gradient: 5,
        isTodayDeal: true,
        options: [
          {
            id: 'g-fish-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'fish-mild', label: '微辣' },
              { id: 'fish-med', label: '中辣', defaultValue: true },
              { id: 'fish-hot', label: '特辣' }
            ]
          },
          {
            id: 'g-fish-side',
            title: '配菜',
            multi: true,
            options: [
              { id: 'fish-potato', label: '加土豆片', price: 300 },
              { id: 'fish-noodle', label: '加粉丝', price: 200 },
              { id: 'fish-tofu', label: '加豆腐', price: 300 },
              { id: 'fish-lotus', label: '加藕片', price: 300 },
              { id: 'fish-konjac', label: '加魔芋', price: 200 },
              { id: 'fish-veg', label: '蔬菜拼盘', price: 300 }
            ]
          }
        ]
      },
      {
        id: 'dish-beef',
        name: '小炒黄牛肉',
        price: 4600,
        intro: '猛火快炒嫩而不柴，下饭一绝。',
        tags: ['香辣'],
        spicy: 2,
        sales: 290,
        image: 'beef',
        gradient: 2,
        isTodayDeal: false,
        options: [
          {
            id: 'g-beef-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'beef-mild', label: '微辣', defaultValue: true },
              { id: 'beef-med', label: '中辣' },
              { id: 'beef-hot', label: '特辣' }
            ]
          },
          {
            id: 'g-beef-extra',
            title: '加菜',
            multi: true,
            options: [
              { id: 'beef-more', label: '加牛肉', price: 400 },
              { id: 'beef-pickle', label: '加泡椒', price: 200 },
              { id: 'beef-chive', label: '加蒜苔', price: 150 },
              { id: 'beef-mushroom', label: '加木耳', price: 200 },
              { id: 'beef-pepper', label: '加红椒', price: 100 },
              { id: 'beef-coriander', label: '加一份米饭', price: 200 }
            ]
          }
        ]
      },
      {
        id: 'dish-veg',
        name: '菌菇炒时蔬',
        price: 2800,
        intro: '云南山珍配当季时蔬，清甜爽口。',
        tags: ['素'],
        spicy: 0,
        sales: 180,
        image: 'veg',
        gradient: 2,
        isTodayDeal: false,
        options: [
          {
            id: 'g-veg-flavor',
            title: '口味',
            multi: false,
            options: [
              { id: 'veg-stir', label: '清炒', defaultValue: true },
              { id: 'veg-garlic', label: '加蒜蓉' },
              { id: 'veg-spicy', label: '加辣' }
            ]
          },
          {
            id: 'g-veg-extra',
            title: '加菜',
            multi: true,
            options: [
              { id: 'veg-herb', label: '加鸡腿菇', price: 300 },
              { id: 'veg-king', label: '加杏鲍菇', price: 300 },
              { id: 'veg-mushroom', label: '加木耳', price: 200 },
              { id: 'veg-shrimp', label: '加虾仁', price: 500 },
              { id: 'veg-rice', label: '加一份米饭', price: 200 }
            ]
          }
        ]
      },
      {
        id: 'dish-pork',
        name: '傣味烤五花',
        price: 5200,
        intro: '炭火慢烤外焦里嫩，蘸酸梅酱。',
        tags: ['香辣'],
        spicy: 3,
        sales: 210,
        image: 'pork',
        gradient: 5,
        isTodayDeal: false,
        options: [
          {
            id: 'g-pork-sauce',
            title: '蘸料',
            multi: false,
            options: [
              { id: 'pork-plum', label: '酸梅酱', defaultValue: true },
              { id: 'pork-chili', label: '干辣椒面' },
              { id: 'pork-both', label: '两种都要' }
            ]
          },
          {
            id: 'g-pork-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'pork-original', label: '原味' },
              { id: 'pork-mild', label: '微辣', defaultValue: true },
              { id: 'pork-hot', label: '特辣' }
            ]
          },
          {
            id: 'g-pork-cut',
            title: '火候',
            multi: false,
            options: [
              { id: 'pork-std', label: '标准', defaultValue: true },
              { id: 'pork-crisp', label: '焦脆一些' },
              { id: 'pork-tender', label: '软嫩一些' }
            ]
          },
          {
            id: 'g-pork-wrap',
            title: '搭配',
            multi: true,
            options: [
              { id: 'pork-leaf', label: '加生菜叶', price: 100 },
              { id: 'pork-glut', label: '加蒸糯米饭', price: 200 }
            ]
          }
        ]
      }
    ]
  },
  {
    id: 'cat-cold',
    name: '凉菜',
    dishes: [
      {
        id: 'dish-cucumber',
        name: '酸辣黄瓜',
        price: 1600,
        intro: '拍碎现拌，酸辣开胃。',
        tags: ['微辣'],
        spicy: 1,
        sales: 300,
        image: 'cucumber',
        gradient: 4,
        isTodayDeal: false,
        options: [
          {
            id: 'g-cuc-flavor',
            title: '口味',
            multi: false,
            options: [
              { id: 'cuc-sour', label: '酸辣', defaultValue: true },
              { id: 'cuc-garlic', label: '蒜香' },
              { id: 'cuc-sweet', label: '微甜' }
            ]
          },
          {
            id: 'g-cuc-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'cuc-mild', label: '微辣', defaultValue: true },
              { id: 'cuc-hot', label: '加辣' }
            ]
          },
          {
            id: 'g-cuc-size',
            title: '份量',
            multi: false,
            options: [
              { id: 'cuc-normal', label: '例份', defaultValue: true },
              { id: 'cuc-large', label: '大份', price: 400 }
            ]
          }
        ]
      },
      {
        id: 'dish-pigear',
        name: '凉拌猪耳',
        price: 2400,
        intro: '爽脆弹牙，蒜香入味。',
        tags: ['微辣'],
        spicy: 1,
        sales: 150,
        image: 'pigear',
        gradient: 4,
        isTodayDeal: false,
        options: [
          {
            id: 'g-pig-coriander',
            title: '加料',
            multi: false,
            options: [
              { id: 'pig-cori', label: '要香菜', defaultValue: true },
              { id: 'pig-nocori', label: '不要香菜' }
            ]
          },
          {
            id: 'g-pig-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'pig-mild', label: '微辣', defaultValue: true },
              { id: 'pig-med', label: '中辣' }
            ]
          },
          {
            id: 'g-pig-size',
            title: '份量',
            multi: false,
            options: [
              { id: 'pig-normal', label: '例份', defaultValue: true },
              { id: 'pig-large', label: '大份', price: 500 }
            ]
          }
        ]
      }
    ]
  },
  {
    id: 'cat-main',
    name: '主食',
    dishes: [
      {
        id: 'dish-bao',
        name: '破酥包',
        price: 600,
        intro: '面皮层层起酥，咸香爆汁。',
        tags: ['招牌'],
        spicy: 0,
        sales: 900,
        image: 'bao',
        gradient: 1,
        isTodayDeal: false,
        options: [
          {
            id: 'g-bao-flavor',
            title: '口味',
            multi: false,
            options: [
              { id: 'bao-meat', label: '鲜肉', defaultValue: true },
              { id: 'bao-char', label: '叉烧' },
              { id: 'bao-bean', label: '豆沙' }
            ]
          },
          {
            id: 'g-bao-cook',
            title: '做法',
            multi: false,
            options: [
              { id: 'bao-steam', label: '蒸', defaultValue: true },
              { id: 'bao-fry', label: '煎制' }
            ]
          },
          {
            id: 'g-bao-count',
            title: '份量',
            multi: false,
            options: [
              { id: 'bao-one', label: '1 只', defaultValue: true },
              { id: 'bao-two', label: '2 只', price: 600 },
              { id: 'bao-four', label: '4 只', price: 1800 }
            ]
          }
        ]
      },
      {
        id: 'dish-rice',
        name: '铜锅洋芋饭',
        price: 2200,
        intro: '小铜锅现焖，洋芋焦香铺底。',
        tags: [],
        spicy: 0,
        sales: 400,
        image: 'rice',
        gradient: 1,
        isTodayDeal: false,
        options: [
          {
            id: 'g-rice-extra',
            title: '加料',
            multi: true,
            options: [
              { id: 'rice-egg', label: '加煎蛋', price: 200 },
              { id: 'rice-ham', label: '加火腿', price: 300 },
              { id: 'rice-more', label: '加一份洋芋', price: 200 },
              { id: 'rice-sausage', label: '加腊肠', price: 400 },
              { id: 'rice-corn', label: '加玉米', price: 200 },
              { id: 'rice-refill', label: '加一份饭', price: 200 }
            ]
          },
          {
            id: 'g-rice-spicy',
            title: '辣度',
            multi: false,
            options: [
              { id: 'rice-plain', label: '不辣', defaultValue: true },
              { id: 'rice-mild', label: '微辣' }
            ]
          }
        ]
      }
    ]
  },
  {
    id: 'cat-sweet',
    name: '甜品饮品',
    dishes: [
      {
        id: 'dish-bingfen',
        name: '玫瑰冰粉',
        price: 1200,
        originalPrice: 1500,
        intro: '手搓冰粉配玫瑰蜜，冰凉顺滑。',
        tags: ['甜'],
        spicy: 0,
        sales: 600,
        image: 'bingfen',
        gradient: 3,
        isTodayDeal: true,
        options: [
          {
            id: 'g-ice',
            title: '冰度',
            multi: false,
            options: [
              { id: 'ice-normal', label: '多冰', defaultValue: true },
              { id: 'ice-less', label: '少冰' },
              { id: 'ice-no', label: '去冰' }
            ]
          },
          {
            id: 'g-top',
            title: '加料',
            multi: true,
            options: [
              { id: 'top-riceball', label: '加糍粑', price: 150 },
              { id: 'top-haw', label: '加山楂', price: 100 },
              { id: 'top-taro', label: '加芋圆', price: 200 },
              { id: 'top-fruit', label: '加水果', price: 200 },
              { id: 'top-jiuniang', label: '加醪糟', price: 200 }
            ]
          }
        ]
      },
      {
        id: 'dish-suanjiao',
        name: '酸梅汁',
        price: 1000,
        originalPrice: 1300,
        intro: '乌梅现熬，酸甜回甘解辣。',
        tags: ['甜'],
        spicy: 0,
        sales: 500,
        image: 'suanjiao',
        gradient: 3,
        isTodayDeal: true,
        options: [
          {
            id: 'g-temp',
            title: '冷热',
            multi: false,
            options: [
              { id: 'temp-cold', label: '冰镇', defaultValue: true },
              { id: 'temp-warm', label: '常温' }
            ]
          },
          {
            id: 'g-plum-size',
            title: '份量',
            multi: false,
            options: [
              { id: 'plum-mid', label: '中杯', defaultValue: true },
              { id: 'plum-large', label: '大杯', price: 300 }
            ]
          },
          {
            id: 'g-plum-top',
            title: '加料',
            multi: true,
            options: [
              { id: 'plum-osmanthus', label: '加桂花', price: 100 },
              { id: 'plum-haw', label: '加山楂', price: 100 },
              { id: 'plum-double', label: '双倍酸梅', price: 200 }
            ]
          }
        ]
      },
      {
        id: 'dish-tea',
        name: '普洱茶',
        price: 800,
        intro: '云南熟普，温润解腻。',
        tags: [],
        spicy: 0,
        sales: 260,
        image: 'tea',
        gradient: 1,
        isTodayDeal: false,
        options: [
          {
            id: 'g-tea-temp',
            title: '温度',
            multi: false,
            options: [
              { id: 'tea-hot', label: '热泡', defaultValue: true },
              { id: 'tea-warm', label: '常温' }
            ]
          },
          {
            id: 'g-tea-strong',
            title: '浓淡',
            multi: false,
            options: [
              { id: 'tea-normal', label: '正常', defaultValue: true },
              { id: 'tea-light', label: '淡一些' }
            ]
          },
          {
            id: 'g-tea-extra',
            title: '加料',
            multi: true,
            options: [
              { id: 'tea-sugar', label: '加冰糖', price: 100 },
              { id: 'tea-tangerine', label: '加陈皮', price: 100 },
              { id: 'tea-milk', label: '加鲜奶', price: 200 },
              { id: 'tea-honey', label: '加蜂蜜', price: 150 },
              { id: 'tea-jujube', label: '加红枣', price: 100 },
              { id: 'tea-rose', label: '加玫瑰', price: 150 }
            ]
          }
        ]
      }
    ]
  }
];

// 招牌菜轮播条目
export const SIGNATURE_BANNERS: Banner[] = [
  {
    id: 'banner-chicken',
    title: '招牌必点 · 汽锅鸡',
    subtitle: '原汤化原食 · 蒸足四小时',
    dishId: 'dish-chicken',
    gradient: 0
  },
  {
    id: 'banner-fish',
    title: '香茅烤鱼',
    subtitle: '傣味驱寒 · 现点现烤',
    dishId: 'dish-fish',
    gradient: 5
  },
  {
    id: 'banner-crossing',
    title: '过桥米线',
    subtitle: '滚鸡汤现浇 · 先荤后素',
    dishId: 'dish-crossing',
    gradient: 1
  },
  {
    id: 'banner-bingfen',
    title: '玫瑰冰粉',
    subtitle: '饭后一碗 · 唇齿留香',
    dishId: 'dish-bingfen',
    gradient: 3
  }
];

// 工具函数

export function dishById(id: string): Dish {
  for (const c of CATEGORIES) {
    for (const d of c.dishes) {
      if (d.id === id) {
        return d;
      }
    }
  }
  return CATEGORIES[0].dishes[0];
}

export function formatPrice(cents: number): string {
  const yuan = cents / 100;
  return Number.isInteger(yuan) ? String(yuan) : yuan.toFixed(2);
}

// 今日特惠：固定为所有标记特惠的菜品（首版不做按时段轮换，避免"不同时段看到不同优惠"的困惑）
export function dealDishes(): Dish[] {
  return CATEGORIES.flatMap((c: DishCategory) => c.dishes)
    .filter((d: Dish) => d.isTodayDeal === true);
}

// 今日特惠档位表（覆盖全天）：配合 TimeRules.hourLabel/pickHourly 驱动菜单页特惠条"随时间变"
export const DINING_SLOTS: HourSlot[] = [
  { from: 0, to: 8, label: '晨间' },
  { from: 8, to: 11, label: '早午茶' },
  { from: 11, to: 14, label: '午市' },
  { from: 14, to: 17, label: '下午茶' },
  { from: 17, to: 22, label: '晚市' },
  { from: 22, to: 24, label: '夜宵档' }
];