// 模块四 · 书单书架「拾光书局」列表页（NavDestination）
// 双列 Grid + Rating 星级 + Progress 进度 + 每日荐书活内容条(按天) + 详情 DetailSheet + 「每日荐书」专属页入口
import {
  Book, BookCategory, BOOK_CATEGORIES, BOOKS, BOOK_GRADIENTS, bookEmoji,
  filterBooks, recommendPool
} from '../../model/BookData';
import { dayIndex, weekdayLabel, pickDaily } from '../../common/TimeRules';
import { Placeholder } from '../../common/Placeholder';
import { TagChip } from '../../common/TagChip';
import { SheetHero } from '../../common/SheetHero';
import { TimeDealBar } from '../../common/TimeDealBar';

const ACCENT = '#2E6B4F';       // 拾光书局 · 墨绿
const ACCENT_SOFT = '#ECF5F0';
const GOLD = '#C98A2D';

@Component
export struct BookList {
  // 分类筛选
  @State catId: string = 'all';
  @State books: Book[] = filterBooks('all');
  // 每日荐书"随时间变"：按"天"轮换出 1 本（与「每日荐书」页同源联动）
  @State todayBooks: Book[] = pickDaily(recommendPool(), dayIndex(), 1);
  @State dayLabel: string = '每日荐书 · ' + weekdayLabel();
  @State selected: Book = BOOKS[0];
  @State showDetail: boolean = false;
  @Consume pathStack: NavPathStack;

  onTick(value: number): void {
    this.todayBooks = pickDaily(recommendPool(), dayIndex(), 1);
    this.dayLabel = '每日荐书 · ' + weekdayLabel();
  }

  onCat(id: string): void {
    this.catId = id;
    this.books = filterBooks(id);
  }

  isTodayPick(b: Book): boolean {
    for (const t of this.todayBooks) {
      if (t.id === b.id) {
        return true;
      }
    }
    return false;
  }

  openBook(b: Book): void {
    this.selected = b;
    this.showDetail = true;
  }

  openDailyPick(): void {
    this.pathStack.pushPathByName('DailyPick', null);
  }

  @Builder
  filterChip(label: string, sel: boolean, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(sel ? Color.White : '#5A514C')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(sel ? ACCENT : Color.White)
      .borderRadius(999)
      .border({ width: 1, color: sel ? ACCENT : '#E3E0DB' })
      .onClick(() => onTap())
  }

  // 今日荐书小卡（活内容条横向滚动）
  @Builder
  recommendChip(b: Book) {
    Row({ space: 8 }) {
      Placeholder({
        emoji: bookEmoji(b.imageKey),
        gradient: BOOK_GRADIENTS[b.gradient],
        boxWidth: 44,
        boxHeight: 44,
        corner: 10,
        emojiSize: 24
      })
      Column({ space: 2 }) {
        Text(b.title)
          .fontSize(13)
          .fontColor('#26201C')
        Row({ space: 4 }) {
          Text(b.rating.toFixed(1) + ' 分')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(GOLD)
          Text('· 在读 ' + String(b.progress) + '%')
            .fontSize(11)
            .fontColor('#8A837C')
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => this.openBook(b))
  }

  @Builder
  recommendStripContent() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.todayBooks, (b: Book) => {
          this.recommendChip(b)
        }, (b: Book) => b.id)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(66)
  }

