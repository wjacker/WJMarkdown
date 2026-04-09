import { ChatBubble } from './components/ChatBubble';
import { ChatBubbleActionDispatcher, ChatBubbleActionType } from './components/ChatBubbleActionDispatcher';
import pasteboard from '@ohos.pasteboard';
import promptAction from '@ohos.promptAction';
import preferences from '@ohos.data.preferences';
import textToSpeech from '@hms.ai.textToSpeech';
import { ChatAnswerVariant, ChatMessage, ChatMessagePhase, MessageFeedback, MessageRole } from './models/ChatModels';
import { AgentConversationHelper, AgentConversationItem, AgentConversationSection } from './models/ConversationModels';
import { HiAgentConfig, HiAgentConversation, HiAgentEventHelper, HiAgentHistoryMessage, HiAgentMessageAnswerInfo, HiAgentStreamEvent } from './models/HiAgentModels';
import { AgentConfigStore, AgentStoredConfig } from './services/AgentConfigStore';
import { HiAgentService, HiAgentStreamSession } from './services/HiAgentService';
import { AgentTextUtils } from './utils/AgentTextUtils';
import { AgentVariantHelper } from './utils/AgentVariantHelper';

@Entry
@Component
struct Index {
  @State private messages: Array<ChatMessage> = [];
  @State private draft: string = '请生成一段包含任务列表、代码块和表格的 Markdown 回复。';
  @State private apiUrl: string = '';
  @State private apiKey: string = '';
  @State private userId: string = 'demo-user';
  @State private conversationId: string = '';
  @State private isConfigExpanded: boolean = true;
  @State private statusText: string = '请先填写 HiAgent 的 Api URL、ApiKey 和 UserID。';
  @State private isSending: boolean = false;
  @State private speakingMessageId: string = '';
  @State private shouldAutoScrollToBottom: boolean = true;
  @State private conversationItems: Array<AgentConversationItem> = [];
  @State private isConversationDrawerVisible: boolean = false;
  @State private activeConversationMenuId: string = '';
  @State private activeConversationMenuTop: number = 88;
  @State private renameConversationId: string = '';
  @State private renameDraft: string = '';
  @State private isRenameDialogVisible: boolean = false;

  private messageScroller: Scroller = new Scroller();
  private configStore: preferences.Preferences | null = null;
  private configSaveTimer: number = -1;
  private revealTimer: number = -1;
  private revealChunkSize: number = 5;
  private revealIntervalMs: number = 24;
  private activeRevealMessageId: string = '';
  private activeAssistantMessageId: string = '';
  private activeStreamSession: HiAgentStreamSession | null = null;
  private serviceConversationId: string = '';
  private ttsEngine: textToSpeech.TextToSpeechEngine | null = null;
  private answerVariantsByMessageId: Map<string, Array<ChatAnswerVariant>> = new Map();
  private pendingConversationTitleByMessageId: Map<string, string> = new Map();

  aboutToAppear(): void {
    ChatBubbleActionDispatcher.register((messageId: string, action: ChatBubbleActionType) => {
      this.handleChatBubbleAction(messageId, action);
    });
    this.resetConversation();
    this.restoreSavedConfig();
  }

