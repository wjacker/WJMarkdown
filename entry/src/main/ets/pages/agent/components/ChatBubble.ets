import { ChatMessage, ChatMessagePhase, MessageFeedback, MessageRole } from '../models/ChatModels';
import { MarkdownMessage } from './MarkdownMessage';
import { ChatBubbleActionDispatcher, ChatBubbleActionType } from './ChatBubbleActionDispatcher';

@Component
struct ChatBubbleContentArea {
  @ObjectLink message: ChatMessage;

  build() {
    ForEach([this.buildContentToken()], (_token: string) => {
      Column() {
        if (this.message.role === MessageRole.Assistant) {
          Column() {
            MarkdownMessage({
              content: this.message.visibleContent,
              isStreaming: this.message.isStreaming,
              isAssistant: true,
              streamingLabel: ''
            })
          }
          .width('100%')
          .padding({ left: 6, right: 6 })
        } else {
          Text(this.message.visibleContent)
            .fontSize(15)
            .lineHeight(24)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .wordBreak(WordBreak.BREAK_WORD)
            .textAlign(TextAlign.Start)
        }
      }
    }, (token: string) => token)
  }

  private buildContentToken(): string {
    return `${this.message.visibleContent.length}-${this.message.rawContent.length}` +
      `-${this.message.activeAnswerIndex}-${this.message.isStreaming ? '1' : '0'}`;
  }
}

@Component
struct ChatBubbleActionArea {
  private static readonly ACTION_ICON_SIZE: number = 12;
  private static readonly ACTION_BUTTON_SIZE: number = 24;
  private static readonly ACTION_BUTTON_RADIUS: number = 12;
  private static readonly ACTION_GROUP_PADDING_V: number = 5;
  private static readonly ACTION_GROUP_PADDING_H: number = 7;

  @ObjectLink message: ChatMessage;
  @Prop isSpeaking: boolean = false;

  build() {
    ForEach([this.buildActionToken()], (_token: string) => {
      Row({ space: 6 }) {
        Row({ space: 2 }) {
          this.ActionButtonBuilder('copy', () => {
            ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Copy);
          })

          this.ActionButtonBuilder('regenerate', () => {
            ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Regenerate);
          })

          this.ActionButtonBuilder('delete', () => {
            ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Delete);
          })

          this.ActionButtonBuilder('like', () => {
            ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Like);
          })

          this.ActionButtonBuilder('dislike', () => {
            ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Dislike);
          })