  // 书卡：封面 + 星标 + 阅读进度
  @Builder
  bookCard(b: Book) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Placeholder({
          emoji: bookEmoji(b.imageKey),
          gradient: BOOK_GRADIENTS[b.gradient],
          boxWidth: '100%',
          boxHeight: 150,
          corner: 12,
          emojiSize: 56
        })
        if (this.isTodayPick(b)) {
          Text('今日荐书')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(ACCENT)
            .borderRadius(999)
            .margin(8)
        }
      }
      .width('100%')

      Column({ space: 4 }) {
        Text(b.title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#26201C')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(b.author)
          .fontSize(11)
          .fontColor('#8A837C')
        Row({ space: 6 }) {
          Rating({ rating: b.rating, indicator: false })
            .stars(5)
            .width(70)
            .height(14)
            .enabled(false)
          Text(b.rating.toFixed(1))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(GOLD)
        }
        .width('100%')

        Row({ space: 6 }) {
          Progress({ value: b.progress, type: ProgressType.Linear })
            .width('100%')
            .height(4)
            .color(ACCENT)
            .backgroundColor('#E7E4DE')
          Text(String(b.progress) + '%')
            .fontSize(10)
            .fontColor('#8A837C')
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .onClick(() => this.openBook(b))
  }

  // 详情价格行：改为星级 + 评分 + 阅读进度
  @Builder
  bookPriceLine() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Rating({ rating: this.selected.rating, indicator: false })
          .stars(5)
          .width(96)
          .height(18)
          .enabled(false)
        Text(this.selected.rating.toFixed(1) + ' 分')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(GOLD)
        Text(this.selected.category === 'novel' ? '小说'
          : this.selected.category === 'history' ? '历史'
            : this.selected.category === 'tech' ? '科技' : '人文')
          .fontSize(12)
          .fontColor('#5A514C')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(ACCENT_SOFT)
          .borderRadius(999)
      }
      .width('100%')

      Row({ space: 8 }) {
        Progress({ value: this.selected.progress, type: ProgressType.Linear })
          .width(120)
          .height(6)
          .color(ACCENT)
        Text('在读 ' + String(this.selected.progress) + '%')
          .fontSize(13)
          .fontColor('#8A837C')
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  bookBody() {
    Column({ space: 14 }) {
      Row({ space: 6 }) {
        ForEach(this.selected.tags, (tag: string) => {
          TagChip({ text: tag, fg: ACCENT, bg: ACCENT_SOFT, fontSize: 11 })
        }, (tag: string) => tag)
      }
      .width('100%')

      Text(this.selected.intro)
        .fontSize(14)
        .fontColor('#5A514C')
        .lineHeight(22)
        .width('100%')

      Text('「' + this.selected.quote + '」')
        .fontSize(13)
        .fontColor('#8A837C')
        .lineHeight(20)
        .width('100%')

      Text('开始阅读 →')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 13, bottom: 13 })
        .backgroundColor(ACCENT)
        .borderRadius(999)
        .onClick(() => {
          try {
            this.getUIContext().getPromptAction().showToast({
              message: '翻开「' + this.selected.title + '」，陪你读下去 📖',
              duration: 1500
            });
          } catch (e) {
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  bookSheet() {
    Column() {
      SheetHero({
        emoji: bookEmoji(this.selected.imageKey),
        gradient: BOOK_GRADIENTS[this.selected.gradient],
        title: this.selected.title,
        badgeText: this.isTodayPick(this.selected) ? '荐' : '',
        badgeBg: ACCENT
      })

      Scroll() {
        Column({ space: 14 }) {
          this.bookPriceLine()
          Divider()
            .color('#EFECE7')
          this.bookBody()
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

  build() {
    NavDestination() {
      Column() {
        // 头部：返回 + 书局品牌 + 每日荐书入口
        Row({ space: 10 }) {
          Text('‹ 返回')
            .fontSize(15)
            .fontColor(ACCENT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(ACCENT_SOFT)
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pop();
            })
          Column({ space: 2 }) {
            Text('拾光书局')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#26201C')
            Text('一卷时光 · 满架书香')
              .fontSize(12)
              .fontColor('#8C8078')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('每日荐书 ›')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(ACCENT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(ACCENT_SOFT)
            .borderRadius(999)
            .onClick(() => this.openDailyPick())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        // 活内容条：每日荐书（按天轮换，与「每日荐书」页同一 pickDaily 同源联动）
        TimeDealBar({
          title: '每日荐书',
          slotLabel: this.dayLabel,
          onTick: (v: number) => this.onTick(v),
          content: this.recommendStripContent
        })
        .padding({ left: 16, right: 16 })
        .margin({ top: 8, bottom: 12 })

        // 分类
        Row({ space: 8 }) {
          ForEach(BOOK_CATEGORIES, (c: BookCategory) => {
            this.filterChip(c.name, this.catId === c.id, () => this.onCat(c.id))
          }, (c: BookCategory) => c.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 10 })

        // 书架：双列 Grid
        Grid() {
          ForEach(this.books, (b: Book) => {
            GridItem() {
              this.bookCard(b)
            }
          }, (b: Book) => b.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F6F3')
      .bindSheet(
        $$this.showDetail,
        this.bookSheet(),
        { height: SheetSize.MEDIUM, dragBar: true, showClose: true }
      )
    }
    .title('拾光书局')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}