// 活内容条：标题 + 右侧操作/档位 + 分钟级 TextClock → 触发页面 onTick 重算"当前活动项"
// 页面自己用 TimeRules 算好 slotLabel 与活动数据，传给本条的 content 渲染（类型由页面自持）。

// 顶层空构建器：@BuilderParam 兜底默认值
@Builder
function emptySlot() {
}

@Component
export struct TimeDealBar {
  title: string = '';
  slotLabel: string = '';                    // 当前档位文案（页面算好传入）
  actionText: string = '';                   // 右侧按钮文案（如「店内大屏」），空则不显示
  onAction: () => void = () => {};
  onTick: (value: number) => void = () => {};
  @BuilderParam content: () => void = emptySlot;

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#211E1A')
        Blank()
        if (this.actionText !== '') {
          Text(this.actionText + ' ›')
            .fontSize(12)
            .fontColor('#FF6B35')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#FFEADF')
            .borderRadius(999)
            .onClick(() => this.onAction())
        }
        if (this.slotLabel !== '') {
          Text(this.slotLabel)
            .fontSize(11)
            .fontColor('#8A837C')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#F1EEE9')
            .borderRadius(999)
        }
        TextClock()
          .format('HH:mm')
          .fontSize(12)
          .fontColor('#8A837C')
          .onDateChange((v: number) => {
            this.onTick(v)
          })
      }
      .width('100%')

      this.content()
    }
    .width('100%')
  }
}