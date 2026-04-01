import { ChatBubble } from '../components/ChatBubble';
import preferences from '@ohos.data.preferences';
import { ChatMessage } from '../models/ChatModels';
import { HiAgentConfig, HiAgentHistoryMessage, HiAgentStreamEvent } from '../models/HiAgentModels';
import { HiAgentService, HiAgentStreamSession } from '../services/HiAgentService';

@Entry
@Component
struct Index {
  private static readonly CONFIG_STORE_NAME: string = 'hiagent_chat_config';
  private static readonly KEY_API_URL: string = 'api_url';
  private static readonly KEY_API_KEY: string = 'api_key';
  private static readonly KEY_USER_ID: string = 'user_id';
  private static readonly KEY_CONFIG_EXPANDED: string = 'config_expanded';

  @State private messages: Array<ChatMessage> = [];
  @State private draft: string = '请生成一段包含任务列表、代码块和表格的 Markdown 回复。';
  @State private apiUrl: string = '';
  @State private apiKey: string = '';
  @State private userId: string = 'demo-user';
  @State private conversationId: string = '';
  @State private isConfigExpanded: boolean = true;
  @State private statusText: string = '请先填写 HiAgent 的 Api URL、ApiKey 和 UserID。';
  @State private isSending: boolean = false;

  private messageScroller: Scroller = new Scroller();
  private configStore: preferences.Preferences | null = null;
  private configSaveTimer: number = -1;
  private revealTimer: number = -1;
  private revealChunkSize: number = 5;
  private revealIntervalMs: number = 24;
  private activeRevealMessageId: string = '';
  private activeAssistantMessageId: string = '';
  private activeStreamSession: HiAgentStreamSession | null = null;

  aboutToAppear(): void {
    this.resetConversation();
    this.restoreSavedConfig();
  }

  aboutToDisappear(): void {
    this.flushConfigIfNeeded();
    this.stopRevealTimer();
    this.closeActiveSession();
  }

