import { ChatMessagePhase, MessageFeedback, MessageRole } from '../models/ChatModels';
import { MarkdownMessage } from './MarkdownMessage';
import { ChatBubbleActionDispatcher, ChatBubbleActionType } from './ChatBubbleActionDispatcher';

@Component
export struct ChatBubble {
  private static readonly ACTION_ICON_SIZE: number = 12;
  private static readonly ACTION_BUTTON_SIZE: number = 24;
  private static readonly ACTION_BUTTON_RADIUS: number = 12;
  private static readonly ACTION_GROUP_PADDING_V: number = 5;
  private static readonly ACTION_GROUP_PADDING_H: number = 7;

  @Prop messageId: string = '';
  @Prop role: MessageRole = MessageRole.Assistant;
  @Prop content: string = '';
  @Prop isStreaming: boolean = false;
  @Prop statusLabel: string = '';
  @Prop streamPhase: ChatMessagePhase = ChatMessagePhase.Idle;
  @Prop feedback: MessageFeedback = MessageFeedback.None;
  @Prop answerVersionCount: number = 0;
  @Prop activeAnswerVersionIndex: number = 0;
  @Prop isSpeaking: boolean = false;
  @Prop showActions: boolean = false;
  @Prop contentRenderToken: string = '';
  @Prop actionRenderToken: string = '';
  @State private localFeedback: MessageFeedback = MessageFeedback.None;

