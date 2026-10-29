// 模块二 · 酒店房型「云栖酒店」列表页（NavDestination）
// Grid 宫格房型 + 房型/价格双筛选 + 今日特价活内容条(TimeDealBar) + 详情 DetailSheet + 全景看房入口
import {
  Room, TypeFilter, PriceBand, TYPE_FILTERS, PRICE_BANDS, ROOMS, HOTEL_GRADIENTS, roomEmoji,
  filterRooms, specialPool, HOTEL_SLOTS, setTourRoomId
} from '../../model/HotelData';
import { nowHour, hourLabel, pickHourly } from '../../common/TimeRules';
import { formatPrice } from '../../common/Unit';
import { Placeholder } from '../../common/Placeholder';
import { TagChip } from '../../common/TagChip';
import { DetailSheet } from '../../common/DetailSheet';
import { TimeDealBar } from '../../common/TimeDealBar';

const ACCENT = '#1F4E79';       // 云栖酒店 · 深蓝
const ACCENT_SOFT = '#EAF1F8';

@Component
export struct HotelList {
  // 筛选状态：房型 + 价格档，变化即重算列表
  @State typeId: string = 'all';
  @State bandId: string = 'all';
  @State rooms: Room[] = filterRooms('all', 'all');
  // 今日特价"随时间变"：从特价池按小时轮换出 2 间
  @State specials: Room[] = pickHourly(specialPool(), nowHour(), 2);
  @State slotLabel: string = hourLabel(HOTEL_SLOTS, nowHour());
  @State selected: Room = ROOMS[0];
  @State showDetail: boolean = false;
  @Consume pathStack: NavPathStack;

  onTickSpecials(value: number): void {
    const h = new Date(value).getHours();
    this.specials = pickHourly(specialPool(), h, 2);
    this.slotLabel = hourLabel(HOTEL_SLOTS, h);
  }

  onType(id: string): void {
    this.typeId = id;
    this.rooms = filterRooms(id, this.bandId);
  }

  onBand(id: string): void {
    this.bandId = id;
    this.rooms = filterRooms(this.typeId, id);
  }

  // 该房型是否命中今天的特价轮换
  isTodayPick(r: Room): boolean {
    for (const s of this.specials) {
      if (s.id === r.id) {
        return true;
      }
    }
    return false;
  }

  openRoom(r: Room): void {
    this.selected = r;
    this.showDetail = true;
  }

  // 全景看房：写入目标房型后再进沉浸页
  openTour(id: string): void {
    setTourRoomId(id);
    this.pathStack.pushPathByName('RoomTour', null);
  }

  openFeaturedTour(): void {
    this.openTour(this.specials.length > 0 ? this.specials[0].id : ROOMS[0].id);
  }

  @Builder
  specialChip(r: Room) {
    Row({ space: 8 }) {
      Placeholder({
        emoji: roomEmoji(r.imageKey),
        gradient: HOTEL_GRADIENTS[r.gradient],
        boxWidth: 44,
        boxHeight: 44,
        corner: 10,
        emojiSize: 24
      })
      Column({ space: 2 }) {
        Text(r.name)
          .fontSize(12)
          .fontColor('#26201C')
        Row({ space: 4 }) {
          Text('¥' + formatPrice(r.priceCents))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E64545')
          Text('限时特价')
            .fontSize(9)
            .fontColor('#E64545')
        }
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => this.openRoom(r))
  }

  @Builder
  specialStripContent() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.specials, (r: Room) => {
          this.specialChip(r)
        }, (r: Room) => r.id)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(66)
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

