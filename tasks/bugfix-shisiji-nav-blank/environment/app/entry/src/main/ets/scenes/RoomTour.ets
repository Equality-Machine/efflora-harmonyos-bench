// 云栖酒店 · 专属第二页：全景看房
// 全屏沉浸深蓝页：慢速轮播同一间房的多角度"景别"（emoji + 渐变占位），验收"换场景即换产品"。
import {
  Room, ROOMS, HOTEL_GRADIENTS, roomEmoji, roomById, specialPool, HOTEL_SLOTS, tourRoomId
} from '../model/HotelData';
import { nowHour, hourLabel, pickHourly } from '../common/TimeRules';
import { formatPrice } from '../common/Unit';
import { Placeholder } from '../common/Placeholder';

const GOLD = '#FFC069';

@Component
export struct RoomTour {
  @Consume pathStack: NavPathStack;
  @State room: Room = ROOMS[0];
  @State slotLabel: string = hourLabel(HOTEL_SLOTS, nowHour());

  aboutToAppear(): void {
    this.room = roomById(tourRoomId);
  }

  // 当前房型是否命中本时段特价（与列表页同一规则，同源一致）
  isTodayPick(): boolean {
    const picks = pickHourly(specialPool(), nowHour(), 2);
    for (const p of picks) {
      if (p.id === this.room.id) {
        return true;
      }
    }
    return false;
  }

  // 单个"景别"：全屏渐变底 + 大 emoji + 底部景别名/描述
  @Builder
  tourSlide(angle: string, desc: string, gradIdx: number) {
    Stack({ alignContent: Alignment.BottomStart }) {
      Placeholder({
        emoji: roomEmoji(this.room.imageKey),
        gradient: HOTEL_GRADIENTS[gradIdx],
        boxWidth: '100%',
        boxHeight: '100%',
        corner: 0,
        emojiSize: 140
      })
      // 底部暗色渐变衬托文案
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#00000000', 0.5], ['#B3000000', 1.0]]
        })
      Column({ space: 6 }) {
        Text(angle)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text(desc)
          .fontSize(13)
          .fontColor('#BCD3E8')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(24)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    NavDestination() {
      Column() {
        // 顶栏：返回 + 标题
        Row() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor('#DCE8F2')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor('#1F3A52')
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pop();
            })
          Blank()
          Text('全景看房 · ' + this.slotLabel)
            .fontSize(13)
            .fontColor('#8DA7BC')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })

        // 多角度慢速轮播
        Swiper() {
          this.tourSlide('正面视角', '全屋一览 · 光线透亮', 0)
          this.tourSlide('窗景视角', '落地窗正对湖面', 1)
          this.tourSlide('配套视角', '浴室 · 阳台 · 独立浴缸', 3)
        }
        .layoutWeight(1)
        .width('100%')
        .loop(true)
        .autoPlay(true)
        .interval(4000)
        .duration(700)
        .indicator(true)

        // 底部信息：房名 / 价格 / 特价 pill / 文案
        Row() {
          Column({ space: 4 }) {
            Text(this.room.name)
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
            Text(this.room.area + '㎡ · ' + this.room.floor)
              .fontSize(14)
              .fontColor('#8DA7BC')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Column({ space: 4 }) {
            Row({ space: 4 }) {
              Text('¥')
                .fontSize(18)
                .fontColor(GOLD)
              Text(formatPrice(this.room.priceCents))
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(GOLD)
            }
            if (this.isTodayPick()) {
              Text('限时特价 · ' + this.slotLabel)
                .fontSize(12)
                .fontColor('#FFE1DE')
            } else {
              Text('门市价')
                .fontSize(12)
                .fontColor('#6E8296')
            }
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 20 })

        Text('枕湖而眠 · 推窗即是山色湖光')
          .fontSize(13)
          .fontColor('#6E8296')
          .padding({ bottom: 12 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#0F2438')
    }
    .title('全景看房')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}