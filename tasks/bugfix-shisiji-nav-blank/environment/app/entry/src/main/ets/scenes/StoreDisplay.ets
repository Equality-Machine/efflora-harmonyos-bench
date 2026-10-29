// 第二页：店内大屏轮播页（NavDestination）
// 复用菜单态数据与今日特惠逻辑 —— "同一份菜单，第二种呈现"：全屏深底、慢速大轮播。
import { Banner, Dish, SIGNATURE_BANNERS, dishById, dishEmoji, dishMedia, formatPrice, dealDishes } from '../model/DiningData';

@Component
export struct StoreDisplay {
  @Consume pathStack: NavPathStack;
  private deals: Dish[] = dealDishes();

  @Builder
  bigSlide(b: Banner) {
    Stack() {
      // 占位底层：照片缺失/透明时透出
      Text(dishEmoji(dishById(b.dishId).image))
        .fontSize(112)
        .opacity(0.9)
      // 照片层
      Image(dishMedia(dishById(b.dishId).image))
        .objectFit(ImageFit.Cover)
        .width('100%')
        .height('100%')
      // 底部阴影蒙层，衬托文字
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#00000000', 0.0], ['#B3000000', 1.0]]
        })
      // 主文案（垂直居中）
      Column({ space: 12 }) {
        Text(b.title)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
        Text(b.subtitle)
          .fontSize(16)
          .fontColor('#D9CFC4')
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .padding({ left: 24, right: 24 })
      // 价格（左下角）
      Column({ space: 4 }) {
        Row({ space: 4 }) {
          Text('¥')
            .fontSize(20)
            .fontColor('#FFC069')
          Text(formatPrice(dishById(b.dishId).price))
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFC069')
        }
        if (dishById(b.dishId).originalPrice !== undefined) {
          Text('原价 ¥' + formatPrice(dishById(b.dishId).originalPrice!))
            .fontSize(13)
            .fontColor('#6E625A')
            .decoration({ type: TextDecorationType.LineThrough })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#4D000000')
      .borderRadius(12)
      .position({ x: 20, y: '82%' })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Text('‹ 返回菜单')
            .fontSize(16)
            .fontColor('#E8E0D8')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#2A211C')
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pop();
            })
          Blank()
          Text('店内大屏 · 招牌菜轮播')
            .fontSize(14)
            .fontColor('#8C8078')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })

        Swiper() {
          ForEach(SIGNATURE_BANNERS, (b: Banner) => {
            this.bigSlide(b)
          }, (b: Banner) => b.id)
        }
        .layoutWeight(1)
        .width('100%')
        .loop(true)
        .autoPlay(true)
        .interval(4500)
        .duration(700)
        .indicator(true)

        // 底部：今日特惠条（复用时段轮换逻辑）
        Row({ space: 10 }) {
          Text('今日特惠')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFC069')
          Blank()
        }
        .width('100%')

        Scroll() {
          Row({ space: 12 }) {
            ForEach(this.deals, (d: Dish) => {
              Column({ space: 4 }) {
                Text(d.name)
                  .fontSize(15)
                  .fontColor(Color.White)
                Row({ space: 4 }) {
                  Text('¥' + formatPrice(d.price))
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFC069')
                  if (d.originalPrice !== undefined) {
                    Text('¥' + formatPrice(d.originalPrice))
                      .fontSize(11)
                      .fontColor('#6E625A')
                      .decoration({ type: TextDecorationType.LineThrough })
                  }
                }
              }
              .alignItems(HorizontalAlign.Start)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .backgroundColor('#2A211C')
              .borderRadius(12)
            }, (d: Dish) => d.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(64)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#14100C')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .title('店内大屏')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}