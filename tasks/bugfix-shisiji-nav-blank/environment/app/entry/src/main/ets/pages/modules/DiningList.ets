// 模块一 · 餐厅点餐「鲜小馆」菜单页（NavDestination，由四时集首页 push 进入）
// 形态① 招牌轮播 Swiper · ② 菜系 Tabs+菜品列表 · ③ 详情 DetailSheet(通用壳体+规格正文) · ④ 今日特惠 TimeDealBar(时间驱动)
// 抽壳说明：缩略图/标签/角标/详情壳体/活内容条均改用 common/ 通用件，接口与行为不变。
import {
  Banner, Dish, DishCategory, DishOption, DishOptionGroup, STORE, DISH_GRADIENTS, CATEGORIES,
  SIGNATURE_BANNERS, dishById, dishEmoji, dishMedia, formatPrice, dealDishes, DINING_SLOTS
} from '../../model/DiningData';
import { StoreDisplay } from '../../scenes/StoreDisplay';
import { nowHour, hourLabel, pickHourly } from '../../common/TimeRules';
import { Placeholder } from '../../common/Placeholder';
import { TagChip } from '../../common/TagChip';
import { DealBadge } from '../../common/DealBadge';
import { SheetHero } from '../../common/SheetHero';
import { TimeDealBar } from '../../common/TimeDealBar';

// 生成某菜选项组的默认选择：单选预选默认项，多选默认全不选
function baseSelect(dish: Dish): string[][] {
  const groups: DishOptionGroup[] = dish.options ?? [];
  const result: string[][] = [];
  for (const g of groups) {
    if (g.multi) {
      result.push([]);
    } else {
      const def = g.options.find((o: DishOption) => o.defaultValue === true) ?? g.options[0];
      result.push([def.id]);
    }
  }
  return result;
}

// 选项渲染模型：选中态直接参与 ForEach key，点选后对应胶囊必然重建、立即高亮
interface ChipItem {
  id: string;
  label: string;
  price?: number;
  selected: boolean;
}

@Component
export struct DiningList {
  // 今日特惠"随时间变"：按当前小时从特惠池轮换出 3 道 + 档位文案
  @State deals: Dish[] = pickHourly(dealDishes(), nowHour(), 3);
  @State slotLabel: string = hourLabel(DINING_SLOTS, nowHour());
  @State currentDish: Dish = CATEGORIES[0].dishes[0];
  @State showDetail: boolean = false;
  @State chosenByGroup: string[][] = [];
  @Consume pathStack: NavPathStack;

  // TextClock 每分钟回调：重算当前小时的特惠集合与档位
  onTickDeals(value: number): void {
    const h = new Date(value).getHours();
    this.deals = pickHourly(dealDishes(), h, 3);
    this.slotLabel = hourLabel(DINING_SLOTS, h);
  }

  // 打开某个菜的详情弹层：重置该菜的选项默认选择
  openDetail(id: string): void {
    this.currentDish = dishById(id);
    this.chosenByGroup = baseSelect(this.currentDish);
    this.showDetail = true;
  }

  // 当前菜勾选项后的总价 = 基础价 + 各选中项加价
  dishTotal(): number {
    let total = this.currentDish.price;
    const groups: DishOptionGroup[] = this.currentDish.options ?? [];
    for (let g = 0; g < groups.length; g++) {
      for (const optId of this.chosenByGroup[g] ?? []) {
        const opt = groups[g].options.find((o: DishOption) => o.id === optId);
        if (opt !== undefined && opt.price !== undefined) {
          total += opt.price;
        }
      }
    }
    return total;
  }

  // 某组内某选项是否已选中
  isChosen(g: number, optId: string): boolean {
    return (this.chosenByGroup[g] ?? []).indexOf(optId) >= 0;
  }

  // 把选项拍平成渲染模型：带上当次选中态（选中态写入 key，切换即重建高亮）
  chipItems(g: DishOptionGroup, gi: number): ChipItem[] {
    return g.options.map((o: DishOption): ChipItem => ({
      id: o.id,
      label: o.label,
      price: o.price,
      selected: this.isChosen(gi, o.id)
    }));
  }

  // 点选：单选覆盖，多选切换
  toggleOpt(g: number, optId: string): void {
    const groups: DishOptionGroup[] = this.currentDish.options ?? [];
    if (groups.length === 0 || g < 0 || g >= groups.length) {
      return;
    }
    const prev = this.chosenByGroup[g] ?? [];
    let next: string[];
    if (groups[g].multi) {
      if (prev.indexOf(optId) >= 0) {
        next = prev.filter((x: string) => x !== optId);
      } else {
        next = [...prev, optId];
      }
    } else {
      next = [optId];
    }
    const arr = [...this.chosenByGroup];
    arr[g] = next;
    this.chosenByGroup = arr;
  }

