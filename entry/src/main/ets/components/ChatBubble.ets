import { ChatMessagePhase, MessageRole } from '../models/ChatModels';
import { MarkdownMessage } from './MarkdownMessage';

@Component
export struct ChatBubble {
  @Prop role: MessageRole = MessageRole.Assistant;
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;
  @Prop statusLabel: string = '';
  @Prop streamPhase: ChatMessagePhase = ChatMessagePhase.Idle;
  @BuilderParam actionContent?: () => void;

  build() {
    Column({ space: 8 }) {
      if (this.shouldShowThinkingOnly()) {
        this.StreamingStatusBuilder();
      } else {
        Column({ space: 14 }) {
          if (this.role === MessageRole.Assistant) {
            Column() {
              MarkdownMessage({
                content: this.content,
                isStreaming: false,
                isAssistant: true,
                streamingLabel: ''
              })
            }
            .width('100%')
            .padding({ left: 6, right: 6 })
          } else {
            this.UserTextBuilder();
          }

          if (this.actionContent !== undefined) {
            Column() {
              this.actionContent();
            }
            .width('100%')
            .padding({ left: 4, right: 4 })
          }
        }
        .padding({
          top: this.role === MessageRole.Assistant ? 18 : 20,
          right: this.role === MessageRole.Assistant ? 22 : 24,
          bottom: this.role === MessageRole.Assistant ? 18 : 20,
          left: this.role === MessageRole.Assistant ? 22 : 24
        })
        .constraintSize({
          maxWidth: this.role === MessageRole.Assistant ? '88%' : '78%'
        })
        .backgroundColor(this.getBubbleBackgroundColor())
        .borderRadius(this.role === MessageRole.Assistant ? 20 : 22)
        .border(this.role === MessageRole.Assistant ? {
          width: 1,
          color: '#EEF2F7'
        } : {
          width: 0,
          color: '#00000000'
        })
        .shadow({
          radius: this.role === MessageRole.Assistant ? 18 : 14,
          color: this.role === MessageRole.Assistant ? '#120F172A' : '#180F3D91',
          offsetX: 0,
          offsetY: 6
        })
        .clip(true)

        if (this.shouldShowStreamingHint()) {
          this.StreamingStatusBuilder();
        }
      }
    }
    .width('100%')
    .alignItems(this.role === MessageRole.Assistant ? HorizontalAlign.Start : HorizontalAlign.End)
  }

  @Builder
  private StreamingStatusBuilder() {
    Row({ space: 8 }) {
      Column()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(this.getStreamingAccentColor())

      Text(this.getStreamingHintText())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getStreamingTextColor())
    }
    .padding({ top: 6, right: 12, bottom: 6, left: 12 })
    .backgroundColor(this.getStreamingBackgroundColor())
    .borderRadius(999)
    .border({
      width: 1,
      color: this.getStreamingBorderColor()
    })
  }

  @Builder
  private UserTextBuilder() {
    Text(this.content)
      .fontSize(15)
      .lineHeight(24)
      .fontColor('#FFFFFF')
      .fontWeight(FontWeight.Medium)
      .wordBreak(WordBreak.BREAK_WORD)
      .textAlign(TextAlign.Start)
  }

  private shouldShowThinkingOnly(): boolean {
    return this.role === MessageRole.Assistant && this.isStreaming && this.content.trim().length === 0;
  }

  private shouldShowStreamingHint(): boolean {
    return this.role === MessageRole.Assistant &&
      this.isStreaming &&
      this.content.trim().length > 0 &&
      (this.streamPhase === ChatMessagePhase.Sending ||
        this.streamPhase === ChatMessagePhase.Thinking ||
        this.streamPhase === ChatMessagePhase.Answering);
  }

  private getStreamingHintText(): string {
    if (this.statusLabel.trim().length > 0 &&
      this.statusLabel !== '已结束' &&
      this.statusLabel !== '已停止' &&
      this.statusLabel !== '出错') {
      return this.normalizeStreamingLabel(this.statusLabel);
    }
    if (this.streamPhase === ChatMessagePhase.Answering) {
      return 'AI 正在回答';
    }
    return 'AI 正在思考';
  }

  private getBubbleBackgroundColor(): string {
    if (this.role === MessageRole.Assistant) {
      return '#F7F8FA';
    }
    return '#5EA2F8';
  }

  private normalizeStreamingLabel(label: string): string {
    if (label === 'AI 正在思考中') {
      return 'AI 正在思考';
    }
    if (label === 'AI 正在回答中') {
      return 'AI 正在回答';
    }
    return label;
  }

  private getStreamingBackgroundColor(): string {
    if (this.streamPhase === ChatMessagePhase.Answering) {
      return '#E8F1FF';
    }
    if (this.streamPhase === ChatMessagePhase.Sending) {
      return '#FEF3E6';
    }
    return '#EAFBF3';
  }

  private getStreamingBorderColor(): string {
    if (this.streamPhase === ChatMessagePhase.Answering) {
      return '#CFE0FF';
    }
    if (this.streamPhase === ChatMessagePhase.Sending) {
      return '#F8D7AA';
    }
    return '#CBEFD9';
  }

  private getStreamingTextColor(): string {
    if (this.streamPhase === ChatMessagePhase.Answering) {
      return '#2F6FEB';
    }
    if (this.streamPhase === ChatMessagePhase.Sending) {
      return '#C57A10';
    }
    return '#1E9B63';
  }

  private getStreamingAccentColor(): string {
    if (this.streamPhase === ChatMessagePhase.Answering) {
      return '#5EA2F8';
    }
    if (this.streamPhase === ChatMessagePhase.Sending) {
      return '#F2A93B';
    }
    return '#34C27E';
  }
}
