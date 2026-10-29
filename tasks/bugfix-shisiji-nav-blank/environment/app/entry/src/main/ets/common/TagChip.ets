// 标签胶囊：统一的细分小标签（招牌/湖景/亲人/在读…）

@Component
export struct TagChip {
  text: string = '';
  fg: string = '#2E7D5B';
  bg: string = '#EAF6EF';
  fontSize: number = 10;

  build() {
    Text(this.text)
      .fontSize(this.fontSize)
      .fontColor(this.fg)
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .backgroundColor(this.bg)
      .borderRadius(999)
  }
}