  // 招牌轮播卡片：渐变底 + emoji 兜底 + 照片层 + 暗角 + 文案，点进详情
  @Builder
  bannerCard(b: Banner) {
    Stack({ alignContent: Alignment.End }) {
      Text(dishEmoji(dishById(b.dishId).image))
        .fontSize(96)
        .opacity(0.9)
      Image(dishMedia(dishById(b.dishId).image))
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 90,
          colors: [['#00000066', 0.0], ['#00000000', 0.7]]
        })
      Column({ space: 6 }) {
        Text(b.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text(b.subtitle)
          .fontSize(13)
          .fontColor('#FFF3EA')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .height(184)
    .linearGradient({
      angle: 135,
      colors: [
        [DISH_GRADIENTS[b.gradient][0], 0.0],
        [DISH_GRADIENTS[b.gradient][1], 1.0]
      ]
    })
    .borderRadius(16)
    .clip(true)
    .onClick(() => this.openDetail(b.dishId))
  }

  // 今日特惠小卡：44×44 占位图 + 现价/划线 + 菜名
  @Builder
  dealChip(d: Dish) {
    Row({ space: 8 }) {
      Placeholder({
        emoji: dishEmoji(d.image),
        gradient: DISH_GRADIENTS[d.gradient],
        media: dishMedia(d.image),
        boxWidth: 44,
        boxHeight: 44,
        corner: 10,
        emojiSize: 24
      })
      Column({ space: 2 }) {
        Row({ space: 4 }) {
          Text(formatPrice(d.price))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E64545')
          if (d.originalPrice !== undefined) {
            Text('¥' + formatPrice(d.originalPrice))
              .fontSize(11)
              .fontColor('#B5A9A0')
              .decoration({ type: TextDecorationType.LineThrough })
          }
        }
        Text(d.name)
          .fontSize(12)
          .fontColor('#26201C')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => this.openDetail(d.id))
  }

  // 活内容条：标题 + 「店内大屏」入口 + 档位 pill + 时钟；内容为横滑特惠卡
  @Builder
  dealStripContent() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.deals, (d: Dish) => {
          this.dealChip(d)
        }, (d: Dish) => d.id)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(66)
  }