          this.ActionButtonBuilder('sound', () => {
            ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Sound);
          })
        }
        .padding({
          top: ChatBubbleActionArea.ACTION_GROUP_PADDING_V,
          right: ChatBubbleActionArea.ACTION_GROUP_PADDING_H,
          bottom: ChatBubbleActionArea.ACTION_GROUP_PADDING_V,
          left: ChatBubbleActionArea.ACTION_GROUP_PADDING_H
        })
        .backgroundColor('#FFFFFF')
        .borderRadius(15)
        .border({
          width: 1,
          color: '#E2E8F0'
        })
        .alignSelf(ItemAlign.Start)

        Blank()

        if (this.message.answerCount > 1) {
          Row({ space: 4 }) {
            Button() {
              Image($r('app.media.icon_ai_previous'))
                .width(ChatBubbleActionArea.ACTION_ICON_SIZE)
                .height(ChatBubbleActionArea.ACTION_ICON_SIZE)
                .objectFit(ImageFit.Contain)
                .opacity(this.message.activeAnswerIndex > 0 ? 1 : 0.45)
            }
              .width(ChatBubbleActionArea.ACTION_BUTTON_SIZE)
              .height(ChatBubbleActionArea.ACTION_BUTTON_SIZE)
              .backgroundColor('#00000000')
              .borderRadius(ChatBubbleActionArea.ACTION_BUTTON_RADIUS)
              .padding(0)
              .enabled(this.message.activeAnswerIndex > 0)
              .onClick(() => {
                if (this.message.activeAnswerIndex <= 0) {
                  return;
                }
                ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Previous);
              })

            Text(`${this.message.activeAnswerIndex + 1}/${this.message.answerCount}`)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#64748B')

            Button() {
              Image($r('app.media.icon_ai_next'))
                .width(ChatBubbleActionArea.ACTION_ICON_SIZE)
                .height(ChatBubbleActionArea.ACTION_ICON_SIZE)
                .objectFit(ImageFit.Contain)
                .opacity(this.message.activeAnswerIndex + 1 < this.message.answerCount ? 1 : 0.45)
            }
              .width(ChatBubbleActionArea.ACTION_BUTTON_SIZE)
              .height(ChatBubbleActionArea.ACTION_BUTTON_SIZE)
              .backgroundColor('#00000000')
              .borderRadius(ChatBubbleActionArea.ACTION_BUTTON_RADIUS)
              .padding(0)
              .enabled(this.message.activeAnswerIndex + 1 < this.message.answerCount)
              .onClick(() => {
                if (this.message.activeAnswerIndex + 1 >= this.message.answerCount) {
                  return;
                }
                ChatBubbleActionDispatcher.dispatch(this.message.id, ChatBubbleActionType.Next);
              })
          }
          .padding({
            top: ChatBubbleActionArea.ACTION_GROUP_PADDING_V,
            right: ChatBubbleActionArea.ACTION_GROUP_PADDING_H,
            bottom: ChatBubbleActionArea.ACTION_GROUP_PADDING_V,
            left: ChatBubbleActionArea.ACTION_GROUP_PADDING_H
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
      .padding({ left: 4, right: 4 })
    }, (token: string) => token)
  }

  private buildActionToken(): string {
    return `${this.message.showActions}-${this.message.feedback}-${this.message.activeAnswerIndex}` +
      `-${this.message.answerCount}-${this.isSpeaking}`;
  }

  @Builder
  private ActionButtonBuilder(action: string, onClick: () => void) {
    Button() {
      Image(this.getActionIconResource(action))
        .width(ChatBubbleActionArea.ACTION_ICON_SIZE)
        .height(ChatBubbleActionArea.ACTION_ICON_SIZE)
        .fillColor(this.getActionIconColor(action))
    }
      .width(ChatBubbleActionArea.ACTION_BUTTON_SIZE)
      .height(ChatBubbleActionArea.ACTION_BUTTON_SIZE)
      .backgroundColor(this.getActionButtonBackground(action))
      .borderRadius(ChatBubbleActionArea.ACTION_BUTTON_RADIUS)
      .padding(0)
      .onClick(onClick)
  }

  private getActionButtonBackground(action: string): string {
    if (action === 'like' && this.message.feedback === MessageFeedback.Like) {
      return '#DBEAFE';
    }
    if (action === 'dislike' && this.message.feedback === MessageFeedback.Dislike) {
      return '#FEE2E2';
    }
    if (action === 'sound' && this.isSpeaking) {
      return '#CCFBF1';
    }
    return '#F8FAFC';
  }

  private getActionIconColor(action: string): string {
    if (action === 'like' && this.message.feedback === MessageFeedback.Like) {
      return '#2563EB';
    }
    if (action === 'dislike' && this.message.feedback === MessageFeedback.Dislike) {
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

@Component
export struct ChatBubble {
  @ObjectLink message: ChatMessage;
  @Prop isSpeaking: boolean = false;

  build() {
    ForEach([this.buildShellToken()], (_token: string) => {
      Column({ space: 8 }) {
        if (this.shouldShowStatusOnly()) {
          this.StreamingStatusBuilder();
        } else {
          Column({ space: 14 }) {
            ChatBubbleContentArea({
              message: this.message
            })

            if (this.message.showActions) {
              ChatBubbleActionArea({
                message: this.message,
                isSpeaking: this.isSpeaking
              })
            }
          }
          .padding({
            top: this.message.role === MessageRole.Assistant ? 18 : 10,
            right: this.message.role === MessageRole.Assistant ? 22 : 10,
            bottom: this.message.role === MessageRole.Assistant ? 18 : 10,
            left: this.message.role === MessageRole.Assistant ? 22 : 10
          })
          .constraintSize({
            maxWidth: this.message.role === MessageRole.Assistant ? '88%' : '78%'
          })
          .backgroundColor(this.getBubbleBackgroundColor())
          .borderRadius(10)
          .border(this.message.role === MessageRole.Assistant ? {
            width: 1,
            color: '#EEF2F7'
          } : {
            width: 0,
            color: '#00000000'
          })
          .shadow({
            radius: this.message.role === MessageRole.Assistant ? 18 : 14,
            color: this.message.role === MessageRole.Assistant ? '#120F172A' : '#180F3D91',
            offsetX: 0,
            offsetY: 6
          })
          .clip(true)

          if (this.shouldShowStatusHint()) {
            this.StreamingStatusBuilder();
          }
        }
      }
      .width('100%')
      .alignItems(this.message.role === MessageRole.Assistant ? HorizontalAlign.Start : HorizontalAlign.End)
    }, (token: string) => token)
  }

  private buildShellToken(): string {
    return `${this.message.role}:${this.message.showActions ? '1' : '0'}:${this.message.statusLabel}` +
      `:${this.message.streamPhase}:${this.message.isStreaming ? '1' : '0'}:${this.message.visibleContent.length}`;
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

  private shouldShowStatusOnly(): boolean {
    return this.message.role === MessageRole.Assistant &&
      !this.message.showActions &&
      !this.hasRenderableContent() &&
      this.getStreamingHintText().trim().length > 0;
  }

  private shouldShowStatusHint(): boolean {
    return this.message.role === MessageRole.Assistant &&
      !this.message.showActions &&
      this.hasRenderableContent() &&
      this.getStreamingHintText().trim().length > 0;
  }

  private hasRenderableContent(): boolean {
    return this.message.visibleContent.trim().length > 0;
  }

  private getStreamingHintText(): string {
    if (this.message.statusLabel.trim().length > 0 &&
      this.message.statusLabel !== '已结束' &&
      this.message.statusLabel !== '已停止' &&
      this.message.statusLabel !== '出错') {
      return this.normalizeStreamingLabel(this.message.statusLabel);
    }
    if (this.message.streamPhase === ChatMessagePhase.Answering) {
      return 'AI 正在回答';
    }
    return 'AI 正在思考';
  }

  private getBubbleBackgroundColor(): string {
    if (this.message.role === MessageRole.Assistant) {
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
    if (this.message.streamPhase === ChatMessagePhase.Answering) {
      return '#E8F1FF';
    }
    if (this.message.streamPhase === ChatMessagePhase.Sending) {
      return '#FEF3E6';
    }
    return '#EAFBF3';
  }

  private getStreamingBorderColor(): string {
    if (this.message.streamPhase === ChatMessagePhase.Answering) {
      return '#CFE0FF';
    }
    if (this.message.streamPhase === ChatMessagePhase.Sending) {
      return '#F8D7AA';
    }
    return '#CBEFD9';
  }

  private getStreamingTextColor(): string {
    if (this.message.streamPhase === ChatMessagePhase.Answering) {
      return '#2F6FEB';
    }
    if (this.message.streamPhase === ChatMessagePhase.Sending) {
      return '#C57A10';
    }
    return '#1E9B63';
  }

  private getStreamingAccentColor(): string {
    if (this.message.streamPhase === ChatMessagePhase.Answering) {
      return '#5EA2F8';
    }
    if (this.message.streamPhase === ChatMessagePhase.Sending) {
      return '#F2A93B';
    }
    return '#34C27E';
  }

}