  build() {
    Column({ space: 0 }) {
      this.HeaderBuilder();
      this.ConfigBuilder();

      List({ space: 16, scroller: this.messageScroller }) {
        ForEach(this.messages, (message: ChatMessage) => {
          ListItem() {
            ChatBubble({
              role: message.role,
              content: message.visibleContent,
              isStreaming: message.isStreaming
            })
          }
        }, (message: ChatMessage) => `${message.id}-${message.visibleContent.length}-${message.isStreaming}`)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 8, right: 16, bottom: 12, left: 16 })
      .backgroundColor('#F4F7FB')
      .scrollBar(BarState.Off)

      this.ComposerBuilder();
    }
    .height('100%')
    .width('100%')
    .backgroundColor('#E9EEF5')
  }

  @Builder
  private HeaderBuilder() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 6 }) {
          Text('HiAgent Markdown Chat')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text('HarmonyOS SSE chat demo with real HiAgent streaming markdown rendering.')
            .fontSize(13)
            .fontColor('#526174')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('New chat')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F3D91')
          .backgroundColor('#DBEAFE')
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.resetConversation();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 18, right: 16, bottom: 12, left: 16 })
    .backgroundColor('#FFF7ED')
  }

  @Builder
  private ConfigBuilder() {
    Column({ space: this.isConfigExpanded ? 10 : 0 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(this.isConfigExpanded ? 'HiAgent Config' : 'Config Hidden')
            .fontSize(this.isConfigExpanded ? 15 : 14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F172A')

          Text(this.isConfigExpanded ? '接口配置会自动保存，下次启动继续可用。' : this.statusText)
            .fontSize(11)
            .fontColor('#64748B')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.conversationId.length > 0) {
          Text(this.shortenId(this.conversationId))
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getStatusTextColor())
            .padding({ top: 6, right: 10, bottom: 6, left: 10 })
            .backgroundColor(this.getStatusBackgroundColor())
            .borderRadius(14)
        }

        Button('Sync')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#166534')
          .backgroundColor('#DCFCE7')
          .borderRadius(16)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.syncHistory();
          })

        Button(this.isConfigExpanded ? 'Hide' : 'Show')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F3D91')
          .backgroundColor('#DBEAFE')
          .borderRadius(16)
          .padding({ left: 12, right: 12 })
          .onClick(() => {
            this.toggleConfigPanel();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.isConfigExpanded) {
        TextInput({ text: this.apiUrl, placeholder: 'Api URL，例如 http://host:32300' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.apiUrl = value;
            this.scheduleConfigSave();
          })

        TextInput({ text: this.apiKey, placeholder: 'ApiKey，body.AppKey 默认复用同一值' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.apiKey = value;
            this.scheduleConfigSave();
          })

        TextInput({ text: this.userId, placeholder: 'UserID' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => {
            this.userId = value;
            this.scheduleConfigSave();
          })

        Row({ space: 8 }) {
          Text(this.statusText)
            .fontSize(12)
            .fontColor(this.getStatusTextColor())
            .layoutWeight(1)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.conversationId.length === 0) {
            Text('No conversation')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getStatusTextColor())
              .padding({ top: 6, right: 10, bottom: 6, left: 10 })
              .backgroundColor(this.getStatusBackgroundColor())
              .borderRadius(14)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 10, right: 16, bottom: this.isConfigExpanded ? 12 : 8, left: 16 })
    .backgroundColor('#F8FAFC')
  }

  @Builder
  private ComposerBuilder() {
    Column({ space: 12 }) {
      TextInput({ text: this.draft, placeholder: '输入要发给 HiAgent 的问题...' })
        .height(52)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.draft = value;
        })

      Row({ space: 12 }) {
        Button('Insert sample prompt')
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F172A')
          .backgroundColor('#FFFFFF')
          .borderRadius(18)
          .onClick(() => {
            this.draft = '请生成一段 Markdown 回复，包含标题、任务列表、代码块、表格和总结。';
          })

        Button(this.isSending ? 'Stop' : 'Send')
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.isSending ? '#DC2626' : '#2563EB')
          .borderRadius(18)
          .onClick(() => {
            if (this.isSending) {
              this.stopActiveResponse();
            } else {
              this.sendPrompt();
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 14, right: 16, bottom: 20, left: 16 })
    .backgroundColor('#FFF7ED')
  }

  private resetConversation(): void {
    this.stopRevealTimer();
    this.closeActiveSession();
    this.conversationId = '';
    this.isSending = false;
    this.statusText = '请先填写 HiAgent 的 Api URL、ApiKey 和 UserID。';
    this.messages = this.buildGuideMessages();
    this.scrollToBottom();
  }

  private restoreSavedConfig(): void {
    try {
      const context: Context = getContext(this);
      const store: preferences.Preferences = preferences.getPreferencesSync(context, {
        name: Index.CONFIG_STORE_NAME
      });
      this.configStore = store;
      this.apiUrl = this.readStoredString(Index.KEY_API_URL, '');
      this.apiKey = this.readStoredString(Index.KEY_API_KEY, '');
      this.userId = this.readStoredString(Index.KEY_USER_ID, 'demo-user');
      this.isConfigExpanded = this.readStoredBoolean(Index.KEY_CONFIG_EXPANDED, true);
      if (this.buildConfig().isReady()) {
        this.statusText = '已恢复上次配置，可以直接发送。';
      }
    } catch (_error) {
      this.statusText = '配置读取失败，请重新填写接口参数。';
    }
  }

  private toggleConfigPanel(): void {
    this.isConfigExpanded = !this.isConfigExpanded;
    this.scheduleConfigSave();
  }

  private scheduleConfigSave(): void {
    if (this.configSaveTimer >= 0) {
      clearTimeout(this.configSaveTimer);
      this.configSaveTimer = -1;
    }
    this.configSaveTimer = setTimeout(() => {
      this.persistConfig();
    }, 250);
  }

  private flushConfigIfNeeded(): void {
    if (this.configSaveTimer >= 0) {
      clearTimeout(this.configSaveTimer);
      this.configSaveTimer = -1;
    }
    this.persistConfig();
  }

  private persistConfig(): void {
    try {
      if (this.configStore === null) {
        const context: Context = getContext(this);
        this.configStore = preferences.getPreferencesSync(context, {
          name: Index.CONFIG_STORE_NAME
        });
      }
      if (this.configStore === null) {
        return;
      }

      this.configStore.putSync(Index.KEY_API_URL, this.apiUrl);
      this.configStore.putSync(Index.KEY_API_KEY, this.apiKey);
      this.configStore.putSync(Index.KEY_USER_ID, this.userId);
      this.configStore.putSync(Index.KEY_CONFIG_EXPANDED, this.isConfigExpanded);
      this.configStore.flushSync();
    } catch (_error) {
      // Ignore local persistence errors so chat features remain available.
    }
  }

  private readStoredString(key: string, defaultValue: string): string {
    if (this.configStore === null) {
      return defaultValue;
    }
    const value: preferences.ValueType = this.configStore.getSync(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  private readStoredBoolean(key: string, defaultValue: boolean): boolean {
    if (this.configStore === null) {
      return defaultValue;
    }
    const value: preferences.ValueType = this.configStore.getSync(key, defaultValue);
    return typeof value === 'boolean' ? value : defaultValue;
  }

  private async sendPrompt(): Promise<void> {
    const prompt: string = this.draft.trim();
    if (prompt.length === 0) {
      this.statusText = '先输入一个问题再发送。';
      return;
    }

    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.statusText = '请先填写 Api URL、ApiKey 和 UserID。';
      return;
    }

    const nextMessages: Array<ChatMessage> = this.messages.slice();
    nextMessages.push(ChatMessage.user(this.createMessageId('user'), prompt));
    const assistantMessageId: string = this.createMessageId('assistant');
    const assistantMessage: ChatMessage = ChatMessage.assistant(assistantMessageId, '', '', true);
    assistantMessage.streamCompleted = false;
    nextMessages.push(assistantMessage);
    this.messages = nextMessages;
    this.activeAssistantMessageId = assistantMessageId;
    this.isSending = true;
    this.draft = '';
    this.statusText = this.conversationId.length > 0 ? `会话 ${this.shortenId(this.conversationId)} 已连接，正在发送...` : '正在创建会话...';
    this.scrollToBottom();
    this.startRevealTimer(assistantMessageId);

    try {
      const appConversationId: string = await this.ensureConversation(config);
      this.statusText = `会话 ${this.shortenId(appConversationId)} 已连接，正在等待模型响应...`;
      this.activeStreamSession = HiAgentService.startChatStream(
        config,
        appConversationId,
        prompt,
        (event: HiAgentStreamEvent) => {
          this.handleStreamEvent(assistantMessageId, event);
        },
        () => {
          this.completeAssistantMessage(assistantMessageId, '响应完成。');
        },
        (errorMessage: string) => {
          this.failAssistantMessage(assistantMessageId, errorMessage);
        }
      );
    } catch (error) {
      this.failAssistantMessage(assistantMessageId, this.stringifyError(error));
    }
  }

  private async syncHistory(): Promise<void> {
    if (this.isSending) {
      this.statusText = '当前仍在流式响应中，请先停止或等待完成。';
      return;
    }

    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.statusText = '同步历史前请先填写 Api URL、ApiKey 和 UserID。';
      return;
    }
    if (this.conversationId.trim().length === 0) {
      this.statusText = '当前还没有会话，先发送一条消息创建会话。';
      return;
    }

    this.statusText = '正在同步会话历史...';
    try {
      const historyMessages: Array<HiAgentHistoryMessage> = await HiAgentService.getConversationMessages(
        config,
        this.conversationId,
        100
      );
      this.messages = this.buildHistoryMessages(historyMessages);
      this.statusText = historyMessages.length > 0 ? `已同步 ${historyMessages.length} 条历史记录。` : '当前会话还没有历史消息。';
      this.scrollToBottom();
    } catch (error) {
      this.statusText = `同步历史失败：${this.stringifyError(error)}`;
    }
  }

  private async stopActiveResponse(): Promise<void> {
    const session: HiAgentStreamSession | null = this.activeStreamSession;
    const localAssistantMessageId: string = this.activeAssistantMessageId;

    this.activeStreamSession = null;
    this.activeAssistantMessageId = '';
    this.isSending = false;

    if (session === null) {
      return;
    }

    try {
      const config: HiAgentConfig = this.buildConfig();
      if (config.isReady()) {
        await HiAgentService.stopMessage(config, session.messageId, session.taskId);
      }
      this.statusText = '已停止当前回复。';
    } catch (error) {
      this.statusText = `停止请求失败：${this.stringifyError(error)}`;
    } finally {
      session.close();
      this.markAssistantStopped(localAssistantMessageId);
    }
  }

  private startRevealTimer(messageId: string): void {
    if (this.activeRevealMessageId === messageId && this.revealTimer >= 0) {
      return;
    }
    this.stopRevealTimer();
    this.activeRevealMessageId = messageId;
    this.revealTimer = setInterval(() => {
      const messageIndex: number = this.findMessageIndex(this.activeRevealMessageId);
      if (messageIndex < 0) {
        this.stopRevealTimer();
        return;
      }

      const message: ChatMessage = this.messages[messageIndex];
      if (message.visibleContent.length < message.rawContent.length) {
        const nextMessage: ChatMessage = message.copy();
        const nextLength: number = Math.min(message.rawContent.length, message.visibleContent.length + this.revealChunkSize);
        nextMessage.visibleContent = message.rawContent.substring(0, nextLength);
        nextMessage.isStreaming = true;

        const nextMessages: Array<ChatMessage> = this.messages.slice();
        nextMessages[messageIndex] = nextMessage;
        this.messages = nextMessages;
        this.scrollToBottom();
        return;
      }

      if (message.streamCompleted) {
        if (message.isStreaming) {
          const nextMessage: ChatMessage = message.copy();
          nextMessage.isStreaming = false;
          const nextMessages: Array<ChatMessage> = this.messages.slice();
          nextMessages[messageIndex] = nextMessage;
          this.messages = nextMessages;
        }
        this.stopRevealTimer();
      }
    }, this.revealIntervalMs);
  }

  private stopRevealTimer(): void {
    if (this.revealTimer >= 0) {
      clearInterval(this.revealTimer);
      this.revealTimer = -1;
    }
    this.activeRevealMessageId = '';
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.messageScroller.scrollEdge(Edge.Bottom);
    }, 30);
  }

  private findMessageIndex(messageId: string): number {
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id === messageId) {
        return index;
      }
    }
    return -1;
  }

  private buildGuideMessages(): Array<ChatMessage> {
    const guideMarkdown: string = [
      '# HiAgent 已接入',
      '',
      '请先填写上方接口配置，然后点击发送。',
      '',
      '当前页面已经串起：',
      '- `create_conversation`',
      '- `chat_query`（`streaming` SSE）',
      '- `stop_message`',
      '- `get_conversation_messages`',
      '',
      '推荐测试词：`请生成一段 Markdown 回复，包含任务列表、代码块、表格和总结。`',
      '',
      '> 文档约定里 body 中的 `AppKey` 默认和 header 里的 `Apikey` 使用同一份值。'
    ].join('\n');

    const guideMessage: ChatMessage = ChatMessage.assistant(
      this.createMessageId('guide'),
      guideMarkdown,
      guideMarkdown,
      false
    );
    guideMessage.streamCompleted = true;
    return [guideMessage];
  }

  private buildHistoryMessages(historyMessages: Array<HiAgentHistoryMessage>): Array<ChatMessage> {
    if (historyMessages.length === 0) {
      return this.buildGuideMessages();
    }

    const nextMessages: Array<ChatMessage> = [];
    for (let index: number = 0; index < historyMessages.length; index++) {
      const historyMessage: HiAgentHistoryMessage = historyMessages[index];
      if (historyMessage.query.trim().length > 0) {
        const userMessage: ChatMessage = ChatMessage.user(this.createMessageId(`history-user-${index}`), historyMessage.query);
        userMessage.conversationId = this.conversationId;
        userMessage.createdAt = historyMessage.createdTime * 1000;
        nextMessages.push(userMessage);
      }

      if (historyMessage.answer.trim().length > 0) {
        const assistantMessage: ChatMessage = ChatMessage.assistant(
          this.createMessageId(`history-assistant-${index}`),
          historyMessage.answer,
          historyMessage.answer,
          false
        );
        assistantMessage.streamCompleted = true;
        assistantMessage.conversationId = this.conversationId;
        assistantMessage.serviceMessageId = historyMessage.messageId;
        assistantMessage.taskId = historyMessage.taskId;
        assistantMessage.createdAt = historyMessage.createdTime * 1000;
        nextMessages.push(assistantMessage);
      }
    }
    return nextMessages;
  }

  private async ensureConversation(config: HiAgentConfig): Promise<string> {
    if (this.conversationId.trim().length > 0) {
      return this.conversationId.trim();
    }

    const conversation = await HiAgentService.createConversation(config);
    this.conversationId = conversation.appConversationId;
    return conversation.appConversationId;
  }

  private handleStreamEvent(localMessageId: string, event: HiAgentStreamEvent): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = this.messages[messageIndex].copy();
    if (event.conversationId.length > 0) {
      nextMessage.conversationId = event.conversationId;
      this.conversationId = event.conversationId;
    }
    if (event.messageId.length > 0) {
      nextMessage.serviceMessageId = event.messageId;
    }
    if (event.taskId.length > 0) {
      nextMessage.taskId = event.taskId;
    }
    if (event.answer.length > 0) {
      nextMessage.rawContent = this.mergeStreamAnswer(nextMessage.rawContent, event.answer, event.event === 'message_replace');
    }

    nextMessage.isStreaming = true;
    nextMessage.streamCompleted = false;

    const nextMessages: Array<ChatMessage> = this.messages.slice();
    nextMessages[messageIndex] = nextMessage;
    this.messages = nextMessages;
    this.statusText = '正在流式渲染 Markdown 内容...';
    this.scrollToBottom();
  }

  private completeAssistantMessage(localMessageId: string, statusText: string): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex >= 0) {
      const nextMessage: ChatMessage = this.messages[messageIndex].copy();
      nextMessage.streamCompleted = true;
      if (nextMessage.visibleContent.length >= nextMessage.rawContent.length) {
        nextMessage.isStreaming = false;
      }
      const nextMessages: Array<ChatMessage> = this.messages.slice();
      nextMessages[messageIndex] = nextMessage;
      this.messages = nextMessages;
    }
    this.finishSending(statusText);
  }

  private failAssistantMessage(localMessageId: string, errorMessage: string): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex >= 0) {
      const nextMessage: ChatMessage = this.messages[messageIndex].copy();
      nextMessage.rawContent = nextMessage.rawContent.length > 0
        ? `${nextMessage.rawContent}\n\n> 接口错误：${errorMessage}`
        : `> 接口错误\n\n${errorMessage}`;
      nextMessage.streamCompleted = true;
      nextMessage.isStreaming = true;

      const nextMessages: Array<ChatMessage> = this.messages.slice();
      nextMessages[messageIndex] = nextMessage;
      this.messages = nextMessages;
      this.startRevealTimer(localMessageId);
    }
    this.finishSending(`请求失败：${errorMessage}`);
  }

  private markAssistantStopped(localMessageId: string): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = this.messages[messageIndex].copy();
    if (nextMessage.rawContent.trim().length === 0) {
      nextMessage.rawContent = '已停止本次生成。';
    }
    nextMessage.streamCompleted = true;
    nextMessage.isStreaming = true;

    const nextMessages: Array<ChatMessage> = this.messages.slice();
    nextMessages[messageIndex] = nextMessage;
    this.messages = nextMessages;
    this.startRevealTimer(localMessageId);
  }

  private finishSending(statusText: string): void {
    this.activeStreamSession = null;
    this.activeAssistantMessageId = '';
    this.isSending = false;
    this.statusText = statusText;
  }

  private closeActiveSession(): void {
    if (this.activeStreamSession !== null) {
      this.activeStreamSession.close();
      this.activeStreamSession = null;
    }
    this.activeAssistantMessageId = '';
  }

  private buildConfig(): HiAgentConfig {
    return new HiAgentConfig(this.apiUrl, this.apiKey, this.userId);
  }

  private mergeStreamAnswer(currentContent: string, incomingContent: string, replaceAll: boolean = false): string {
    if (incomingContent.length === 0) {
      return currentContent;
    }
    if (replaceAll || currentContent.length === 0) {
      return incomingContent;
    }
    if (incomingContent === currentContent) {
      return currentContent;
    }
    if (incomingContent.startsWith(currentContent)) {
      return incomingContent;
    }
    if (currentContent.indexOf(incomingContent) >= 0) {
      return currentContent;
    }
    return `${currentContent}${incomingContent}`;
  }

  private shortenId(value: string): string {
    if (value.length <= 18) {
      return value;
    }
    return `${value.substring(0, 8)}...${value.substring(value.length - 6)}`;
  }

  private stringifyError(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    if (typeof error === 'object' && error !== null) {
      const message: Object = (error as ESObject)['message'];
      if (typeof message === 'string' && message.length > 0) {
        return message;
      }
    }
    return `${error}`;
  }

  private getStatusBackgroundColor(): string {
    if (this.isSending) {
      return '#DBEAFE';
    }
    if (this.conversationId.length > 0) {
      return '#DCFCE7';
    }
    return '#FEF3C7';
  }

  private getStatusTextColor(): string {
    if (this.isSending) {
      return '#1D4ED8';
    }
    if (this.conversationId.length > 0) {
      return '#166534';
    }
    return '#92400E';
  }

  private createMessageId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  }
}