  @Builder
  dishRow(d: Dish) {
    Row({ space: 12 }) {
      Placeholder({
        emoji: dishEmoji(d.image),
        gradient: DISH_GRADIENTS[d.gradient],
        media: dishMedia(d.image),
        boxWidth: 72,
        boxHeight: 72,
        corner: 12,
        emojiSize: 34
      })

      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(d.name)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#26201C')
          if (d.isTodayDeal === true) {
            DealBadge({ text: '惠', dia: 18, circle: true })
          }
        }
        Row({ space: 6 }) {
          if (d.spicy > 0) {
            Text('🌶'.repeat(d.spicy))
              .fontSize(12)
          }
          ForEach(d.tags, (tag: string) => {
            TagChip({ text: tag })
          }, (tag: string) => tag)
        }
        Text(d.intro)
          .fontSize(12)
          .fontColor('#8C8078')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 4 }) {
        Row({ space: 2 }) {
          Text('¥')
            .fontSize(12)
            .fontColor('#FF6B35')
          Text(formatPrice(d.price))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF6B35')
        }
        if (d.originalPrice !== undefined) {
          Text('¥' + formatPrice(d.originalPrice))
            .fontSize(11)
            .fontColor('#B5A9A0')
            .decoration({ type: TextDecorationType.LineThrough })
        }
        Text('月售 ' + d.sales)
          .fontSize(11)
          .fontColor('#B5A9A0')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => this.openDetail(d.id))
  }

  @Builder
  dishList(cat: DishCategory) {
    List({ space: 12 }) {
      ForEach(cat.dishes, (d: Dish) => {
        ListItem() {
          this.dishRow(d)
        }
      }, (d: Dish) => d.id)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 16 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
  }

  // 选项组：标题 + 可多选提示 + 胶囊排布
  @Builder
  optionGroup(g: DishOptionGroup, gi: number) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(g.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#8C8078')
        if (g.multi) {
          Text('可多选')
            .fontSize(10)
            .fontColor('#B5A9A0')
        }
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.chipItems(g, gi), (c: ChipItem) => {
          this.optionChip(c, () => this.toggleOpt(gi, c.id))
        }, (c: ChipItem) => c.id + '_' + c.selected)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 单个选项小胶囊：选中=实橙底白字+✓（clear 高亮）；加价项在尾标 +¥
  @Builder
  optionChip(c: ChipItem, onTap: () => void) {
    Row({ space: 4 }) {
      if (c.selected) {
        Text('✓ ')
          .fontSize(12)
          .fontColor(Color.White)
      }
      Text(c.label)
        .fontSize(12)
        .fontColor(c.selected ? Color.White : '#5A514C')
      if (c.price !== undefined && c.price > 0) {
        Text('+¥' + formatPrice(c.price))
          .fontSize(10)
          .fontColor(c.selected ? '#FFEADF' : '#E64545')
      }
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor(c.selected ? '#FF6B35' : Color.White)
    .borderRadius(999)
    .border({ width: 1, color: c.selected ? '#FF6B35' : '#EFE4DA' })
    .onClick(() => onTap())
  }

  // 详情弹层：数据化 SheetHero 头部 + 页面自绘正文（@BuilderParam 在弹窗内二次渲染有 this 失效的坑，故不代管）
  @Builder
  detailSheet() {
    Column() {
      SheetHero({
        emoji: dishEmoji(this.currentDish.image),
        gradient: DISH_GRADIENTS[this.currentDish.gradient],
        media: dishMedia(this.currentDish.image),
        title: this.currentDish.name,
        badgeText: this.currentDish.isTodayDeal === true ? '惠' : '',
        badgeBg: '#E64545'
      })

      Scroll() {
        Column({ space: 14 }) {
          this.detailPriceLine()
          this.detailBody()
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  // 价格行（含划线原价 + 特惠省价 pill）
  @Builder
  detailPriceLine() {
    Row({ space: 10 }) {
      Row({ space: 2 }) {
        Text('¥')
          .fontSize(16)
          .fontColor('#FF6B35')
        Text(formatPrice(this.dishTotal()))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF6B35')
      }
      if (this.currentDish.originalPrice !== undefined) {
        Text('¥' + formatPrice(this.currentDish.originalPrice))
          .fontSize(15)
          .fontColor('#B5A9A0')
          .decoration({ type: TextDecorationType.LineThrough })
      }
      if (this.currentDish.isTodayDeal === true) {
        Text('特惠 ¥' + formatPrice(this.currentDish.originalPrice! - this.currentDish.price))
          .fontSize(13)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('#E64545')
          .borderRadius(999)
      }
    }
    .width('100%')
  }

  // 详情正文：辣度/标签 + 介绍 + 店铺信息 + 规格选择
  @Builder
  detailBody() {
    Column({ space: 12 }) {
      Row({ space: 6 }) {
        if (this.currentDish.spicy > 0) {
          Text('🌶'.repeat(this.currentDish.spicy))
            .fontSize(14)
        }
        ForEach(this.currentDish.tags, (tag: string) => {
          TagChip({ text: tag, fontSize: 11 })
        }, (tag: string) => tag)
      }
      .width('100%')

      Text(this.currentDish.intro)
        .fontSize(14)
        .fontColor('#5A514C')
        .lineHeight(22)
        .width('100%')

      Row() {
        Text('月售 ' + this.currentDish.sales)
          .fontSize(13)
          .fontColor('#B5A9A0')
        Blank()
        Text(STORE.name + ' · ' + STORE.hours)
          .fontSize(13)
          .fontColor('#B5A9A0')
      }
      .width('100%')

      if ((this.currentDish.options ?? []).length > 0) {
        Divider()
          .color('#F0E6DB')

        ForEach(this.currentDish.options ?? [], (g: DishOptionGroup, gi: number) => {
          this.optionGroup(g, gi)
        }, (g: DishOptionGroup) => g.id)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      Column() {
        // 头部：返回 + 店名 + 标语
        Row({ space: 10 }) {
          Text('‹ 返回')
            .fontSize(15)
            .fontColor('#FF6B35')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#FFEADF')
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pop();
            })
          Column({ space: 2 }) {
            Text(STORE.name)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#26201C')
            Text(STORE.slogan)
              .fontSize(12)
              .fontColor('#8C8078')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        // 形态①：招牌菜轮播
        Swiper() {
          ForEach(SIGNATURE_BANNERS, (b: Banner) => {
            this.bannerCard(b)
          }, (b: Banner) => b.id)
        }
        .height(184)
        .padding({ left: 16, right: 16 })
        .loop(true)
        .autoPlay(true)
        .interval(3000)
        .duration(600)
        .indicator(true)

        // 形态④：今日特惠活内容条（时间驱动）
        TimeDealBar({
          title: '今日特惠',
          slotLabel: this.slotLabel,
          actionText: '店内大屏',
          onAction: () => {
            this.pathStack.pushPathByName('StoreDisplay', null)
          },
          onTick: (v: number) => this.onTickDeals(v),
          content: this.dealStripContent
        })
        .padding({ left: 16, right: 16 })
        .margin({ top: 16, bottom: 12 })

        // 形态②：菜系页签 + 餐品列表
        Tabs({ barPosition: BarPosition.Start }) {
          ForEach(CATEGORIES, (cat: DishCategory) => {
            TabContent() {
              this.dishList(cat)
            }
            .backgroundColor('#FFF7F0')
            .tabBar(cat.name)
          }, (c: DishCategory) => c.id)
        }
        .barHeight(44)
        .barMode(BarMode.Scrollable)
        .scrollable(true)
        .backgroundColor('#FFF7F0')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFF7F0')
      .bindSheet(
        $$this.showDetail,
        this.detailSheet(),
        { height: SheetSize.MEDIUM, dragBar: true, showClose: true }
      )
    }
    .title('鲜小馆')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}