  aboutToDisappear(): void {
    ChatBubbleActionDispatcher.clear();
    this.flushConfigIfNeeded();
    this.stopRevealTimer();
    this.closeActiveSession();
    this.shutdownSpeechEngine();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: 0 }) {
        this.HeaderBuilder();
        this.ConfigBuilder();

        List({ space: 22, scroller: this.messageScroller }) {
          ForEach(this.messages, (message: ChatMessage) => {
            ListItem() {
              ChatBubble({
                message: message,
                isSpeaking: this.speakingMessageId === message.id,
              })
              .padding({ top: 2, bottom: 6 })
            }
          }, (message: ChatMessage) => message.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ top: 14, right: 16, bottom: 20, left: 16 })
        .backgroundColor('#F4F7FB')
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.shouldAutoScrollToBottom = true;
        })
        .onDidScroll((_scrollOffset: number, scrollState: ScrollState) => {
          if (scrollState === ScrollState.Scroll) {
            this.shouldAutoScrollToBottom = this.safeIsAtEnd();
          }
        })
        .onScrollStop(() => {
          this.shouldAutoScrollToBottom = this.safeIsAtEnd();
        })

        this.ComposerBuilder();
      }
      .height('100%')
      .width('100%')
      .backgroundColor('#E9EEF5')

      if (this.isConversationDrawerVisible) {
        this.ConversationDrawerOverlayBuilder();
      }

      if (this.isRenameDialogVisible) {
        this.RenameConversationDialogBuilder();
      }
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  private HeaderBuilder() {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Button() {
          Image($r('app.media.icon_ai_more'))
            .width(18)
            .height(18)
            .fillColor('#0F3D91')
        }
        .width(38)
        .height(38)
        .backgroundColor('#FFFFFF')
        .borderRadius(19)
        .onClick(() => {
          this.isConversationDrawerVisible = true;
          this.activeConversationMenuId = '';
        })

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
            void this.startNewConversation();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 18, right: 16, bottom: 12, left: 16 })
    .backgroundColor('#FFF7ED')
  }

  @Builder
  private ConversationDrawerOverlayBuilder() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#400F172A')
      .onClick(() => {
        this.isConversationDrawerVisible = false;
        this.activeConversationMenuId = '';
      })

      Row() {
        Column({ space: 14 }) {
          Row() {
            Text('对话历史')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')

            Blank()

            Button('新建')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#0F3D91')
              .backgroundColor('#DBEAFE')
              .borderRadius(16)
              .padding({ left: 12, right: 12 })
              .onClick(() => {
                this.isConversationDrawerVisible = false;
                this.activeConversationMenuId = '';
                void this.startNewConversation();
              })
          }
          .width('100%')

          if (this.conversationItems.length === 0) {
            Column({ space: 8 }) {
              Text('还没有会话')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#334155')

              Text('发送第一条消息后，这里会自动保存会话记录。')
                .fontSize(12)
                .fontColor('#64748B')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 10, right: 8, bottom: 10, left: 8 })
          } else {
            Stack({ alignContent: Alignment.TopStart }) {
              List({ space: 12 }) {
                ForEach(this.buildConversationSections(), (section: AgentConversationSection) => {
                  ListItem() {
                    Column({ space: 10 }) {
                      Text(section.title)
                        .fontSize(13)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#6B7280')
                        .width('100%')
                        .textAlign(TextAlign.Start)

                      Column({ space: 12 }) {
                        ForEach(section.items, (item: AgentConversationItem) => {
                          this.ConversationItemBuilder(item)
                        }, (item: AgentConversationItem) => this.buildConversationItemKey(item))
                      }
                      .width('100%')
                    }
                    .width('100%')
                  }
                }, (section: AgentConversationSection) => this.buildConversationSectionKey(section))
              }
              .width('100%')
              .layoutWeight(1)
              .scrollBar(BarState.Off)

              if (this.activeConversationMenuId.length > 0) {
                this.ConversationFloatingMenuBuilder()
              }
            }
            .width('100%')
            .layoutWeight(1)
          }
        }
        .width('78%')
        .height('100%')
        .padding({ top: 52, right: 14, bottom: 20, left: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius({ topRight: 26, bottomRight: 26 })
        .shadow({
          radius: 28,
          color: '#1F0F172A',
          offsetX: 6,
          offsetY: 0
        })

        Blank()
          .layoutWeight(1)
          .onClick(() => {
            this.isConversationDrawerVisible = false;
            this.activeConversationMenuId = '';
          })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private ConversationItemBuilder(item: AgentConversationItem) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Column() {
          Text(AgentConversationHelper.buildDisplayTitle(item))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F172A')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button() {
          Image($r('app.media.icon_ai_more'))
            .width(16)
            .height(16)
            .fillColor('#64748B')
        }
        .width(28)
        .height(28)
        .backgroundColor(Color.Transparent)
        .borderRadius(14)
        .onClick(() => {
          if (this.activeConversationMenuId === item.appConversationId) {
            this.activeConversationMenuId = '';
            return;
          }
          this.activeConversationMenuTop = this.resolveConversationMenuTopFor(item.appConversationId);
          this.activeConversationMenuId = item.appConversationId;
        })
      }
      .width('100%')
      .padding({ top: 12, right: 12, bottom: 12, left: 12 })
      .backgroundColor(this.conversationId === item.appConversationId ? '#EFF6FF' : '#F8FAFC')
      .border({
        width: 1,
        color: this.conversationId === item.appConversationId ? '#93C5FD' : '#E2E8F0'
      })
      .borderRadius(16)
      .onClick(() => {
        this.selectConversation(item.appConversationId);
      })
    }
    .width('100%')
  }

  @Builder
  private ConversationFloatingMenuBuilder() {
    Row() {
      Blank()

      Column({ space: 0 }) {
        this.ConversationMenuItemBuilder(
          this.isActiveConversationPinned() ? '取消置顶' : '置顶',
          $r('app.media.icon_ai_pinned'),
          '#0F172A',
          'pin',
          this.activeConversationMenuId
        );
        this.ConversationMenuItemBuilder('重命名', $r('app.media.icon_ai_edit'), '#0F172A', 'rename', this.activeConversationMenuId);
        this.ConversationMenuItemBuilder('删除', $r('app.media.icon_ai_delete'), '#DC2626', 'delete', this.activeConversationMenuId);
      }
      .width(196)
      .backgroundColor('#FFFFFF')
      .borderRadius(22)
      .shadow({
        radius: 24,
        color: '#220F172A',
        offsetX: 0,
        offsetY: 10
      })
      .padding({ top: 6, bottom: 6 })
    }
    .width('100%')
    .margin({ top: this.activeConversationMenuTop, right: 20 })
  }

  @Builder
  private ConversationMenuItemBuilder(label: string, icon: Resource, color: string, actionType: string,
    appConversationId: string) {
    Row({ space: 10 }) {
      Image(icon)
        .width(15)
        .height(15)
        .fillColor(color)

      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)

      Blank()
    }
    .width('100%')
    .padding({ top: 12, right: 14, bottom: 12, left: 14 })
    .onClick(() => {
      if (actionType === 'pin') {
        void this.toggleConversationPinned(appConversationId);
        return;
      }
      if (actionType === 'rename') {
        this.openRenameConversation(appConversationId);
        return;
      }
      void this.deleteConversationItem(appConversationId);
    })
  }

  @Builder
  private RenameConversationDialogBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#500F172A')
      .onClick(() => {
        this.isRenameDialogVisible = false;
      })

      Column({ space: 14 }) {
        Text('重命名会话')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111827')

        TextInput({ text: this.renameDraft, placeholder: '请输入新的会话名称' })
          .height(46)
          .fontSize(14)
          .backgroundColor('#F8FAFC')
          .borderRadius(14)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.renameDraft = this.sanitizeConversationTitle(value, false);
          })

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#475569')
            .backgroundColor('#F1F5F9')
            .borderRadius(14)
            .onClick(() => {
              this.isRenameDialogVisible = false;
            })

          Button('确定')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#2563EB')
            .borderRadius(14)
            .onClick(() => {
              void this.confirmRenameConversation();
            })
        }
        .width('100%')
      }
      .width('78%')
      .padding(18)
      .backgroundColor('#FFFFFF')
      .borderRadius(24)
    }
    .width('100%')
    .height('100%')
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

        Button(this.isSending ? '停止回复' : 'Send')
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

  private resolveAnswerVersionCount(message: ChatMessage): number {
    const localVariants: Array<ChatAnswerVariant> | undefined = this.answerVariantsByMessageId.get(message.id);
    if (localVariants !== undefined && localVariants.length > 0) {
      return localVariants.length;
    }
    return message.answerVersionCount;
  }

  private handleChatBubbleAction(messageId: string, action: ChatBubbleActionType): void {
    if (action === ChatBubbleActionType.Copy) {
      void this.copyMessageText(messageId);
      return;
    }
    if (action === ChatBubbleActionType.Regenerate) {
      void this.queryAgainAssistantMessage(messageId);
      return;
    }
    if (action === ChatBubbleActionType.Delete) {
      void this.deleteAssistantMessage(messageId);
      return;
    }
    if (action === ChatBubbleActionType.Like) {
      void this.toggleFeedback(messageId, MessageFeedback.Like);
      return;
    }
    if (action === ChatBubbleActionType.Dislike) {
      void this.toggleFeedback(messageId, MessageFeedback.Dislike);
      return;
    }
    if (action === ChatBubbleActionType.Sound) {
      void this.toggleSpeakMessage(messageId);
      return;
    }
    if (action === ChatBubbleActionType.Previous) {
      void this.switchAnswerVariant(messageId, -1);
      return;
    }
    if (action === ChatBubbleActionType.Next) {
      void this.switchAnswerVariant(messageId, 1);
    }
  }

  private resetConversation(showGuideMessage: boolean = true): void {
    this.stopRevealTimer();
    this.closeActiveSession();
    this.stopSpeakingMessage(false);
    this.answerVariantsByMessageId.clear();
    this.conversationId = '';
    this.serviceConversationId = '';
    this.isSending = false;
    this.shouldAutoScrollToBottom = true;
    this.statusText = '请先填写 HiAgent 的 Api URL、ApiKey 和 UserID。';
    this.messages = showGuideMessage ? this.buildGuideMessages() : [];
    this.scrollToBottom(true);
  }

  private async startNewConversation(): Promise<void> {
    if (this.isSending) {
      this.showToast('当前仍在生成中，请稍后再新建会话');
      return;
    }
    this.isConversationDrawerVisible = false;
    this.activeConversationMenuId = '';
    this.isRenameDialogVisible = false;
    this.resetConversation(false);
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.statusText = '请先填写 Api URL、ApiKey 和 UserID。';
      this.scheduleConfigSave();
      return;
    }

    this.statusText = '正在创建新会话...';
    try {
      const conversation: HiAgentConversation = await HiAgentService.createConversation(config);
      this.conversationId = conversation.appConversationId;
      this.upsertConversationItem(conversation.appConversationId, conversation.conversationName, '', Date.now());
      void this.refreshConversationList(false);
      this.statusText = `新会话 ${this.shortenId(conversation.appConversationId)} 已创建。`;
      this.scheduleConfigSave();
    } catch (error) {
      this.statusText = `创建新会话失败：${this.stringifyError(error)}`;
    }
  }

  private restoreSavedConfig(): void {
    try {
      const context: Context = getContext(this);
      const store: preferences.Preferences = AgentConfigStore.open(context);
      this.configStore = store;
      const storedConfig: AgentStoredConfig = AgentConfigStore.load(store);
      this.conversationItems = AgentConversationHelper.sort(AgentConfigStore.loadConversations(store));
      this.apiUrl = storedConfig.apiUrl;
      this.apiKey = storedConfig.apiKey;
      this.userId = storedConfig.userId;
      this.conversationId = storedConfig.conversationId;
      this.isConfigExpanded = storedConfig.isConfigExpanded;
      if (this.buildConfig().isReady()) {
        void this.refreshConversationList(false);
      }
      if (this.buildConfig().isReady() && this.conversationId.trim().length > 0) {
        this.statusText = `已恢复上次会话 ${this.shortenId(this.conversationId)}，正在同步历史...`;
        void this.syncHistory();
      } else if (this.buildConfig().isReady()) {
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
        this.configStore = AgentConfigStore.open(context);
      }
      if (this.configStore === null) {
        return;
      }
      AgentConfigStore.save(this.configStore, new AgentStoredConfig(
        this.apiUrl,
        this.apiKey,
        this.userId,
        this.conversationId,
        this.isConfigExpanded
      ));
      AgentConfigStore.saveConversations(this.configStore, this.conversationItems);
    } catch (_error) {
      // Ignore local persistence errors so chat features remain available.
    }
  }

  private persistConversationList(): void {
    this.scheduleConfigSave();
  }

  private async refreshConversationList(showErrorToast: boolean = true): Promise<void> {
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      return;
    }

    try {
      const remoteConversations: Array<HiAgentConversation> = await HiAgentService.getConversationList(config);
      const nextItems: Array<AgentConversationItem> = [];
      for (let index: number = 0; index < remoteConversations.length; index++) {
        const remoteConversation: HiAgentConversation = remoteConversations[index];
        const localIndex: number = this.getConversationItemIndex(remoteConversation.appConversationId);
        const localItem: AgentConversationItem | null = localIndex >= 0 ? this.conversationItems[localIndex] : null;
        const createdAt: number = remoteConversation.createTimestamp > 0
          ? remoteConversation.createTimestamp * 1000
          : (localItem !== null ? localItem.createdAt : Date.now());
        nextItems.push(new AgentConversationItem(
          remoteConversation.appConversationId,
          remoteConversation.conversationName.trim().length > 0 ? remoteConversation.conversationName : (localItem !== null ? localItem.title : ''),
          createdAt,
          remoteConversation.isPinned || (localItem !== null ? localItem.isPinned : false)
        ));
      }
      this.conversationItems = AgentConversationHelper.sort(nextItems);
      this.persistConversationList();
    } catch (error) {
      if (showErrorToast) {
        this.showToast(`会话列表获取失败：${this.stringifyError(error)}`);
      }
    }
  }

  private upsertConversationItem(appConversationId: string, title: string = '', _preview: string = '', updatedAt: number = 0,
    forceTitleUpdate: boolean = false): void {
    const normalizedId: string = appConversationId.trim();
    if (normalizedId.length === 0) {
      return;
    }

    const normalizedUpdatedAt: number = updatedAt > 0 ? updatedAt : Date.now();
    const nextItems: Array<AgentConversationItem> = [];
    let updated: boolean = false;
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const nextItem: AgentConversationItem = this.conversationItems[index].copy();
      if (nextItem.appConversationId === normalizedId) {
        if (title.trim().length > 0 && (forceTitleUpdate || nextItem.title.trim().length === 0)) {
          nextItem.title = title.trim();
        }
        nextItem.createdAt = normalizedUpdatedAt;
        nextItems.push(nextItem);
        updated = true;
      } else {
        nextItems.push(nextItem);
      }
    }

    if (!updated) {
      nextItems.push(new AgentConversationItem(
        normalizedId,
        title.trim(),
        normalizedUpdatedAt,
        false
      ));
    }

    this.conversationItems = AgentConversationHelper.sort(nextItems);
    this.persistConversationList();
  }

  private getConversationItemIndex(appConversationId: string): number {
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      if (this.conversationItems[index].appConversationId === appConversationId) {
        return index;
      }
    }
    return -1;
  }

  private buildConversationSections(): Array<AgentConversationSection> {
    const sections: Array<AgentConversationSection> = [];
    const pinnedItems: Array<AgentConversationItem> = [];
    const sectionMap: Map<string, Array<AgentConversationItem>> = new Map();
    const orderedTitles: Array<string> = [];

    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const item: AgentConversationItem = this.conversationItems[index];
      if (item.isPinned) {
        pinnedItems.push(item);
        continue;
      }
      const title: string = AgentConversationHelper.buildGroupTitle(item.createdAt);
      const existingItems: Array<AgentConversationItem> | undefined = sectionMap.get(title);
      if (existingItems === undefined) {
        sectionMap.set(title, [item]);
        orderedTitles.push(title);
      } else {
        existingItems.push(item);
      }
    }

    if (pinnedItems.length > 0) {
      sections.push(new AgentConversationSection('置顶', pinnedItems));
    }
    for (let index: number = 0; index < orderedTitles.length; index++) {
      const title: string = orderedTitles[index];
      const items: Array<AgentConversationItem> | undefined = sectionMap.get(title);
      if (items !== undefined) {
        sections.push(new AgentConversationSection(title, items));
      }
    }
    return sections;
  }

  private buildConversationItemKey(item: AgentConversationItem): string {
    return `${item.appConversationId}:${item.title}:${item.isPinned ? '1' : '0'}:${item.createdAt}`;
  }

  private buildConversationSectionKey(section: AgentConversationSection): string {
    let key: string = `${section.title}:${section.items.length}`;
    for (let index: number = 0; index < section.items.length; index++) {
      key += `|${this.buildConversationItemKey(section.items[index])}`;
    }
    return key;
  }

  private cloneConversationItems(): Array<AgentConversationItem> {
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      nextItems.push(this.conversationItems[index].copy());
    }
    return nextItems;
  }

  private isActiveConversationPinned(): boolean {
    const itemIndex: number = this.getConversationItemIndex(this.activeConversationMenuId);
    if (itemIndex < 0) {
      return false;
    }
    return this.conversationItems[itemIndex].isPinned;
  }

  private resolveConversationMenuTopFor(appConversationId: string): number {
    if (appConversationId.length === 0) {
      return 88;
    }
    let itemOffset: number = 0;
    const sections: Array<AgentConversationSection> = this.buildConversationSections();
    for (let sectionIndex: number = 0; sectionIndex < sections.length; sectionIndex++) {
      itemOffset += 26;
      for (let itemIndex: number = 0; itemIndex < sections[sectionIndex].items.length; itemIndex++) {
        if (sections[sectionIndex].items[itemIndex].appConversationId === appConversationId) {
          const nextTop: number = 60 + itemOffset;
          return nextTop > 500 ? 500 : nextTop;
        }
        itemOffset += 60;
      }
      itemOffset += 12;
    }
    return 88;
  }

  private async selectConversation(appConversationId: string): Promise<void> {
    if (this.isSending) {
      this.showToast('当前仍在生成中，请稍后再切换会话');
      return;
    }
    if (appConversationId.trim().length === 0) {
      return;
    }
    this.activeConversationMenuId = '';
    this.isConversationDrawerVisible = false;
    this.isRenameDialogVisible = false;
    if (this.conversationId === appConversationId) {
      this.statusText = `会话 ${this.shortenId(appConversationId)} 已连接，正在同步历史...`;
      await this.syncHistory();
      return;
    }
    this.answerVariantsByMessageId.clear();
    this.messages = this.buildGuideMessages();
    this.conversationId = appConversationId;
    this.scheduleConfigSave();
    this.statusText = `会话 ${this.shortenId(appConversationId)} 已连接，正在同步历史...`;
    await this.syncHistory();
  }

  private async toggleConversationPinned(appConversationId: string): Promise<void> {
    const itemIndex: number = this.getConversationItemIndex(appConversationId);
    if (itemIndex < 0) {
      return;
    }
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }
    const previousItems: Array<AgentConversationItem> = this.cloneConversationItems();
    const nextItems: Array<AgentConversationItem> = [];
    let nextPinnedState: boolean = false;
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const nextItem: AgentConversationItem = this.conversationItems[index].copy();
      if (index === itemIndex) {
        nextItem.isPinned = !nextItem.isPinned;
        nextPinnedState = nextItem.isPinned;
      }
      nextItems.push(nextItem);
    }
    this.conversationItems = AgentConversationHelper.sort(nextItems);
    this.activeConversationMenuId = '';
    this.persistConversationList();
    try {
      if (nextPinnedState) {
        await HiAgentService.setConversationTop(config, appConversationId);
      } else {
        await HiAgentService.cancelConversationTop(config, appConversationId);
      }
    } catch (error) {
      this.conversationItems = previousItems;
      this.persistConversationList();
      this.showToast(this.stringifyError(error));
    }
  }

  private openRenameConversation(appConversationId: string): void {
    const itemIndex: number = this.getConversationItemIndex(appConversationId);
    if (itemIndex < 0) {
      return;
    }
    this.renameConversationId = appConversationId;
    this.renameDraft = this.conversationItems[itemIndex].title;
    this.isRenameDialogVisible = true;
    this.activeConversationMenuId = '';
  }

  private async confirmRenameConversation(): Promise<void> {
    const normalizedTitle: string = this.sanitizeConversationTitle(this.renameDraft, false);
    if (normalizedTitle.length === 0) {
      this.showToast('会话名称不能为空');
      return;
    }
    const targetConversationId: string = this.renameConversationId;
    const itemIndex: number = this.getConversationItemIndex(targetConversationId);
    if (itemIndex < 0) {
      this.isRenameDialogVisible = false;
      return;
    }
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }
    const previousItems: Array<AgentConversationItem> = this.cloneConversationItems();
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      const nextItem: AgentConversationItem = this.conversationItems[index].copy();
      if (index === itemIndex) {
        nextItem.title = normalizedTitle;
      }
      nextItems.push(nextItem);
    }
    this.conversationItems = AgentConversationHelper.sort(nextItems);
    this.isRenameDialogVisible = false;
    this.renameConversationId = '';
    this.renameDraft = '';
    this.persistConversationList();
    try {
      await HiAgentService.updateConversation(config, targetConversationId, normalizedTitle);
    } catch (error) {
      this.conversationItems = previousItems;
      this.persistConversationList();
      this.showToast(this.stringifyError(error));
    }
  }

  private async deleteConversationItem(appConversationId: string): Promise<void> {
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }
    try {
      await HiAgentService.deleteConversation(config, appConversationId);
    } catch (error) {
      this.showToast(this.stringifyError(error));
      return;
    }
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < this.conversationItems.length; index++) {
      if (this.conversationItems[index].appConversationId !== appConversationId) {
        nextItems.push(this.conversationItems[index].copy());
      }
    }
    this.conversationItems = nextItems;
    this.activeConversationMenuId = '';
    this.persistConversationList();
    if (this.conversationId === appConversationId) {
      this.startNewConversation();
    }
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

    const needsCreateConversation: boolean = this.conversationId.trim().length === 0;
    const shouldUpdateEmptyConversationTitle: boolean = this.isCurrentConversationEmpty();

    const nextMessages: Array<ChatMessage> = this.messages.slice();
    const userMessage: ChatMessage = ChatMessage.user(this.createMessageId('user'), prompt);
    userMessage.conversationId = this.conversationId;
    this.syncMessageUiState(userMessage);
    nextMessages.push(userMessage);
    const assistantMessageId: string = this.createMessageId('assistant');
    const assistantMessage: ChatMessage = ChatMessage.assistant(assistantMessageId, '', '', true);
    assistantMessage.conversationId = this.conversationId;
    assistantMessage.streamCompleted = false;
    this.applyMessagePhase(assistantMessage, ChatMessagePhase.Sending, '发送中');
    this.syncMessageUiState(assistantMessage);
    const initialVariants: Array<ChatAnswerVariant> = [this.createAnswerVariantFromMessage(assistantMessage)];
    this.replaceAnswerVariants(assistantMessage.id, initialVariants);
    this.applyAnswerVariantMeta(assistantMessage, initialVariants);
    nextMessages.push(assistantMessage);
    this.messages = nextMessages;
    this.activeAssistantMessageId = assistantMessageId;
    this.isSending = true;
    this.draft = '';
    this.statusText = this.conversationId.length > 0 ? `会话 ${this.shortenId(this.conversationId)} 已连接，正在发送...` : '正在创建会话...';
    this.shouldAutoScrollToBottom = true;
    this.scrollToBottom(true);
    this.startRevealTimer(assistantMessageId);

    try {
      const appConversationId: string = await this.ensureConversation(config);
      const sanitizedPromptTitle: string = this.sanitizeConversationTitle(prompt, true);
      this.upsertConversationItem(appConversationId, sanitizedPromptTitle, prompt, Date.now());
      if (shouldUpdateEmptyConversationTitle && sanitizedPromptTitle.length > 0) {
        this.pendingConversationTitleByMessageId.set(assistantMessageId, sanitizedPromptTitle);
      } else {
        this.pendingConversationTitleByMessageId.delete(assistantMessageId);
      }
      void this.refreshConversationList(false);
      this.bindPendingMessagesToConversation(appConversationId, assistantMessageId);
      this.updateAssistantPhase(assistantMessageId, ChatMessagePhase.Sending, '发送中', 'request_start');
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
      const errorText: string = this.stringifyError(error);
      if (needsCreateConversation) {
        this.failAssistantMessage(assistantMessageId, `创建会话失败：${errorText}`);
      } else {
        this.failAssistantMessage(assistantMessageId, errorText);
      }
    }
  }

  private isCurrentConversationEmpty(): boolean {
    for (let index: number = 0; index < this.messages.length; index++) {
      const message: ChatMessage = this.messages[index];
      if (message.role === MessageRole.User || message.role === MessageRole.Assistant) {
        if (message.rawContent.trim().length > 0 || message.visibleContent.trim().length > 0) {
          return false;
        }
      }
    }
    return true;
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
      this.answerVariantsByMessageId.clear();
      this.messages = this.buildHistoryMessages(historyMessages);
      void this.refreshConversationList(false);
      if (historyMessages.length > 0) {
        const latestHistory: HiAgentHistoryMessage = historyMessages[historyMessages.length - 1];
        const previewText: string = latestHistory.query.trim().length > 0 ? latestHistory.query : latestHistory.answer;
        const titleText: string = latestHistory.query.trim().length > 0 ? latestHistory.query : previewText;
        this.upsertConversationItem(this.conversationId, titleText, previewText, latestHistory.createdTime * 1000);
      }
      this.statusText = historyMessages.length > 0 ? `已同步 ${historyMessages.length} 条历史记录。` : '当前会话还没有历史消息。';
      this.shouldAutoScrollToBottom = true;
      this.scrollToBottom(true);
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
        this.applyMessageToList(messageIndex, nextMessage);
        this.scrollToBottom();
        return;
      }

      if (message.streamCompleted) {
        if (message.isStreaming) {
          const nextMessage: ChatMessage = message.copy();
          nextMessage.isStreaming = false;
          this.applyMessageToList(messageIndex, nextMessage);
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

  private scrollToBottom(force: boolean = false): void {
    if (!force && !this.shouldAutoScrollToBottom) {
      return;
    }
    setTimeout(() => {
      this.messageScroller.scrollEdge(Edge.Bottom);
    }, 30);
  }

  private safeIsAtEnd(): boolean {
    try {
      return this.messageScroller.isAtEnd();
    } catch (_error) {
      return this.shouldAutoScrollToBottom;
    }
  }

  private findMessageIndex(messageId: string): number {
    for (let index: number = 0; index < this.messages.length; index++) {
      if (this.messages[index].id === messageId) {
        return index;
      }
    }
    return -1;
  }

  private getMessageById(messageId: string): ChatMessage | null {
    const messageIndex: number = this.findMessageIndex(messageId);
    if (messageIndex < 0) {
      return null;
    }
    return this.messages[messageIndex];
  }

  private ensureAnswerVariants(message: ChatMessage): Array<ChatAnswerVariant> {
    const existingVariants: Array<ChatAnswerVariant> | undefined = this.answerVariantsByMessageId.get(message.id);
    if (existingVariants !== undefined) {
      this.applyAnswerVariantMeta(message, existingVariants);
      return existingVariants;
    }

    if (message.role !== MessageRole.Assistant) {
      return [];
    }

    const variants: Array<ChatAnswerVariant> = [this.createAnswerVariantFromMessage(message)];
    this.answerVariantsByMessageId.set(message.id, variants);
    this.applyAnswerVariantMeta(message, variants);
    return variants;
  }

  private createAnswerVariantFromMessage(message: ChatMessage): ChatAnswerVariant {
    return AgentVariantHelper.createAnswerVariantFromMessage(
      message,
      this.createMessageId(`variant-${message.id}`)
    );
  }

  private applyAnswerVariantMeta(message: ChatMessage, variants: Array<ChatAnswerVariant>): void {
    AgentVariantHelper.applyAnswerVariantMeta(message, variants);
  }

  private syncMessageToActiveVariant(message: ChatMessage): void {
    if (message.role !== MessageRole.Assistant) {
      return;
    }

    const variants: Array<ChatAnswerVariant> = this.ensureAnswerVariants(message);
    if (variants.length === 0) {
      return;
    }

    const activeVariant: ChatAnswerVariant = variants[message.activeAnswerVersionIndex];
    AgentVariantHelper.syncMessageToVariant(message, activeVariant);
  }

  private applyActiveVariantToMessage(message: ChatMessage): void {
    if (message.role !== MessageRole.Assistant) {
      return;
    }

    const variants: Array<ChatAnswerVariant> = this.ensureAnswerVariants(message);
    if (variants.length === 0) {
      return;
    }

    const activeVariant: ChatAnswerVariant = variants[message.activeAnswerVersionIndex];
    AgentVariantHelper.applyVariantToMessage(message, activeVariant);
  }

  private replaceAnswerVariants(messageId: string, variants: Array<ChatAnswerVariant>): void {
    this.answerVariantsByMessageId.set(messageId, variants);
  }

  private syncMessageUiState(message: ChatMessage): void {
    if (message.role !== MessageRole.Assistant) {
      message.showActions = false;
      return;
    }

    message.showActions = message.visibleContent.trim().length > 0 && !message.isStreaming;
  }

  private patchMessage(target: ChatMessage, source: ChatMessage): void {
    target.role = source.role;
    target.rawContent = source.rawContent;
    target.visibleContent = source.visibleContent;
    target.isStreaming = source.isStreaming;
    target.streamCompleted = source.streamCompleted;
    target.streamPhase = source.streamPhase;
    target.statusLabel = source.statusLabel;
    target.lastEvent = source.lastEvent;
    target.conversationId = source.conversationId;
    target.queryId = source.queryId;
    target.serviceMessageId = source.serviceMessageId;
    target.taskId = source.taskId;
    target.createdAt = source.createdAt;
    target.feedback = source.feedback;
    target.answerVersionCount = source.answerVersionCount;
    target.activeAnswerVersionIndex = source.activeAnswerVersionIndex;
    target.showActions = source.showActions;
  }

  private getActiveAnswerVariant(message: ChatMessage): ChatAnswerVariant | null {
    const variants: Array<ChatAnswerVariant> = this.ensureAnswerVariants(message);
    if (variants.length === 0) {
      return null;
    }
    return variants[message.activeAnswerVersionIndex];
  }

  private cloneAnswerVariants(messageId: string): Array<ChatAnswerVariant> {
    const variants: Array<ChatAnswerVariant> | undefined = this.answerVariantsByMessageId.get(messageId);
    if (variants === undefined) {
      return [];
    }
    const nextVariants: Array<ChatAnswerVariant> = [];
    for (let index: number = 0; index < variants.length; index++) {
      nextVariants.push(variants[index].copy());
    }
    return nextVariants;
  }

  private buildVariantMergeKey(variant: ChatAnswerVariant): string {
    return AgentVariantHelper.buildVariantMergeKey(variant);
  }

  private buildPendingQueryAgainVariant(localMessageId: string): ChatAnswerVariant {
    return AgentVariantHelper.buildPendingQueryAgainVariant(localMessageId, (prefix: string): string => {
      return this.createMessageId(prefix);
    });
  }

  private applyMessageToList(messageIndex: number, nextMessage: ChatMessage): void {
    this.syncMessageToActiveVariant(nextMessage);
    this.syncMessageUiState(nextMessage);
    this.patchMessage(this.messages[messageIndex], nextMessage);
    this.messages = this.messages.slice();
  }

  private findPairedUserMessageIndex(assistantMessageIndex: number): number {
    if (assistantMessageIndex <= 0 || assistantMessageIndex >= this.messages.length) {
      return -1;
    }

    for (let index: number = assistantMessageIndex - 1; index >= 0; index--) {
      const candidate: ChatMessage = this.messages[index];
      if (candidate.role === MessageRole.User) {
        return index;
      }
      if (candidate.role === MessageRole.Assistant) {
        return -1;
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
    this.syncMessageUiState(guideMessage);
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
        this.syncMessageUiState(userMessage);
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
        assistantMessage.queryId = historyMessage.queryId;
        assistantMessage.serviceMessageId = historyMessage.messageId;
        assistantMessage.taskId = historyMessage.taskId;
        assistantMessage.createdAt = historyMessage.createdTime * 1000;
        const variants: Array<ChatAnswerVariant> = this.buildVariantsFromHistoryMessage(historyMessage);
        this.replaceAnswerVariants(assistantMessage.id, variants);
        this.applyAnswerVariantMeta(assistantMessage, variants);
        assistantMessage.answerVersionCount = variants.length;
        assistantMessage.activeAnswerVersionIndex = variants.length > 0 ? variants.length - 1 : 0;
        this.applyActiveVariantToMessage(assistantMessage);
        this.syncMessageUiState(assistantMessage);
        nextMessages.push(assistantMessage);
      }
    }
    return nextMessages;
  }

  private buildVariantsFromHistoryMessage(historyMessage: HiAgentHistoryMessage): Array<ChatAnswerVariant> {
    const variants: Array<ChatAnswerVariant> = [];
    for (let index: number = 0; index < historyMessage.otherAnswers.length; index++) {
      variants.push(this.buildVariantFromAnswerInfo(historyMessage.otherAnswers[index]));
    }

    if (historyMessage.answerInfo.messageId.trim().length > 0 || historyMessage.answerInfo.answer.trim().length > 0) {
      variants.push(this.buildVariantFromAnswerInfo(historyMessage.answerInfo));
    } else if (historyMessage.answer.trim().length > 0) {
      const fallbackAnswerInfo: HiAgentMessageAnswerInfo = new HiAgentMessageAnswerInfo(
        historyMessage.answer,
        historyMessage.messageId,
        historyMessage.createdTime,
        historyMessage.taskId
      );
      variants.push(this.buildVariantFromAnswerInfo(fallbackAnswerInfo));
    }

    variants.sort((left: ChatAnswerVariant, right: ChatAnswerVariant) => left.createdAt - right.createdAt);
    return variants;
  }

  private async ensureConversation(config: HiAgentConfig): Promise<string> {
    if (this.conversationId.trim().length > 0) {
      return this.conversationId.trim();
    }

    const conversation = await HiAgentService.createConversation(config);
    this.conversationId = conversation.appConversationId;
    this.upsertConversationItem(conversation.appConversationId, conversation.conversationName, '', Date.now());
    void this.refreshConversationList(false);
    this.scheduleConfigSave();
    return conversation.appConversationId;
  }

  private handleStreamEvent(localMessageId: string, event: HiAgentStreamEvent): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = this.messages[messageIndex].copy();
    const normalizedEventName: string = HiAgentEventHelper.normalizeEventName(event.event);
    if (event.conversationId.length > 0) {
      this.serviceConversationId = event.conversationId;
    }
    if (nextMessage.conversationId.length === 0 && this.conversationId.length > 0) {
      nextMessage.conversationId = this.conversationId;
    }
    if (event.taskId.length > 0) {
      nextMessage.taskId = event.taskId;
    }
    nextMessage.serviceMessageId = this.resolveServiceMessageId(nextMessage, event, normalizedEventName);
    if (normalizedEventName.length > 0) {
      nextMessage.lastEvent = normalizedEventName;
    }

    if (this.isKeepAliveEvent(normalizedEventName)) {
      return;
    }

    if (this.shouldAppendAnswer(normalizedEventName, event)) {
      nextMessage.rawContent = this.mergeStreamAnswer(nextMessage.rawContent, event.answer, normalizedEventName === 'message_replace');
    }

    if (HiAgentEventHelper.isErrorEvent(normalizedEventName, event.status)) {
      this.failAssistantMessage(localMessageId, HiAgentEventHelper.extractEventErrorMessage(event));
      return;
    }

    const phase: ChatMessagePhase = this.resolveStreamPhase(nextMessage, event, normalizedEventName);
    const phaseLabel: string = this.resolvePhaseLabel(phase, event, normalizedEventName, nextMessage.statusLabel);
    this.applyMessagePhase(nextMessage, phase, phaseLabel, normalizedEventName);
    if (phase === ChatMessagePhase.Stopped && nextMessage.rawContent.trim().length === 0) {
      nextMessage.rawContent = '已停止本次生成。';
    }
    nextMessage.streamCompleted = phase === ChatMessagePhase.Finished || phase === ChatMessagePhase.Stopped;
    if (nextMessage.streamCompleted) {
      nextMessage.visibleContent = nextMessage.rawContent;
      nextMessage.isStreaming = false;
    } else {
      nextMessage.isStreaming = nextMessage.visibleContent.length < nextMessage.rawContent.length;
    }

    this.applyMessageToList(messageIndex, nextMessage);
    this.statusText = this.resolveStatusTextByPhase(phase, phaseLabel);
    this.scrollToBottom();

    if (phase === ChatMessagePhase.Finished || phase === ChatMessagePhase.Stopped) {
      this.finishSending(this.resolveStatusTextByPhase(phase, phaseLabel));
    }
  }

  private completeAssistantMessage(localMessageId: string, statusText: string, fallbackLookupMessageId: string = ''): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex >= 0) {
      const nextMessage: ChatMessage = this.messages[messageIndex].copy();
      this.applyMessagePhase(nextMessage, ChatMessagePhase.Finished, '已结束', nextMessage.lastEvent);
      nextMessage.streamCompleted = true;
      nextMessage.visibleContent = nextMessage.rawContent;
      nextMessage.isStreaming = false;
      this.applyMessageToList(messageIndex, nextMessage);
    }
    void this.applyPendingConversationTitle(localMessageId);
    this.finishSending(statusText);
  }

  private failAssistantMessage(localMessageId: string, errorMessage: string): void {
    this.pendingConversationTitleByMessageId.delete(localMessageId);
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex >= 0) {
      const nextMessage: ChatMessage = this.messages[messageIndex].copy();
      if (nextMessage.rawContent.trim().length === 0) {
        nextMessage.rawContent = '接口请求失败，请稍后重试。';
        nextMessage.visibleContent = '';
      }
      this.applyMessagePhase(nextMessage, ChatMessagePhase.Error, '出错', 'error');
      nextMessage.streamCompleted = true;
      nextMessage.isStreaming = true;
      this.applyMessageToList(messageIndex, nextMessage);
      this.startRevealTimer(localMessageId);
    }
    this.finishSending(`请求失败：${errorMessage}`);
  }

  private markAssistantStopped(localMessageId: string): void {
    this.pendingConversationTitleByMessageId.delete(localMessageId);
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = this.messages[messageIndex].copy();
    if (nextMessage.rawContent.trim().length === 0) {
      nextMessage.rawContent = '响应生成已停止~';
      nextMessage.visibleContent = '';
    }
    this.applyMessagePhase(nextMessage, ChatMessagePhase.Stopped, '已停止', 'stopped');
    nextMessage.streamCompleted = true;
    nextMessage.isStreaming = true;
    this.applyMessageToList(messageIndex, nextMessage);
    this.startRevealTimer(localMessageId);
  }

  private finishSending(statusText: string): void {
    const localAssistantMessageId: string = this.activeAssistantMessageId;
    if (localAssistantMessageId.length > 0) {
      const messageIndex: number = this.findMessageIndex(localAssistantMessageId);
      if (messageIndex >= 0) {
        const nextMessage: ChatMessage = this.messages[messageIndex].copy();
        if (nextMessage.rawContent.length > 0) {
          nextMessage.visibleContent = nextMessage.rawContent;
        }
        nextMessage.isStreaming = false;
        if (nextMessage.streamPhase !== ChatMessagePhase.Error && nextMessage.streamPhase !== ChatMessagePhase.Stopped) {
          nextMessage.streamCompleted = true;
        }
        this.syncMessageUiState(nextMessage);
        this.applyMessageToList(messageIndex, nextMessage);
      }
      void this.applyPendingConversationTitle(localAssistantMessageId);
    }
    if (this.activeStreamSession !== null) {
      this.activeStreamSession.close();
    }
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

  private sanitizeConversationTitle(title: string, stripControlChars: boolean): string {
    let nextTitle: string = stripControlChars ? title.replace(/[\n\r\t]/g, '') : title;
    nextTitle = nextTitle.trim();
    if (nextTitle.length > 100) {
      nextTitle = nextTitle.substring(0, 100);
    }
    return nextTitle;
  }

  private async applyPendingConversationTitle(localMessageId: string): Promise<void> {
    const pendingTitle: string | undefined = this.pendingConversationTitleByMessageId.get(localMessageId);
    if (pendingTitle === undefined || pendingTitle.trim().length === 0) {
      return;
    }
    this.pendingConversationTitleByMessageId.delete(localMessageId);
    const message: ChatMessage | null = this.getMessageById(localMessageId);
    if (message === null) {
      return;
    }
    const appConversationId: string = message.conversationId.trim().length > 0 ? message.conversationId.trim() : this.conversationId.trim();
    if (appConversationId.length === 0) {
      return;
    }

      this.upsertConversationItem(appConversationId, pendingTitle, '', Date.now(), true);
    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      return;
    }
    try {
      await HiAgentService.updateConversation(config, appConversationId, pendingTitle);
    } catch (_error) {
      // Keep the local title even if remote rename fails after a successful first reply.
    }
  }

  private bindPendingMessagesToConversation(appConversationId: string, assistantMessageId: string): void {
    if (appConversationId.trim().length === 0) {
      return;
    }

    let assistantBound: boolean = false;
    let userBound: boolean = false;
    for (let index: number = this.messages.length - 1; index >= 0; index--) {
      const nextMessage: ChatMessage = this.messages[index];
      if (!assistantBound && nextMessage.id === assistantMessageId) {
        nextMessage.conversationId = appConversationId;
        assistantBound = true;
        continue;
      }

      if (!userBound && nextMessage.role === 'user' && nextMessage.conversationId.trim().length === 0) {
        nextMessage.conversationId = appConversationId;
        userBound = true;
      }

      if (assistantBound && userBound) {
        break;
      }
    }
    this.messages = this.messages.slice();
  }

  private applyMessagePhase(message: ChatMessage, phase: ChatMessagePhase, label: string, eventName: string = ''): void {
    message.streamPhase = phase;
    message.statusLabel = label;
    if (eventName.length > 0) {
      message.lastEvent = eventName;
    }
  }

  private updateAssistantPhase(localMessageId: string, phase: ChatMessagePhase, label: string,
    eventName: string = ''): void {
    const messageIndex: number = this.findMessageIndex(localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = this.messages[messageIndex].copy();
    this.applyMessagePhase(nextMessage, phase, label, eventName);
    this.applyMessageToList(messageIndex, nextMessage);
  }

  private resolveStreamPhase(message: ChatMessage, event: HiAgentStreamEvent, eventName: string): ChatMessagePhase {
    if (HiAgentEventHelper.isStoppedEvent(eventName)) {
      return ChatMessagePhase.Stopped;
    }
    if (this.isTerminalEvent(eventName, event.status)) {
      return ChatMessagePhase.Finished;
    }
    if (this.isAnsweringEvent(eventName, event)) {
      return ChatMessagePhase.Answering;
    }
    if (HiAgentEventHelper.isThinkingEvent(eventName, event.status, event.thought)) {
      return ChatMessagePhase.Thinking;
    }
    if (HiAgentEventHelper.isProgressOnlyEvent(eventName)) {
      return message.streamPhase;
    }
    if (message.rawContent.trim().length > 0) {
      return ChatMessagePhase.Answering;
    }
    return ChatMessagePhase.Thinking;
  }

  private resolvePhaseLabel(phase: ChatMessagePhase, event: HiAgentStreamEvent, eventName: string,
    currentLabel: string): string {
    const eventLabel: string = HiAgentEventHelper.resolveEventLabel(eventName, phase, event);
    if (eventLabel.length > 0) {
      return eventLabel;
    }
    if (phase === ChatMessagePhase.Sending) {
      return '发送中';
    }
    if (phase === ChatMessagePhase.Thinking) {
      if (event.status.toLowerCase() === 'queued') {
        return '排队中';
      }
      return 'AI 正在思考中';
    }
    if (phase === ChatMessagePhase.Answering) {
      return '回答中';
    }
    if (phase === ChatMessagePhase.Finished) {
      return '已结束';
    }
    if (phase === ChatMessagePhase.Stopped) {
      return '已停止';
    }
    if (phase === ChatMessagePhase.Error) {
      return '出错';
    }
    return currentLabel;
  }

  private resolveStatusTextByPhase(phase: ChatMessagePhase, phaseLabel: string): string {
    if (phase === ChatMessagePhase.Sending) {
      return '消息发送中...';
    }
    if (phase === ChatMessagePhase.Thinking) {
      return phaseLabel.length > 0 && phaseLabel !== 'AI 正在思考中'
        ? `AI 正在思考中：${phaseLabel}...`
        : 'AI 正在思考中...';
    }
    if (phase === ChatMessagePhase.Answering) {
      return phaseLabel.length > 0 && phaseLabel !== '回答中'
        ? `AI 正在回答中：${phaseLabel}...`
        : 'AI 正在回答中...';
    }
    if (phase === ChatMessagePhase.Finished) {
      return '回答已结束。';
    }
    if (phase === ChatMessagePhase.Stopped) {
      return '已停止当前回复。';
    }
    if (phase === ChatMessagePhase.Error) {
      return '当前回复出错。';
    }
    return this.statusText;
  }

  private shouldAppendAnswer(eventName: string, event: HiAgentStreamEvent): boolean {
    const normalizedAnswer: string = this.normalizeStreamText(event.answer);
    if (normalizedAnswer.length === 0) {
      return false;
    }
    return eventName === 'message' || eventName === 'message_replace' || eventName.length === 0;
  }

  private isAnsweringEvent(eventName: string, event: HiAgentStreamEvent): boolean {
    return eventName === 'message_output_start' ||
      eventName === 'message' ||
      eventName === 'message_replace' ||
      eventName === 'message_output_end' ||
      (eventName.length === 0 && this.normalizeStreamText(event.answer).length > 0);
  }

  private isKeepAliveEvent(eventName: string): boolean {
    return eventName === 'ping' || eventName === 'keepalive' || eventName === 'keep_alive';
  }

  private isTerminalEvent(eventName: string, status: string): boolean {
    const normalizedStatus: string = status.trim().toLowerCase();
    return eventName === 'message_end' ||
      eventName === 'message_finish' ||
      eventName === 'flow_end' ||
      eventName === 'done' ||
      eventName === 'finish' ||
      eventName === 'finished' ||
      eventName === 'completed' ||
      normalizedStatus === 'finished' ||
      normalizedStatus === 'completed' ||
      normalizedStatus === 'done';
  }

  private resolveServiceMessageId(message: ChatMessage, event: HiAgentStreamEvent, eventName: string): string {
    if (HiAgentEventHelper.isRootMessageEvent(eventName) && event.messageId.trim().length > 0) {
      return event.messageId.trim();
    }
    return message.serviceMessageId;
  }

  private buildConfig(): HiAgentConfig {
    return new HiAgentConfig(this.apiUrl, this.apiKey, this.userId);
  }

  private mergeStreamAnswer(currentContent: string, incomingContent: string, replaceAll: boolean = false): string {
    return AgentTextUtils.mergeStreamAnswer(currentContent, incomingContent, replaceAll);
  }

  private normalizeStreamText(content: string): string {
    return AgentTextUtils.normalizeStreamText(content);
  }

  private shortenId(value: string): string {
    return AgentTextUtils.shortenId(value);
  }

  private stringifyError(error: Object): string {
    return AgentTextUtils.stringifyError(error);
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

  private async copyMessageText(messageId: string): Promise<void> {
    const message: ChatMessage | null = this.getMessageById(messageId);
    if (message === null) {
      return;
    }

    const plainText: string = message.rawContent.length > 0 ? message.rawContent : message.visibleContent;
    if (plainText.trim().length === 0) {
      this.showToast('当前回复还没有内容可复制');
      return;
    }

    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, plainText);
      await systemPasteboard.setData(data);
      this.showToast('已复制回复内容');
    } catch (_error) {
      this.showToast('复制失败，请稍后重试');
    }
  }

  private async queryAgainAssistantMessage(messageId: string): Promise<void> {
    if (this.isSending) {
      this.showToast('当前已有回复在生成，请稍后再试');
      return;
    }

    const messageIndex: number = this.findMessageIndex(messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }

    const pairedUserMessageIndex: number = this.findPairedUserMessageIndex(messageIndex);
    const pairedUserMessage: ChatMessage | null = pairedUserMessageIndex >= 0 ? this.messages[pairedUserMessageIndex].copy() : null;
    const sourceMessage: ChatMessage = this.messages[messageIndex].copy();
    const existingVariants: Array<ChatAnswerVariant> = this.ensureAnswerVariants(sourceMessage);
    if (existingVariants.length > 0) {
      this.syncMessageToActiveVariant(sourceMessage);
    }
    if (existingVariants.length >= 10) {
      this.showToast('最多只支持10次生成哦~');
      return;
    }

    const activeVariant: ChatAnswerVariant | null = this.getActiveAnswerVariant(sourceMessage);
    if (activeVariant === null || activeVariant.serviceMessageId.trim().length === 0) {
      this.showToast('当前回复还没有可重新回答的 messageId');
      return;
    }
    const appConversationId: string = sourceMessage.conversationId.trim().length > 0 ? sourceMessage.conversationId : this.conversationId;
    if (appConversationId.trim().length === 0) {
      this.showToast('当前还没有有效的会话 ID');
      return;
    }
    this.upsertConversationItem(appConversationId, '', sourceMessage.rawContent, Date.now());

    const regeneratedAssistantMessageId: string = this.createMessageId('assistant');
    const nextVariants: Array<ChatAnswerVariant> = this.cloneAnswerVariants(messageId);
    const pendingVariant: ChatAnswerVariant = this.buildPendingQueryAgainVariant(regeneratedAssistantMessageId);
    pendingVariant.serviceMessageId = activeVariant.serviceMessageId;
    pendingVariant.taskId = activeVariant.taskId;
    nextVariants.push(pendingVariant);
    this.answerVariantsByMessageId.delete(messageId);
    this.replaceAnswerVariants(regeneratedAssistantMessageId, nextVariants);

    sourceMessage.activeAnswerVersionIndex = nextVariants.length - 1;
    sourceMessage.id = regeneratedAssistantMessageId;
    this.applyActiveVariantToMessage(sourceMessage);
    sourceMessage.conversationId = appConversationId;
    sourceMessage.queryId = '';
    sourceMessage.serviceMessageId = activeVariant.serviceMessageId;
    sourceMessage.taskId = activeVariant.taskId;
    sourceMessage.rawContent = '';
    sourceMessage.visibleContent = '';
    sourceMessage.feedback = MessageFeedback.None;
    sourceMessage.createdAt = pendingVariant.createdAt;
    this.syncMessageUiState(sourceMessage);
    const nextMessages: Array<ChatMessage> = this.messages.slice();
    nextMessages.splice(messageIndex, 1);
    if (pairedUserMessageIndex >= 0) {
      nextMessages.splice(pairedUserMessageIndex, 1);
    }
    if (pairedUserMessage !== null) {
      pairedUserMessage.id = this.createMessageId('user');
      this.syncMessageUiState(pairedUserMessage);
      nextMessages.push(pairedUserMessage);
    }
    nextMessages.push(sourceMessage);
    this.messages = nextMessages;
    this.activeAssistantMessageId = regeneratedAssistantMessageId;
    this.isSending = true;
    this.statusText = '正在重新回答这条回复...';
    this.startRevealTimer(regeneratedAssistantMessageId);
    this.scrollToBottom(true);

    this.activeStreamSession = HiAgentService.startQueryAgainStream(
      config,
      appConversationId,
      activeVariant.serviceMessageId,
      (event: HiAgentStreamEvent) => {
        this.handleStreamEvent(regeneratedAssistantMessageId, event);
      },
      () => {
        this.completeAssistantMessage(regeneratedAssistantMessageId, '重新回答完成。', activeVariant.serviceMessageId);
      },
      (errorMessage: string) => {
        this.failAssistantMessage(regeneratedAssistantMessageId, errorMessage);
      }
    );
  }

  private async deleteAssistantMessage(messageId: string): Promise<void> {
    const messageIndex: number = this.findMessageIndex(messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }

    const hydratedMessage: ChatMessage = this.messages[messageIndex].copy();
    this.applyActiveVariantToMessage(hydratedMessage);
    const activeVariant: ChatAnswerVariant | null = this.getActiveAnswerVariant(hydratedMessage);
    if (activeVariant === null || activeVariant.serviceMessageId.trim().length === 0) {
      this.showToast('当前回复缺少删除所需的 messageId');
      return;
    }

    try {
      await HiAgentService.deleteMessage(config, activeVariant.serviceMessageId);
      if (this.speakingMessageId === messageId) {
        this.stopSpeakingMessage(false);
      }

      const nextVariants: Array<ChatAnswerVariant> = this.cloneAnswerVariants(messageId);
      nextVariants.splice(hydratedMessage.activeAnswerVersionIndex, 1);
      if (nextVariants.length === 0) {
        this.answerVariantsByMessageId.delete(messageId);
        const nextMessages: Array<ChatMessage> = this.messages.slice();
        const pairedUserMessageIndex: number = this.findPairedUserMessageIndex(messageIndex);
        nextMessages.splice(messageIndex, 1);
        if (pairedUserMessageIndex >= 0) {
          nextMessages.splice(pairedUserMessageIndex, 1);
        }
        this.messages = nextMessages;
        this.statusText = pairedUserMessageIndex >= 0 ? '已删除当前问答。' : '已删除当前回复。';
      } else {
        const fallbackIndex: number = Math.min(hydratedMessage.activeAnswerVersionIndex, nextVariants.length - 1);
        this.replaceAnswerVariants(messageId, nextVariants);
        const nextMessage: ChatMessage = hydratedMessage.copy();
        nextMessage.activeAnswerVersionIndex = fallbackIndex;
        this.applyActiveVariantToMessage(nextMessage);
        this.applyMessageToList(messageIndex, nextMessage);
        this.statusText = '已删除当前回复。';
      }
    } catch (error) {
      const errorMessage: string = this.stringifyError(error);
      this.statusText = `删除失败：${errorMessage}`;
      this.showToast(errorMessage);
    }
  }

  private async toggleFeedback(messageId: string, nextFeedback: MessageFeedback): Promise<void> {
    const messageIndex: number = this.findMessageIndex(messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }

    const nextMessage: ChatMessage = this.messages[messageIndex].copy();
    const activeVariant: ChatAnswerVariant | null = this.getActiveAnswerVariant(nextMessage);
    if (activeVariant === null || activeVariant.serviceMessageId.trim().length === 0) {
      this.showToast('当前回复还没有可反馈的 messageId');
      return;
    }

    const targetFeedback: MessageFeedback = nextMessage.feedback === nextFeedback ? MessageFeedback.None : nextFeedback;
    try {
      await HiAgentService.feedback(config, activeVariant.serviceMessageId, this.toLikeType(targetFeedback));
      nextMessage.feedback = targetFeedback;
      this.applyMessageToList(messageIndex, nextMessage);

      if (targetFeedback === MessageFeedback.Like) {
        this.showToast('已点赞这条回复');
        return;
      }
      if (targetFeedback === MessageFeedback.Dislike) {
        this.showToast('已点踩这条回复');
        return;
      }
      this.showToast('已取消反馈');
    } catch (error) {
      this.statusText = `反馈失败：${this.stringifyError(error)}`;
      this.showToast('反馈设置失败');
    }
  }

  private async switchAnswerVariant(messageId: string, offset: number): Promise<void> {
    const messageIndex: number = this.findMessageIndex(messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = this.buildConfig();
    if (!config.isReady()) {
      this.showToast('请先填写接口配置');
      return;
    }

    const hydratedMessage: ChatMessage = this.messages[messageIndex].copy();
    const variants: Array<ChatAnswerVariant> = this.cloneAnswerVariants(messageId);
    if (variants.length <= 1) {
      this.showToast('当前只有一个回复版本');
      return;
    }

    const nextIndex: number = hydratedMessage.activeAnswerVersionIndex + offset;
    if (nextIndex < 0 || nextIndex >= variants.length) {
      return;
    }

    const targetVariant: ChatAnswerVariant = variants[nextIndex];
    if (targetVariant.serviceMessageId.trim().length === 0) {
      this.showToast('当前回复版本还没有有效的 messageId');
      return;
    }

    const optimisticMessage: ChatMessage = hydratedMessage.copy();
    optimisticMessage.activeAnswerVersionIndex = nextIndex;
    optimisticMessage.answerVersionCount = variants.length;
    this.applyActiveVariantToMessage(optimisticMessage);
    this.applyMessageToList(messageIndex, optimisticMessage);

    try {
      await HiAgentService.setMessageAnswerUsed(config, targetVariant.serviceMessageId);
      this.statusText = `已切换到第 ${nextIndex + 1}/${variants.length} 个回复。`;
    } catch (error) {
      const rollbackMessage: ChatMessage = hydratedMessage.copy();
      rollbackMessage.answerVersionCount = variants.length;
      this.applyMessageToList(messageIndex, rollbackMessage);
      this.statusText = `切换回复失败：${this.stringifyError(error)}`;
      this.showToast('切换回复失败');
    }
  }

  private buildVariantFromAnswerInfo(answerInfo: HiAgentMessageAnswerInfo): ChatAnswerVariant {
    return AgentVariantHelper.buildVariantFromAnswerInfo(answerInfo, (prefix: string): string => {
      return this.createMessageId(prefix);
    });
  }

  private toLikeType(feedback: MessageFeedback): number {
    return AgentVariantHelper.toLikeType(feedback);
  }

  private toMessageFeedback(likeType: number): MessageFeedback {
    return AgentVariantHelper.toMessageFeedback(likeType);
  }

  private async toggleSpeakMessage(messageId: string): Promise<void> {
    if (this.speakingMessageId === messageId) {
      this.stopSpeakingMessage(true);
      return;
    }

    const message: ChatMessage | null = this.getMessageById(messageId);
    if (message === null) {
      return;
    }

    const speechText: string = this.buildSpeechText(message.rawContent.length > 0 ? message.rawContent : message.visibleContent);
    if (speechText.length === 0) {
      this.showToast('当前回复还没有可播报的内容');
      return;
    }

    try {
      const engine: textToSpeech.TextToSpeechEngine = await this.ensureSpeechEngine();
      if (engine.isBusy()) {
        engine.stop();
      }
      this.speakingMessageId = messageId;
      engine.speak(speechText, {
        requestId: this.createMessageId(`tts-${messageId}`)
      });
      this.statusText = '正在播报这条回复。';
    } catch (error) {
      this.speakingMessageId = '';
      this.statusText = `播报失败：${this.stringifyError(error)}`;
      this.showToast('播报失败，请确认设备支持语音播报');
    }
  }

  private async ensureSpeechEngine(): Promise<textToSpeech.TextToSpeechEngine> {
    if (this.ttsEngine !== null) {
      return this.ttsEngine;
    }

    let selectedVoice: textToSpeech.VoiceInfo | null = null;
    try {
      const voices: Array<textToSpeech.VoiceInfo> = await textToSpeech.listVoices({
        requestId: this.createMessageId('tts-voices'),
        online: 0
      });
      selectedVoice = this.selectPreferredVoice(voices);
    } catch (_error) {
      selectedVoice = null;
    }

    const engine: textToSpeech.TextToSpeechEngine = await textToSpeech.createEngine({
      language: selectedVoice !== null ? selectedVoice.language : 'zh-CN',
      person: selectedVoice !== null ? selectedVoice.person : 0,
      online: 0
    });

    const listener: textToSpeech.SpeakListener = {
      onStart: (_requestId: string, _response: textToSpeech.StartResponse): void => {
        this.statusText = '正在播报这条回复。';
      },
      onComplete: (_requestId: string, _response: textToSpeech.CompleteResponse): void => {
        this.speakingMessageId = '';
        this.statusText = '播报完成。';
      },
      onStop: (_requestId: string, _response: textToSpeech.StopResponse): void => {
        this.speakingMessageId = '';
        this.statusText = '已停止播报。';
      },
      onError: (_requestId: string, _errorCode: number, errorMessage: string): void => {
        this.speakingMessageId = '';
        this.statusText = `播报失败：${errorMessage}`;
        this.showToast('播报失败，请确认设备支持语音播报');
      }
    };
    engine.setListener(listener);
    this.ttsEngine = engine;
    return engine;
  }

  private selectPreferredVoice(voices: Array<textToSpeech.VoiceInfo>): textToSpeech.VoiceInfo | null {
    if (voices.length === 0) {
      return null;
    }

    for (let index: number = 0; index < voices.length; index++) {
      if (voices[index].language === 'zh-CN') {
        return voices[index];
      }
    }
    for (let index: number = 0; index < voices.length; index++) {
      if (voices[index].language.startsWith('zh')) {
        return voices[index];
      }
    }
    return voices[0];
  }

  private stopSpeakingMessage(showToast: boolean): void {
    if (this.ttsEngine !== null) {
      try {
        if (this.ttsEngine.isBusy()) {
          this.ttsEngine.stop();
        }
      } catch (_error) {
        // Ignore stop errors to avoid blocking chat interactions.
      }
    }
    this.speakingMessageId = '';
    if (showToast) {
      this.showToast('已停止播报');
    }
  }

  private shutdownSpeechEngine(): void {
    this.stopSpeakingMessage(false);
    if (this.ttsEngine === null) {
      return;
    }
    try {
      this.ttsEngine.shutdown();
    } catch (_error) {
      // Ignore speech engine shutdown errors during page destruction.
    }
    this.ttsEngine = null;
  }

  private buildSpeechText(content: string): string {
    return AgentTextUtils.buildSpeechText(content);
  }

  private showToast(message: string): void {
    promptAction.showToast({
      message: message,
      duration: 1800
    });
  }

  private createMessageId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
  }
}