  aboutToAppear(): void {
    this.localFeedback = this.feedback;
  }

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
                isStreaming: this.isStreaming,
                isAssistant: true,
                streamingLabel: ''
              })
            }
            .width('100%')
            .padding({ left: 6, right: 6 })
          } else {
            this.UserTextBuilder();
          }

          if (this.showActions) {
            ForEach([this.actionRenderToken], (_token: string) => {
              Column() {
                this.AssistantActionsBuilder();
              }
              .width('100%')
              .padding({ left: 4, right: 4 })
            }, (token: string) => token)
          }
        }
        .padding({
          top: this.role === MessageRole.Assistant ? 18 : 20,
          right: this.role === MessageRole.Assistant ? 22 : 20,
          bottom: this.role === MessageRole.Assistant ? 18 : 20,
          left: this.role === MessageRole.Assistant ? 22 : 20
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

  @Builder
  private AssistantActionsBuilder() {
    Row({ space: 6 }) {
      Row({ space: 2 }) {
        this.ActionButtonBuilder('copy', () => {
          ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Copy);
        })

        this.ActionButtonBuilder('regenerate', () => {
          ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Regenerate);
        })

        this.ActionButtonBuilder('delete', () => {
          ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Delete);
        })

        this.ActionButtonBuilder('like', () => {
          this.localFeedback = this.localFeedback === MessageFeedback.Like ? MessageFeedback.None : MessageFeedback.Like;
          ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Like);
        })

        this.ActionButtonBuilder('dislike', () => {
          this.localFeedback = this.localFeedback === MessageFeedback.Dislike ? MessageFeedback.None : MessageFeedback.Dislike;
          ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Dislike);
        })

        this.ActionButtonBuilder('sound', () => {
          ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Sound);
        })
      }
      .padding({
        top: ChatBubble.ACTION_GROUP_PADDING_V,
        right: ChatBubble.ACTION_GROUP_PADDING_H,
        bottom: ChatBubble.ACTION_GROUP_PADDING_V,
        left: ChatBubble.ACTION_GROUP_PADDING_H
      })
      .backgroundColor('#FFFFFF')
      .borderRadius(15)
      .border({
        width: 1,
        color: '#E2E8F0'
      })
      .alignSelf(ItemAlign.Start)

      Blank()

      if (this.answerVersionCount > 1) {
        Row({ space: 4 }) {
          Button() {
            Image($r('app.media.icon_ai_previous'))
              .width(ChatBubble.ACTION_ICON_SIZE)
              .height(ChatBubble.ACTION_ICON_SIZE)
              .objectFit(ImageFit.Contain)
              .opacity(this.activeAnswerVersionIndex > 0 ? 1 : 0.45)
          }
            .width(ChatBubble.ACTION_BUTTON_SIZE)
            .height(ChatBubble.ACTION_BUTTON_SIZE)
            .backgroundColor('#00000000')
            .borderRadius(ChatBubble.ACTION_BUTTON_RADIUS)
            .padding(0)
            .enabled(this.activeAnswerVersionIndex > 0)
            .onClick(() => {
              if (this.activeAnswerVersionIndex <= 0) {
                return;
              }
              ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Previous);
            })

          Text(`${this.activeAnswerVersionIndex + 1}/${this.answerVersionCount}`)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#64748B')

          Button() {
            Image($r('app.media.icon_ai_next'))
              .width(ChatBubble.ACTION_ICON_SIZE)
              .height(ChatBubble.ACTION_ICON_SIZE)
              .objectFit(ImageFit.Contain)
              .opacity(this.activeAnswerVersionIndex + 1 < this.answerVersionCount ? 1 : 0.45)
          }
            .width(ChatBubble.ACTION_BUTTON_SIZE)
            .height(ChatBubble.ACTION_BUTTON_SIZE)
            .backgroundColor('#00000000')
            .borderRadius(ChatBubble.ACTION_BUTTON_RADIUS)
            .padding(0)
            .enabled(this.activeAnswerVersionIndex + 1 < this.answerVersionCount)
            .onClick(() => {
              if (this.activeAnswerVersionIndex + 1 >= this.answerVersionCount) {
                return;
              }
              ChatBubbleActionDispatcher.dispatch(this.messageId, ChatBubbleActionType.Next);
            })
        }
        .padding({
          top: ChatBubble.ACTION_GROUP_PADDING_V,
          right: ChatBubble.ACTION_GROUP_PADDING_H,
          bottom: ChatBubble.ACTION_GROUP_PADDING_V,
          left: ChatBubble.ACTION_GROUP_PADDING_H
        })
        .backgroundColor('#FFFFFF')
        .borderRadius(15)
        .border({
          width: 1,
          color: '#E2E8F0'
        })
        .alignSelf(ItemAlign.End)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ActionButtonBuilder(action: string, onClick: () => void) {
    Button() {
      Image(this.getActionIconResource(action))
        .width(ChatBubble.ACTION_ICON_SIZE)
        .height(ChatBubble.ACTION_ICON_SIZE)
        .fillColor(this.getActionIconColor(action))
    }
      .width(ChatBubble.ACTION_BUTTON_SIZE)
      .height(ChatBubble.ACTION_BUTTON_SIZE)
      .backgroundColor(this.getActionButtonBackground(action))
      .borderRadius(ChatBubble.ACTION_BUTTON_RADIUS)
      .padding(0)
      .onClick(onClick)
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

  private getActionButtonBackground(action: string): string {
    if (action === 'like' && this.localFeedback === MessageFeedback.Like) {
      return '#DBEAFE';
    }
    if (action === 'dislike' && this.localFeedback === MessageFeedback.Dislike) {
      return '#FEE2E2';
    }
    if (action === 'sound' && this.isSpeaking) {
      return '#CCFBF1';
    }
    return '#F8FAFC';
  }

  private getActionIconColor(action: string): string {
    if (action === 'like' && this.localFeedback === MessageFeedback.Like) {
      return '#2563EB';
    }
    if (action === 'dislike' && this.localFeedback === MessageFeedback.Dislike) {
      return '#DC2626';
    }
    if (action === 'sound' && this.isSpeaking) {
      return '#0F766E';
    }
    if (action === 'delete') {
      return '#64748B';
    }
    return '#475569';
  }

  private getActionIconResource(action: string) {
    if (action === 'copy') {
      return $r('app.media.icon_ai_copy');
    }
    if (action === 'regenerate') {
      return $r('app.media.icon_ai_regenerate');
    }
    if (action === 'delete') {
      return $r('app.media.icon_ai_delete');
    }
    if (action === 'like') {
      return $r('app.media.icon_ai_thumb_up');
    }
    if (action === 'dislike') {
      return $r('app.media.icon_ai_thumb_down');
    }
    return $r('app.media.icon_ai_sound');
  }

}
