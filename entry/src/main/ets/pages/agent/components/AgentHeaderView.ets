import { HiAgentAppConfigPreview } from '../models/HiAgentModels';

@Component
export struct AgentHeaderView {
  @Prop preview: HiAgentAppConfigPreview = new HiAgentAppConfigPreview();
  onSelectQuery?: (query: string) => void = undefined;

  build() {
    Column({ space: 12 }) {
      if (this.hasPreviewContent()) {
        Row({ space: 12 }) {
          if (this.preview.image.trim().length > 0) {
            Image(this.preview.image)
              .width(52)
              .height(52)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
          } else {
            Row() {
              Text('AI')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2563EB')
            }
            .width(52)
            .height(52)
            .borderRadius(16)
            .backgroundColor('#DBEAFE')
          }

          Column({ space: 4 }) {
            if (this.preview.name.trim().length > 0) {
              Text(this.preview.name)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#0F172A')
                .width('100%')
                .textAlign(TextAlign.Start)
            }

            if (this.preview.openMessage.trim().length > 0) {
              Text(this.preview.openMessage)
                .fontSize(13)
                .lineHeight(20)
                .fontColor('#475569')
                .width('100%')
                .textAlign(TextAlign.Start)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#EAF3FF')
        .borderRadius(18)

        if (this.preview.openQuery.length > 0) {
          Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row }) {
            ForEach(this.preview.openQuery, (query: string) => {
              Button(query)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#64748B')
                .backgroundColor('#FFFFFF')
                .borderRadius(18)
                .padding({ top: 8, right: 14, bottom: 8, left: 14 })
                .margin({ right: 10, bottom: 10 })
                .onClick(() => {
                  if(this.onSelectQuery) {
                    this.onSelectQuery(query);
                  }
                })
            }, (query: string) => query)
          }
          .width('100%')
        }
      }
    }
    .width('100%')
  }

  private hasPreviewContent(): boolean {
    return this.preview.name.trim().length > 0 ||
      this.preview.image.trim().length > 0 ||
      this.preview.openMessage.trim().length > 0 ||
      this.preview.openQuery.length > 0;
  }
}
