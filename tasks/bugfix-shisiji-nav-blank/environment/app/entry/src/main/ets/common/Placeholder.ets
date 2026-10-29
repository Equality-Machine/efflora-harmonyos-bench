// 图占位：渐变底 + emoji（+ 可选照片层覆盖）
// 照片缺失/透明时 emoji+渐变自动透出兜底；填入媒体资源即覆盖为真图——"无图不坏、有图即显"。

@Component
export struct Placeholder {
  emoji: string = '';
  gradient: string[] = [];
  media: Resource | undefined = undefined;
  boxWidth: string | number = 72;
  boxHeight: string | number = 72;
  corner: number = 12;
  emojiSize: number = 32;

  build() {
    Stack() {
      Text(this.emoji)
        .fontSize(this.emojiSize)
      if (this.media !== undefined) {
        Image(this.media)
          .objectFit(ImageFit.Cover)
          .width('100%')
          .height('100%')
      }
    }
    .width(this.boxWidth)
    .height(this.boxHeight)
    .linearGradient({
      angle: 135,
      colors: [[this.gradient[0], 0.0], [this.gradient[1], 1.0]]
    })
    .borderRadius(this.corner)
    .clip(true)
  }
}