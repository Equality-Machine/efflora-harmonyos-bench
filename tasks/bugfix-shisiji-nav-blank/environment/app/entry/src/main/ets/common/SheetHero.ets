// 通用详情弹层"头部"：大图（Placeholder）+ 标题 + 右上角标。
// 数据化组件（纯 props、无 @BuilderParam 槽位）——避免 bindSheet 弹窗内 @BuilderParam 代管父级 builder
// 在二次渲染时 `this` 失效的运行时崩溃。正文（价格行/标签/规格/按钮）由各页面在自己的 sheet builder 里直连渲染。
import { Placeholder } from './Placeholder';
import { DealBadge } from './DealBadge';

@Component
export struct SheetHero {
  emoji: string = '';
  gradient: string[] = [];
  media: Resource | undefined = undefined;
  title: string = '';
  badgeText: string = '';      // 空则不显示角标
  badgeBg: string = '#E64545';

  build() {
    Column() {
      Placeholder({
        emoji: this.emoji,
        gradient: this.gradient,
        media: this.media,
        boxWidth: '100%',
        boxHeight: 200,
        corner: 0,
        emojiSize: 88
      })

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
      .padding({ left: 20, right: 20, top: 16, bottom: 4 })
    }
    .width('100%')
  }
}