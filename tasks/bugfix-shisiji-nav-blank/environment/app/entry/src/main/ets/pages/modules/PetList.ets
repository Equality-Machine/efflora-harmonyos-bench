// 模块三 · 宠物领养「暖爪之家」列表页（NavDestination）
// WaterFlow 瀑布流（高度错落）+ 物种筛选 + 本周之星活内容条(按天) + 详情 DetailSheet + 领养申请入口
import {
  Pet, SpeciesFilter, SPECIES_FILTERS, PETS, PET_GRADIENTS, petEmoji,
  filterPets, starPool, setAdoptPetId
} from '../../model/PetData';
import { dayIndex, weekdayLabel, pickDaily } from '../../common/TimeRules';
import { Placeholder } from '../../common/Placeholder';
import { TagChip } from '../../common/TagChip';
import { SheetHero } from '../../common/SheetHero';
import { TimeDealBar } from '../../common/TimeDealBar';

const ACCENT = '#E86A92';       // 暖爪之家 · 桃粉
const ACCENT_SOFT = '#FDEFF4';

// 月龄 → 可读文案：8 → "8 个月"；14 → "1 岁 2 个月"
function ageText(months: number): string {
  if (months < 12) {
    return String(months) + ' 个月';
  }
  const y = Math.floor(months / 12);
  const m = months % 12;
  return String(y) + ' 岁' + (m > 0 ? ' ' + String(m) + ' 个月' : '');
}

@Component
export struct PetList {
  // 品种筛选
  @State speciesId: string = 'all';
  @State pets: Pet[] = filterPets('all');
  // 本周领养之星"随时间变"：按"天"从之星池轮换出 1 只
  @State stars: Pet[] = pickDaily(starPool(), dayIndex(), 1);
  @State starLabel: string = '本周之星 · ' + weekdayLabel();
  @State selected: Pet = PETS[0];
  @State showDetail: boolean = false;
  @Consume pathStack: NavPathStack;

  onTickStars(value: number): void {
    // 以"天"为单位轮换（分钟级回调触发后重算；同一天内稳定）
    this.stars = pickDaily(starPool(), dayIndex(), 1);
    this.starLabel = '本周之星 · ' + weekdayLabel();
  }

  onSpecies(id: string): void {
    this.speciesId = id;
    this.pets = filterPets(id);
  }

  // 是否命中今天的主推之星
  isTodayStar(p: Pet): boolean {
    for (const s of this.stars) {
      if (s.id === p.id) {
        return true;
      }
    }
    return false;
  }

  openPet(p: Pet): void {
    this.selected = p;
    this.showDetail = true;
  }

  // 打开领养申请表：可带意向宠物
  openAdopt(p: Pet): void {
    setAdoptPetId(p.id);
    this.pathStack.pushPathByName('AdoptForm', null);
  }

  openGenericAdopt(): void {
    this.pathStack.pushPathByName('AdoptForm', null);
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

  // 本周之星小卡（活内容条横向滚动）
  @Builder
  starChip(p: Pet) {
    Row({ space: 8 }) {
      Placeholder({
        emoji: petEmoji(p.imageKey),
        gradient: PET_GRADIENTS[p.gradient],
        boxWidth: 44,
        boxHeight: 44,
        corner: 10,
        emojiSize: 24
      })
      Column({ space: 2 }) {
        Text(p.name)
          .fontSize(13)
          .fontColor('#26201C')
        Text(p.breed)
          .fontSize(11)
          .fontColor('#8A837C')
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => this.openPet(p))
  }

  @Builder
  starStripContent() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.stars, (p: Pet) => {
          this.starChip(p)
        }, (p: Pet) => p.id)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .height(66)
  }

