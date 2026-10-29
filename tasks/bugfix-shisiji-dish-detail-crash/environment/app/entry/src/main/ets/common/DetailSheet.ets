// 通用详情半模态壳体：大图区（Placeholder）→ 标题 + 右上角标 → 价格行(@BuilderParam priceLine) → 分割线 → 自定义正文(@BuilderParam body)
// 四模块详情弹层复用；餐厅的"规格选择"正文也注入 body，其点位与交互由页面自持。

import { Placeholder } from './Placeholder';
import { DealBadge } from './DealBadge';

// 顶层空构建器：@BuilderParam 的兜底默认值（不能引用 this）
@Builder
function emptySlot() {
}

@Component
export struct DetailSheet {
  emoji: string = '';
  gradient: string[] = [];
  media: Resource | undefined = undefined;
  title: string = '';
  badgeText: string = '';      // 空则不显示角标
  badgeBg: string = '#E64545';
  showDivider: boolean = true;
  @BuilderParam priceLine: () => void = emptySlot;
  @BuilderParam body: () => void = emptySlot;

  build() {
    Column() {
      // 大图区
      Placeholder({
        emoji: this.emoji,
        gradient: this.gradient,
        media: this.media,
        boxWidth: '100%',
        boxHeight: 200,
        corner: 0,
        emojiSize: 88
      })

      Scroll() {
        Column({ space: 14 }) {
          // 标题 + 角标
          Row({ space: 8 }) {
            Text(this.title)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#211E1A')
            if (this.badgeText !== '') {
              DealBadge({ text: this.badgeText, bg: this.badgeBg, dia: 18, circle: true })
            }
          }
          .width('100%')

          this.priceLine()

          if (this.showDivider) {
            Divider()
              .color('#EFECE7')
          }

          this.body()
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
}