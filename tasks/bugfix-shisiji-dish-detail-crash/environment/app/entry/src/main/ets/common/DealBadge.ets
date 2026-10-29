// 角标：circle=true 是"惠/热"小红圆；否则是胶囊小字条（限时特价 / 本周之星 / 每日荐书）

@Component
export struct DealBadge {
  text: string = '惠';
  bg: string = '#E64545';
  fg: string = '#FFFFFF';
  dia: number = 16;           // circle=直径；pill=字号基准
  circle: boolean = false;

  build() {
    if (this.circle) {
      Text(this.text)
        .fontSize(this.dia * 0.66)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.fg)
        .textAlign(TextAlign.Center)
        .width(this.dia)
        .height(this.dia)
        .borderRadius(999)
        .backgroundColor(this.bg)
    } else {
      Text(this.text)
        .fontSize(this.dia)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.fg)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor(this.bg)
        .borderRadius(999)
    }
  }
}