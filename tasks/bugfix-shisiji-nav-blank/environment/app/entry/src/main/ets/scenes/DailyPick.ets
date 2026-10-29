// 拾光书局 · 专属第二页：每日荐书
// 墨绿沉浸页：今日 1 本荐书大卡（与列表页活内容条用同一个 pickDaily —— 同源联动），星级 + 阅读进度环 + 摘抄。
import { Book, BOOK_GRADIENTS, bookEmoji, recommendPool } from '../model/BookData';
import { dayIndex, weekdayLabel, pickDaily } from '../common/TimeRules';
import { Placeholder } from '../common/Placeholder';
import { TagChip } from '../common/TagChip';

const ACCENT = '#2E6B4F';
const GOLD = '#E8C877';

@Component
export struct DailyPick {
  @State book: Book = pickDaily(recommendPool(), dayIndex(), 1)[0];
  @Consume pathStack: NavPathStack;

  read(): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: '翻开「' + this.book.title + '」，陪你读下去 📖',
        duration: 1500
      });
    } catch (e) {
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 顶栏：返回 + 标题
        Row() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor('#DCE8D8')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#244A38')
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pop();
            })
          Blank()
          Text('每日荐书 · ' + weekdayLabel())
            .fontSize(13)
            .fontColor('#9DB8A8')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })

        Scroll() {
          Column({ space: 16 }) {
            // 今日荐书大卡
            Column({ space: 12 }) {
              // 封面
              Placeholder({
                emoji: bookEmoji(this.book.imageKey),
                gradient: BOOK_GRADIENTS[this.book.gradient],
                boxWidth: '100%',
                boxHeight: 240,
                corner: 20,
                emojiSize: 100
              })

              Column({ space: 6 }) {
                Text(this.book.title)
                  .fontSize(30)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                Text(this.book.author)
                  .fontSize(15)
                  .fontColor('#9DB8A8')
                Row({ space: 8 }) {
                  Rating({ rating: this.book.rating, indicator: false })
                    .stars(5)
                    .width(110)
                    .height(20)
                    .enabled(false)
                  Text(this.book.rating.toFixed(1) + ' 分')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(GOLD)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
            }
            .padding(18)
            .backgroundColor('#1D3A2C')
            .borderRadius(24)

            // 摘抄
            Text('「' + this.book.quote + '」')
              .fontSize(16)
              .fontColor('#DCE8D8')
              .lineHeight(26)
              .width('100%')
              .padding({ left: 4 })

            // 进度环 + 简介
            Row({ space: 12 }) {
              Stack() {
                Progress({ value: this.book.progress, type: ProgressType.Ring })
                  .width(72)
                  .height(72)
                  .color(GOLD)
                  .backgroundColor('#244A38')
                Text(String(this.book.progress) + '%')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              Column({ space: 6 }) {
                Row({ space: 6 }) {
                  ForEach(this.book.tags, (tag: string) => {
                    TagChip({ text: tag, fg: '#9DB8A8', bg: '#244A38', fontSize: 11 })
                  }, (tag: string) => tag)
                }
                Text(this.book.intro)
                  .fontSize(13)
                  .fontColor('#9DB8A8')
                  .lineHeight(20)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            // 开始阅读
            Text('开始阅读 →')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1D3A2C')
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .backgroundColor(GOLD)
              .borderRadius(999)
              .onClick(() => this.read())

            Text('明天见 · 书单会更新')
              .fontSize(12)
              .fontColor('#9DB8A8')
              .width('100%')
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#0F241A')
    }
    .title('每日荐书')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}