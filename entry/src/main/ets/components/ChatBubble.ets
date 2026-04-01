import { MessageRole } from '../models/ChatModels';
import { MarkdownMessage } from './MarkdownMessage';

@Component
export struct ChatBubble {
  @Prop role: MessageRole = MessageRole.Assistant;
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;

  build() {
    Row({ space: 12 }) {
      if (this.role === MessageRole.Assistant) {
        this.AvatarBuilder('AI', '#D9F99D', '#14532D');
      }

      Column({ space: 8 }) {
        Text(this.role === MessageRole.Assistant ? 'Assistant' : 'You')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.role === MessageRole.Assistant ? '#64748B' : '#526D89')

        Column() {
          MarkdownMessage({
            content: this.content,
            isStreaming: this.isStreaming,
            isAssistant: this.role === MessageRole.Assistant
          })
        }
        .width('100%')
        .padding({ top: 14, right: 16, bottom: 14, left: 16 })
        .backgroundColor(this.role === MessageRole.Assistant ? '#FFFFFF' : '#123B5D')
        .borderRadius(24)
        .shadow({
          radius: 24,
          color: this.role === MessageRole.Assistant ? '#12000000' : '#250D253B',
          offsetX: 0,
          offsetY: 8
        })
      }
      .width('84%')
      .alignItems(HorizontalAlign.Start)

      if (this.role === MessageRole.User) {
        this.AvatarBuilder('ME', '#C7D2FE', '#1E3A8A');
      }
    }
    .width('100%')
    .justifyContent(this.role === MessageRole.Assistant ? FlexAlign.Start : FlexAlign.End)
    .alignItems(VerticalAlign.Bottom)
  }

  @Builder
  private AvatarBuilder(label: string, backgroundColor: string, textColor: string) {
    Text(label)
      .width(36)
      .height(36)
      .textAlign(TextAlign.Center)
      .fontSize(11)
      .fontWeight(FontWeight.Bold)
      .fontColor(textColor)
      .backgroundColor(backgroundColor)
      .borderRadius(18)
  }
}