  // 瀑布流宠物卡：图片高度随 heightFactor 错落
  @Builder
  petCard(p: Pet) {
    Column({ space: 8 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        Placeholder({
          emoji: petEmoji(p.imageKey),
          gradient: PET_GRADIENTS[p.gradient],
          boxWidth: '100%',
          boxHeight: 122 * p.heightFactor,
          corner: 12,
          emojiSize: 46
        })
        if (this.isTodayStar(p)) {
          Text('今日之星')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#E86A92')
            .borderRadius(999)
            .margin(8)
        }
      }
      .width('100%')

      Column({ space: 3 }) {
        Row() {
          Text(p.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#26201C')
          Blank()
          Text(p.gender)
            .fontSize(11)
            .fontColor('#8A837C')
        }
        .width('100%')

        Text(p.breed + ' · ' + ageText(p.ageMonths))
          .fontSize(11)
          .fontColor('#8A837C')
          .width('100%')

        Row({ space: 4 }) {
          ForEach(p.tags.slice(0, 2), (tag: string) => {
            TagChip({ text: tag, fg: ACCENT, bg: ACCENT_SOFT })
          }, (tag: string) => tag)
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
    .onClick(() => this.openPet(p))
  }

  @Builder
  petPriceLine() {
    Row({ space: 8 }) {
      Text('领养免费')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(ACCENT)
      Text(this.selected.vaccinated ? '已接种 ✓' : '待接种')
        .fontSize(12)
        .fontColor('#5A514C')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(ACCENT_SOFT)
        .borderRadius(999)
      Text(this.selected.neutered ? '已绝育 ✓' : '未绝育')
        .fontSize(12)
        .fontColor('#5A514C')
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(ACCENT_SOFT)
        .borderRadius(999)
    }
    .width('100%')
  }

  @Builder
  petBody() {
    Column({ space: 14 }) {
      Row({ space: 6 }) {
        ForEach(this.selected.tags, (tag: string) => {
          TagChip({ text: tag, fg: ACCENT, bg: ACCENT_SOFT, fontSize: 11 })
        }, (tag: string) => tag)
      }
      .width('100%')

      Text(this.selected.breed + ' · ' + ageText(this.selected.ageMonths) + ' · ' + this.selected.gender)
        .fontSize(13)
        .fontColor('#8A837C')
        .width('100%')

      Text(this.selected.story)
        .fontSize(14)
        .fontColor('#5A514C')
        .lineHeight(22)
        .width('100%')

      Text('📍 ' + this.selected.location)
        .fontSize(13)
        .fontColor('#8A837C')
        .width('100%')

      // 领养申请入口
      Text('申请领养 · 给TA一个家 🏡')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 13, bottom: 13 })
        .backgroundColor(ACCENT)
        .borderRadius(999)
        .onClick(() => this.openAdopt(this.selected))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  petSheet() {
    Column() {
      SheetHero({
        emoji: petEmoji(this.selected.imageKey),
        gradient: PET_GRADIENTS[this.selected.gradient],
        title: this.selected.name + ' · ' + this.selected.breed,
        badgeText: this.isTodayStar(this.selected) ? '之星' : '',
        badgeBg: ACCENT
      })

      Scroll() {
        Column({ space: 14 }) {
          this.petPriceLine()
          Divider()
            .color('#EFECE7')
          this.petBody()
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

  build() {
    NavDestination() {
      Column() {
        // 头部：返回 + 救助站品牌 + 登记入口
        Row({ space: 10 }) {
          Text('‹ 返回')
            .fontSize(15)
            .fontColor(ACCENT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(ACCENT_SOFT)
            .borderRadius(999)
            .onClick(() => {
              this.pathStack.pop();
            })
          Column({ space: 2 }) {
            Text('暖爪之家')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#26201C')
            Text('领养代替购买 · 一个暖窝换一生陪伴')
              .fontSize(12)
              .fontColor('#8C8078')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('登记领养 ›')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(ACCENT)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(ACCENT_SOFT)
            .borderRadius(999)
            .onClick(() => this.openGenericAdopt())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        // 活内容条：本周领养之星（按天轮换）
        TimeDealBar({
          title: '本周领养之星',
          slotLabel: this.starLabel,
          onTick: (v: number) => this.onTickStars(v),
          content: this.starStripContent
        })
        .padding({ left: 16, right: 16 })
        .margin({ top: 8, bottom: 12 })

        // 物种筛选
        Row({ space: 8 }) {
          ForEach(SPECIES_FILTERS, (s: SpeciesFilter) => {
            this.filterChip(s.name, this.speciesId === s.id, () => this.onSpecies(s.id))
          }, (s: SpeciesFilter) => s.id)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 10 })

        // 待领养宠物：瀑布流（高度错落）
        WaterFlow() {
          ForEach(this.pets, (p: Pet) => {
            FlowItem() {
              this.petCard(p)
            }
          }, (p: Pet) => p.id)
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
        this.petSheet(),
        { height: SheetSize.MEDIUM, dragBar: true, showClose: true }
      )
    }
    .title('暖爪之家')
    .hideTitleBar(true)
    .onBackPressed(() => {
      this.pathStack.pop();
      return true;
    })
  }
}