  @Builder
  roomCard(r: Room) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Placeholder({
          emoji: roomEmoji(r.imageKey),
          gradient: HOTEL_GRADIENTS[r.gradient],
          boxWidth: '100%',
          boxHeight: 110,
          corner: 12,
          emojiSize: 52
        })
        if (this.isTodayPick(r)) {
          Text('限时特价')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#E64545')
            .borderRadius(999)
            .margin(8)
        }
      }
      .width('100%')

      Column({ space: 4 }) {
        Text(r.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#26201C')
        Row() {
          Row({ space: 2 }) {
            Text('¥')
              .fontSize(12)
              .fontColor(ACCENT)
            Text(formatPrice(r.priceCents))
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(ACCENT)
            Text('起')
              .fontSize(11)
              .fontColor('#B5A9A0')
          }
          Blank()
          Text('月售 ' + r.sales)
            .fontSize(10)
            .fontColor('#B5A9A0')
        }
        .width('100%')

        Row({ space: 4 }) {
          Text(r.area + '㎡')
            .fontSize(11)
            .fontColor('#8A837C')
          Text('·')
            .fontSize(11)
            .fontColor('#B5A9A0')
          Text(r.beds)
            .fontSize(11)
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
    .onClick(() => this.openRoom(r))
  }

  @Builder
  roomPriceLine() {
    Row({ space: 8 }) {
      Row({ space: 2 }) {
        Text('¥')
          .fontSize(16)
          .fontColor(ACCENT)
        Text(formatPrice(this.selected.priceCents))
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(ACCENT)
      }
      Text('起/晚')
        .fontSize(13)
        .fontColor('#8A837C')
      Text(this.selected.breakfast ? '含双早' : '不含早')
        .fontSize(12)
        .fontColor('#8A837C')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(ACCENT_SOFT)
        .borderRadius(999)
    }
    .width('100%')
  }

  // 详情页 2×2 关键信息
  @Builder
  infoCell(label: string, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#26201C')
      Text(label)
        .fontSize(11)
        .fontColor('#8A837C')
    }
    .layoutWeight(1)
  }

  @Builder
  roomBody() {
    Column({ space: 14 }) {
      Row({ space: 6 }) {
        ForEach(this.selected.tags, (tag: string) => {
          TagChip({ text: tag, fg: ACCENT, bg: ACCENT_SOFT, fontSize: 11 })
        }, (tag: string) => tag)
      }
      .width('100%')

      Row() {
        this.infoCell('面积', this.selected.area + '㎡')
        this.infoCell('可住', this.selected.capacity + '人')
        this.infoCell('床型', this.selected.beds)
        this.infoCell('楼层', this.selected.floor)
      }
      .width('100%')

      Text('临湖而居，枕山而眠。落地窗外就是湖光山色；房间标配智能客控与全屋地暖，冬天也有暖意。')
        .fontSize(14)
        .fontColor('#5A514C')
        .lineHeight(22)
        .width('100%')

      // 全景看房入口
      Text('全景看房 →')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(ACCENT)
        .padding({ left: 14, right: 14, top: 9, bottom: 9 })
        .backgroundColor(ACCENT_SOFT)
        .borderRadius(999)
        .onClick(() => this.openTour(this.selected.id))

      // 预订按钮（假动作：Toast 反馈，不加真预订）
      Text('预订一晚 · ¥' + formatPrice(this.selected.priceCents))
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
              message: '已订 · 云栖酒店「' + this.selected.name + '」✅',
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
  roomSheet() {
    DetailSheet({
      emoji: roomEmoji(this.selected.imageKey),
      gradient: HOTEL_GRADIENTS[this.selected.gradient],
      title: this.selected.name,
      badgeText: this.isTodayPick(this.selected) ? '特价' : '',
      badgeBg: '#E64545',
      priceLine: this.roomPriceLine,
      body: this.roomBody
    })
  }

  build() {
    NavDestination() {
      Column() {
        // 头部：品牌 + 全景看房入口
        Row() {
          Column({ space: 2 }) {
            Text('云栖酒店')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#26201C')
            Text('39 间湖景房 · 枕湖而眠')
              .fontSize(12)
              .fontColor('#8C8078')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('全景看房 ›')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(ACCENT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(ACCENT_SOFT)
            .borderRadius(999)
            .onClick(() => this.openFeaturedTour())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        // 活内容条：今日特价房（时间驱动）
        TimeDealBar({
          title: '今日特价房',
          slotLabel: this.slotLabel,
          onTick: (v: number) => this.onTickSpecials(v),
          content: this.specialStripContent
        })
        .padding({ left: 16, right: 16 })
        .margin({ top: 8, bottom: 12 })

        // 筛选：房型
        Row({ space: 8 }) {
          ForEach(TYPE_FILTERS, (t: TypeFilter) => {
            this.filterChip(t.name, this.typeId === t.id, () => this.onType(t.id))
          }, (t: TypeFilter) => t.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        // 筛选：价格档
        Row({ space: 8 }) {
          ForEach(PRICE_BANDS, (b: PriceBand) => {
            this.filterChip(b.name, this.bandId === b.id, () => this.onBand(b.id))
          }, (b: PriceBand) => b.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ top: 8, bottom: 10 })

        // 房型宫格
        Grid() {
          ForEach(this.rooms, (r: Room) => {
            GridItem() {
              this.roomCard(r)
            }
          }, (r: Room) => r.id)
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
        this.roomSheet(),
        { height: SheetSize.MEDIUM, dragBar: true, showClose: true }
      )
    }
    .title('云栖酒店')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}