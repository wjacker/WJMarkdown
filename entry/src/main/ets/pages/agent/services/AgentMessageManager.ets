import { AgentAnswer, ChatMessage, ChatMessagePhase, MessageFeedback, MessageRole } from '../models/ChatModels';
import { AgentImageAttachment } from '../models/AgentAttachmentModels';
import { HiAgentConfig, HiAgentEventHelper, HiAgentHistoryMessage, HiAgentMessageAnswerInfo, HiAgentStreamEvent } from '../models/HiAgentModels';
import { HiAgentService, HiAgentStreamSession } from './HiAgentService';
import { AgentTextUtils } from '../utils/AgentTextUtils';
import { AgentAnswerHelper } from '../utils/AgentAnswerHelper';

export interface AgentMessageManagerHost {
  messages: Array<ChatMessage>;
  draft: string;
  attachments: Array<AgentImageAttachment>;
  conversationId: string;
  statusText: string;
  isSending: boolean;
  shouldAutoScrollToBottom: boolean;
  activeAssistantMessageId: string;
  activeStreamSession: HiAgentStreamSession | null;
  serviceConversationId: string;
  answersByMessageId: Map<string, Array<AgentAnswer>>;
  pendingConversationTitleByMessageId: Map<string, string>;
  messageScroller: Scroller;
  revealTimer: number;
  revealChunkSize: number;
  revealIntervalMs: number;
  activeRevealMessageId: string;
  speakingMessageId: string;

  buildConfig(): HiAgentConfig;
  createMessageId(prefix: string): string;
  stringifyError(error: Object): string;
  shortenId(value: string): string;
  showToast(message: string): void;
  upsertConversationItem(appConversationId: string, title?: string, preview?: string, updatedAt?: number,
    keepExistingTitle?: boolean, isPinned?: boolean): void;
  refreshConversationList(showErrorToast?: boolean): Promise<void>;
  scheduleConfigSave(): void;
  sanitizeConversationTitle(title: string, stripControlChars: boolean): string;
  stopSpeakingMessage(showToast: boolean): void;
}

export class AgentMessageManager {
  static buildGuideMessages(createMessageId: (prefix: string) => string): Array<ChatMessage> {
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
      createMessageId('guide'),
      guideMarkdown,
      guideMarkdown,
      false
    );
    guideMessage.streamCompleted = true;
    AgentMessageManager.syncMessageUiState(guideMessage);
    return [guideMessage];
  }

  static async sendPrompt(host: AgentMessageManagerHost): Promise<void> {
    const prompt: string = host.draft.trim();
    if (prompt.length === 0 && host.attachments.length === 0) {
      host.statusText = '先输入一个问题再发送。';
      return;
    }

    const config: HiAgentConfig = host.buildConfig();
    if (!config.isReady()) {
      host.statusText = '请先填写 Api URL、ApiKey 和 UserID。';
      return;
    }

    const needsCreateConversation: boolean = host.conversationId.trim().length === 0;
    const shouldUpdateEmptyConversationTitle: boolean = AgentMessageManager.isCurrentConversationEmpty(host);

    const nextMessages: Array<ChatMessage> = host.messages.slice();
    const userMessageParts: Array<string> = AgentMessageManager.composeUserVisibleParts(prompt, host.attachments);
    for (let index: number = 0; index < userMessageParts.length; index++) {
      const userMessage: ChatMessage = ChatMessage.user(
        host.createMessageId(`user-${index}`),
        userMessageParts[index]
      );
      userMessage.conversationId = host.conversationId;
      AgentMessageManager.syncMessageUiState(userMessage);
      nextMessages.push(userMessage);
    }

    const assistantMessageId: string = host.createMessageId('assistant');
    const assistantMessage: ChatMessage = ChatMessage.assistant(assistantMessageId, '', '', true);
    assistantMessage.conversationId = host.conversationId;
    assistantMessage.streamCompleted = false;
    AgentMessageManager.applyMessagePhase(assistantMessage, ChatMessagePhase.Sending, '发送中');
    AgentMessageManager.syncMessageUiState(assistantMessage);
    const initialVariants: Array<AgentAnswer> = [
      AgentMessageManager.createAnswerFromMessage(host, assistantMessage)
    ];
    AgentMessageManager.replaceAnswers(host, assistantMessage.id, initialVariants);
    AgentMessageManager.applyAnswerMeta(assistantMessage, initialVariants);
    nextMessages.push(assistantMessage);

    host.messages = nextMessages;
    host.activeAssistantMessageId = assistantMessageId;
    host.isSending = true;
    host.draft = '';
    host.attachments = [];
    host.statusText = host.conversationId.length > 0
      ? `会话 ${host.shortenId(host.conversationId)} 已连接，正在发送...`
      : '正在创建会话...';
    host.shouldAutoScrollToBottom = true;
    AgentMessageManager.scrollToBottom(host, true);
    AgentMessageManager.startRevealTimer(host, assistantMessageId);

    try {
      const appConversationId: string = await AgentMessageManager.ensureConversation(host, config);
      const sanitizedPromptTitle: string = host.sanitizeConversationTitle(prompt, true);
      host.upsertConversationItem(appConversationId, sanitizedPromptTitle, prompt, Date.now());
      if (shouldUpdateEmptyConversationTitle && sanitizedPromptTitle.length > 0) {
        host.pendingConversationTitleByMessageId.set(assistantMessageId, sanitizedPromptTitle);
      } else {
        host.pendingConversationTitleByMessageId.delete(assistantMessageId);
      }
      void host.refreshConversationList(false);
      AgentMessageManager.bindPendingMessagesToConversation(host, appConversationId, assistantMessageId);
      AgentMessageManager.updateAssistantPhase(host, assistantMessageId, ChatMessagePhase.Sending, '发送中', 'request_start');
      host.statusText = `会话 ${host.shortenId(appConversationId)} 已连接，正在等待模型响应...`;
      host.activeStreamSession = HiAgentService.startChatStream(
        config,
        appConversationId,
        prompt,
        (event: HiAgentStreamEvent) => {
          AgentMessageManager.handleStreamEvent(host, assistantMessageId, event);
        },
        () => {
          AgentMessageManager.completeAssistantMessage(host, assistantMessageId, '响应完成。');
        },
        (errorMessage: string) => {
          AgentMessageManager.failAssistantMessage(host, assistantMessageId, errorMessage);
        }
      );
    } catch (error) {
      const errorText: string = host.stringifyError(error as Object);
      if (needsCreateConversation) {
        AgentMessageManager.failAssistantMessage(host, assistantMessageId, `创建会话失败：${errorText}`);
      } else {
        AgentMessageManager.failAssistantMessage(host, assistantMessageId, errorText);
      }
    }
  }

  static async syncHistory(host: AgentMessageManagerHost): Promise<void> {
    if (host.isSending) {
      host.statusText = '当前仍在流式响应中，请先停止或等待完成。';
      return;
    }

    const config: HiAgentConfig = host.buildConfig();
    if (!config.isReady()) {
      host.statusText = '同步历史前请先填写 Api URL、ApiKey 和 UserID。';
      return;
    }
    if (host.conversationId.trim().length === 0) {
      host.statusText = '当前还没有会话，先发送一条消息创建会话。';
      return;
    }

    host.statusText = '正在同步会话历史...';
    try {
      const historyMessages: Array<HiAgentHistoryMessage> = await HiAgentService.getConversationMessages(
        config,
        host.conversationId,
        100
      );
      host.answersByMessageId.clear();
      host.messages = AgentMessageManager.buildHistoryMessages(host, historyMessages);
      if (historyMessages.length > 0) {
        const latestHistory: HiAgentHistoryMessage = historyMessages[historyMessages.length - 1];
        const previewText: string = latestHistory.query.trim().length > 0 ? latestHistory.query : latestHistory.answer;
        const titleText: string = latestHistory.query.trim().length > 0 ? latestHistory.query : previewText;
        host.upsertConversationItem(host.conversationId, titleText, previewText, latestHistory.createdTime * 1000);
      }
      host.statusText = historyMessages.length > 0
        ? `已同步 ${historyMessages.length} 条历史记录。`
        : '当前会话还没有历史消息。';
      host.shouldAutoScrollToBottom = true;
      AgentMessageManager.scrollToBottom(host, true);
    } catch (error) {
      host.statusText = `同步历史失败：${host.stringifyError(error as Object)}`;
    }
  }

  static async stopActiveResponse(host: AgentMessageManagerHost): Promise<void> {
    const session: HiAgentStreamSession | null = host.activeStreamSession;
    const localAssistantMessageId: string = host.activeAssistantMessageId;

    host.activeStreamSession = null;
    host.activeAssistantMessageId = '';
    host.isSending = false;

    if (session === null) {
      return;
    }

    try {
      const config: HiAgentConfig = host.buildConfig();
      if (config.isReady()) {
        await HiAgentService.stopMessage(config, session.messageId, session.taskId);
      }
      host.statusText = '已停止当前回复。';
    } catch (error) {
      host.statusText = `停止请求失败：${host.stringifyError(error as Object)}`;
    } finally {
      session.close();
      AgentMessageManager.markAssistantStopped(host, localAssistantMessageId);
    }
  }

  static startRevealTimer(host: AgentMessageManagerHost, messageId: string): void {
    if (host.activeRevealMessageId === messageId && host.revealTimer >= 0) {
      return;
    }
    AgentMessageManager.stopRevealTimer(host);
    host.activeRevealMessageId = messageId;
    host.revealTimer = setInterval(() => {
      const messageIndex: number = AgentMessageManager.findMessageIndex(host, host.activeRevealMessageId);
      if (messageIndex < 0) {
        AgentMessageManager.stopRevealTimer(host);
        return;
      }

      const message: ChatMessage = host.messages[messageIndex];
      if (message.visibleContent.length < message.rawContent.length) {
        const nextMessage: ChatMessage = message.copy();
        const nextLength: number = Math.min(message.rawContent.length, message.visibleContent.length + host.revealChunkSize);
        nextMessage.visibleContent = message.rawContent.substring(0, nextLength);
        nextMessage.isStreaming = true;
        AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
        AgentMessageManager.scrollToBottom(host);
        return;
      }

      if (message.streamCompleted) {
        if (message.isStreaming) {
          const nextMessage: ChatMessage = message.copy();
          nextMessage.isStreaming = false;
          AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
        }
        AgentMessageManager.stopRevealTimer(host);
      }
    }, host.revealIntervalMs) as number;
  }

  private static composeUserVisibleParts(prompt: string, attachments: Array<AgentImageAttachment>): Array<string> {
    const parts: Array<string> = [];
    for (let index: number = 0; index < attachments.length; index++) {
      const attachment: AgentImageAttachment = attachments[index];
      parts.push(`![${attachment.name}](${attachment.fileUri})`);
    }
    if (prompt.length > 0) {
      parts.push(prompt);
    }
    return parts;
  }

  static stopRevealTimer(host: AgentMessageManagerHost): void {
    if (host.revealTimer >= 0) {
      clearInterval(host.revealTimer);
      host.revealTimer = -1;
    }
    host.activeRevealMessageId = '';
  }

  static scrollToBottom(host: AgentMessageManagerHost, force: boolean = false): void {
    if (!force && !host.shouldAutoScrollToBottom) {
      return;
    }
    setTimeout(() => {
      host.messageScroller.scrollEdge(Edge.Bottom);
    }, 30);
  }

  static safeIsAtEnd(host: AgentMessageManagerHost): boolean {
    try {
      return host.messageScroller.isAtEnd();
    } catch (_error) {
      return host.shouldAutoScrollToBottom;
    }
  }

  static getMessageById(host: AgentMessageManagerHost, messageId: string): ChatMessage | null {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, messageId);
    if (messageIndex < 0) {
      return null;
    }
    return host.messages[messageIndex];
  }

  static buildHistoryMessages(host: AgentMessageManagerHost, historyMessages: Array<HiAgentHistoryMessage>): Array<ChatMessage> {
    if (historyMessages.length === 0) {
      return AgentMessageManager.buildGuideMessages((prefix: string): string => host.createMessageId(prefix));
    }

    const nextMessages: Array<ChatMessage> = [];
    for (let index: number = 0; index < historyMessages.length; index++) {
      const historyMessage: HiAgentHistoryMessage = historyMessages[index];
      const userMessageParts: Array<string> = AgentMessageManager.resolveHistoryUserMessageParts(historyMessage);
      for (let userIndex: number = 0; userIndex < userMessageParts.length; userIndex++) {
        const userMessage: ChatMessage = ChatMessage.user(
          host.createMessageId(`history-user-${index}-${userIndex}`),
          userMessageParts[userIndex]
        );
        userMessage.conversationId = host.conversationId;
        userMessage.createdAt = historyMessage.createdTime * 1000;
        AgentMessageManager.syncMessageUiState(userMessage);
        nextMessages.push(userMessage);
      }

      if (historyMessage.answer.trim().length > 0) {
        const assistantMessage: ChatMessage = ChatMessage.assistant(
          host.createMessageId(`history-assistant-${index}`),
          historyMessage.answer,
          historyMessage.answer,
          false
        );
        assistantMessage.streamCompleted = true;
        assistantMessage.conversationId = host.conversationId;
        assistantMessage.queryId = historyMessage.queryId;
        assistantMessage.serviceMessageId = historyMessage.messageId;
        assistantMessage.taskId = historyMessage.taskId;
        assistantMessage.createdAt = historyMessage.createdTime * 1000;
        const variants: Array<AgentAnswer> = AgentMessageManager.buildAnswersFromHistoryMessage(host, historyMessage);
        AgentMessageManager.replaceAnswers(host, assistantMessage.id, variants);
        AgentMessageManager.applyAnswerMeta(assistantMessage, variants);
        assistantMessage.answerCount = variants.length;
        assistantMessage.activeAnswerIndex = variants.length > 0 ? variants.length - 1 : 0;
        AgentMessageManager.applyActiveAnswerToMessage(host, assistantMessage);
        AgentMessageManager.syncMessageUiState(assistantMessage);
        nextMessages.push(assistantMessage);
      }
    }
    return nextMessages;
  }

  static handleStreamEvent(host: AgentMessageManagerHost, localMessageId: string, event: HiAgentStreamEvent): void {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = host.messages[messageIndex].copy();
    const normalizedEventName: string = HiAgentEventHelper.normalizeEventName(event.event);
    if (event.conversationId.length > 0) {
      host.serviceConversationId = event.conversationId;
    }
    if (nextMessage.conversationId.length === 0 && host.conversationId.length > 0) {
      nextMessage.conversationId = host.conversationId;
    }
    if (event.taskId.length > 0) {
      nextMessage.taskId = event.taskId;
    }
    nextMessage.serviceMessageId = AgentMessageManager.resolveServiceMessageId(nextMessage, event, normalizedEventName);
    if (normalizedEventName.length > 0) {
      nextMessage.lastEvent = normalizedEventName;
    }

    if (AgentMessageManager.isKeepAliveEvent(normalizedEventName)) {
      return;
    }

    if (AgentMessageManager.shouldAppendAnswer(normalizedEventName, event)) {
      nextMessage.rawContent = AgentMessageManager.mergeStreamAnswer(
        nextMessage.rawContent,
        event.answer,
        normalizedEventName === 'message_replace'
      );
    }

    if (HiAgentEventHelper.isErrorEvent(normalizedEventName, event.status)) {
      AgentMessageManager.failAssistantMessage(host, localMessageId, HiAgentEventHelper.extractEventErrorMessage(event));
      return;
    }

    const phase: ChatMessagePhase = AgentMessageManager.resolveStreamPhase(nextMessage, event, normalizedEventName);
    const phaseLabel: string = AgentMessageManager.resolvePhaseLabel(phase, event, normalizedEventName, nextMessage.statusLabel);
    AgentMessageManager.applyMessagePhase(nextMessage, phase, phaseLabel, normalizedEventName);
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

    AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
    host.statusText = AgentMessageManager.resolveStatusTextByPhase(host, phase, phaseLabel);
    AgentMessageManager.scrollToBottom(host);

    if (phase === ChatMessagePhase.Finished || phase === ChatMessagePhase.Stopped) {
      AgentMessageManager.finishSending(host, AgentMessageManager.resolveStatusTextByPhase(host, phase, phaseLabel));
    }
  }

  static closeActiveSession(host: AgentMessageManagerHost): void {
    if (host.activeStreamSession !== null) {
      host.activeStreamSession.close();
      host.activeStreamSession = null;
    }
    host.activeAssistantMessageId = '';
  }

  static async queryAgainAssistantMessage(host: AgentMessageManagerHost, messageId: string): Promise<void> {
    if (host.isSending) {
      host.showToast('当前已有回复在生成，请稍后再试');
      return;
    }

    const messageIndex: number = AgentMessageManager.findMessageIndex(host, messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = host.buildConfig();
    if (!config.isReady()) {
      host.showToast('请先填写接口配置');
      return;
    }

    const pairedUserMessageStartIndex: number = AgentMessageManager.findPairedUserMessageStartIndex(host, messageIndex);
    const pairedUserMessages: Array<ChatMessage> = [];
    if (pairedUserMessageStartIndex >= 0) {
      for (let index: number = pairedUserMessageStartIndex; index < messageIndex; index++) {
        pairedUserMessages.push(host.messages[index].copy());
      }
    }
    const sourceMessage: ChatMessage = host.messages[messageIndex].copy();
    const existingVersions: Array<AgentAnswer> = AgentMessageManager.ensureAnswers(host, sourceMessage);
    if (existingVersions.length > 0) {
      AgentMessageManager.syncMessageToActiveAnswer(host, sourceMessage);
    }
    if (existingVersions.length >= 10) {
      host.showToast('最多只支持10次生成哦~');
      return;
    }

    const activeVersion: AgentAnswer | null = AgentMessageManager.getActiveAnswer(host, sourceMessage);
    if (activeVersion === null || activeVersion.serviceMessageId.trim().length === 0) {
      host.showToast('当前回复还没有可重新回答的 messageId');
      return;
    }
    const appConversationId: string = sourceMessage.conversationId.trim().length > 0 ? sourceMessage.conversationId : host.conversationId;
    if (appConversationId.trim().length === 0) {
      host.showToast('当前还没有有效的会话 ID');
      return;
    }
    host.upsertConversationItem(appConversationId, '', sourceMessage.rawContent, Date.now());

    const regeneratedAssistantMessageId: string = host.createMessageId('assistant');
    const nextVersions: Array<AgentAnswer> = AgentMessageManager.cloneAnswers(host, messageId);
    const pendingVersion: AgentAnswer = AgentMessageManager.buildPendingAnswerForRetry(host, regeneratedAssistantMessageId);
    pendingVersion.serviceMessageId = activeVersion.serviceMessageId;
    pendingVersion.taskId = activeVersion.taskId;
    nextVersions.push(pendingVersion);
    host.answersByMessageId.delete(messageId);
    AgentMessageManager.replaceAnswers(host, regeneratedAssistantMessageId, nextVersions);

    sourceMessage.activeAnswerIndex = nextVersions.length - 1;
    sourceMessage.id = regeneratedAssistantMessageId;
    AgentMessageManager.applyActiveAnswerToMessage(host, sourceMessage);
    sourceMessage.conversationId = appConversationId;
    sourceMessage.queryId = '';
    sourceMessage.serviceMessageId = activeVersion.serviceMessageId;
    sourceMessage.taskId = activeVersion.taskId;
    sourceMessage.rawContent = '';
    sourceMessage.visibleContent = '';
    sourceMessage.feedback = MessageFeedback.None;
    sourceMessage.createdAt = pendingVersion.createdAt;
    AgentMessageManager.syncMessageUiState(sourceMessage);

    const nextMessages: Array<ChatMessage> = host.messages.slice();
    nextMessages.splice(messageIndex, 1);
    if (pairedUserMessageStartIndex >= 0) {
      nextMessages.splice(pairedUserMessageStartIndex, messageIndex - pairedUserMessageStartIndex);
    }
    for (let index: number = 0; index < pairedUserMessages.length; index++) {
      const pairedUserMessage: ChatMessage = pairedUserMessages[index];
      pairedUserMessage.id = host.createMessageId(`user-${index}`);
      AgentMessageManager.syncMessageUiState(pairedUserMessage);
      nextMessages.push(pairedUserMessage);
    }
    nextMessages.push(sourceMessage);
    host.messages = nextMessages;
    host.activeAssistantMessageId = regeneratedAssistantMessageId;
    host.isSending = true;
    host.statusText = '正在重新回答这条回复...';
    AgentMessageManager.startRevealTimer(host, regeneratedAssistantMessageId);
    AgentMessageManager.scrollToBottom(host, true);

    host.activeStreamSession = HiAgentService.startQueryAgainStream(
      config,
      appConversationId,
      activeVersion.serviceMessageId,
      (event: HiAgentStreamEvent) => {
        AgentMessageManager.handleStreamEvent(host, regeneratedAssistantMessageId, event);
      },
      () => {
        AgentMessageManager.completeAssistantMessage(host, regeneratedAssistantMessageId, '重新回答完成。');
      },
      (errorMessage: string) => {
        AgentMessageManager.failAssistantMessage(host, regeneratedAssistantMessageId, errorMessage);
      }
    );
  }

  static async deleteAssistantMessage(host: AgentMessageManagerHost, messageId: string): Promise<void> {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = host.buildConfig();
    if (!config.isReady()) {
      host.showToast('请先填写接口配置');
      return;
    }

    const hydratedMessage: ChatMessage = host.messages[messageIndex].copy();
    AgentMessageManager.applyActiveAnswerToMessage(host, hydratedMessage);
    const activeVersion: AgentAnswer | null = AgentMessageManager.getActiveAnswer(host, hydratedMessage);
    if (activeVersion === null || activeVersion.serviceMessageId.trim().length === 0) {
      host.showToast('当前回复缺少删除所需的 messageId');
      return;
    }

    try {
      await HiAgentService.deleteMessage(config, activeVersion.serviceMessageId);
      if (host.speakingMessageId === messageId) {
        host.stopSpeakingMessage(false);
      }

      const nextVersions: Array<AgentAnswer> = AgentMessageManager.cloneAnswers(host, messageId);
      nextVersions.splice(hydratedMessage.activeAnswerIndex, 1);
      if (nextVersions.length === 0) {
        host.answersByMessageId.delete(messageId);
        const nextMessages: Array<ChatMessage> = host.messages.slice();
        const pairedUserMessageStartIndex: number = AgentMessageManager.findPairedUserMessageStartIndex(host, messageIndex);
        nextMessages.splice(messageIndex, 1);
        if (pairedUserMessageStartIndex >= 0) {
          nextMessages.splice(pairedUserMessageStartIndex, messageIndex - pairedUserMessageStartIndex);
        }
        host.messages = nextMessages;
        host.statusText = pairedUserMessageStartIndex >= 0 ? '已删除当前问答。' : '已删除当前回复。';
      } else {
        const fallbackIndex: number = Math.min(hydratedMessage.activeAnswerIndex, nextVersions.length - 1);
        AgentMessageManager.replaceAnswers(host, messageId, nextVersions);
        const nextMessage: ChatMessage = hydratedMessage.copy();
        nextMessage.activeAnswerIndex = fallbackIndex;
        AgentMessageManager.applyActiveAnswerToMessage(host, nextMessage);
        AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
        host.statusText = '已删除当前回复。';
      }
    } catch (error) {
      const errorMessage: string = host.stringifyError(error as Object);
      host.statusText = `删除失败：${errorMessage}`;
      host.showToast(errorMessage);
    }
  }

  static async toggleFeedback(host: AgentMessageManagerHost, messageId: string, nextFeedback: MessageFeedback): Promise<void> {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, messageId);
    if (messageIndex < 0) {
      return;
    }

    const config: HiAgentConfig = host.buildConfig();
    if (!config.isReady()) {
      host.showToast('请先填写接口配置');
      return;
    }

    const nextMessage: ChatMessage = host.messages[messageIndex].copy();
    const activeVersion: AgentAnswer | null = AgentMessageManager.getActiveAnswer(host, nextMessage);
    if (activeVersion === null || activeVersion.serviceMessageId.trim().length === 0) {
      host.showToast('当前回复还没有可反馈的 messageId');
      return;
    }

    const targetFeedback: MessageFeedback = nextMessage.feedback === nextFeedback ? MessageFeedback.None : nextFeedback;
    try {
      await HiAgentService.feedback(config, activeVersion.serviceMessageId, AgentAnswerHelper.toLikeType(targetFeedback));
      nextMessage.feedback = targetFeedback;
      AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);

      if (targetFeedback === MessageFeedback.Like) {
        host.showToast('已点赞这条回复');
        return;
      }
      if (targetFeedback === MessageFeedback.Dislike) {
        host.showToast('已点踩这条回复');
        return;
      }
      host.showToast('已取消反馈');
    } catch (error) {
      host.statusText = `反馈失败：${host.stringifyError(error as Object)}`;
      host.showToast('反馈设置失败');
    }
  }

  static async switchAnswer(host: AgentMessageManagerHost, messageId: string, offset: number): Promise<void> {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, messageId);
    if (messageIndex < 0) {
      return;
    }

    const hydratedMessage: ChatMessage = host.messages[messageIndex].copy();
    const variants: Array<AgentAnswer> = AgentMessageManager.cloneAnswers(host, messageId);
    if (variants.length <= 1) {
      host.showToast('当前只有一个回复版本');
      return;
    }

    const nextIndex: number = hydratedMessage.activeAnswerIndex + offset;
    if (nextIndex < 0 || nextIndex >= variants.length) {
      return;
    }

    const optimisticMessage: ChatMessage = hydratedMessage.copy();
    optimisticMessage.activeAnswerIndex = nextIndex;
    optimisticMessage.answerCount = variants.length;
    AgentMessageManager.applyActiveAnswerToMessage(host, optimisticMessage);
    AgentMessageManager.applyMessageToList(host, messageIndex, optimisticMessage);
    host.statusText = `已切换到第 ${nextIndex + 1}/${variants.length} 个回复。`;
  }

  private static isCurrentConversationEmpty(host: AgentMessageManagerHost): boolean {
    for (let index: number = 0; index < host.messages.length; index++) {
      const message: ChatMessage = host.messages[index];
      if (message.role === MessageRole.User || message.role === MessageRole.Assistant) {
        if (message.rawContent.trim().length > 0 || message.visibleContent.trim().length > 0) {
          return false;
        }
      }
    }
    return true;
  }

  private static findMessageIndex(host: AgentMessageManagerHost, messageId: string): number {
    for (let index: number = 0; index < host.messages.length; index++) {
      if (host.messages[index].id === messageId) {
        return index;
      }
    }
    return -1;
  }

  private static ensureAnswers(host: AgentMessageManagerHost, message: ChatMessage): Array<AgentAnswer> {
    const existingVersions: Array<AgentAnswer> | undefined = host.answersByMessageId.get(message.id);
    if (existingVersions !== undefined) {
      AgentMessageManager.applyAnswerMeta(message, existingVersions);
      return existingVersions;
    }

    if (message.role !== MessageRole.Assistant) {
      return [];
    }

    const variants: Array<AgentAnswer> = [AgentMessageManager.createAnswerFromMessage(host, message)];
    host.answersByMessageId.set(message.id, variants);
    AgentMessageManager.applyAnswerMeta(message, variants);
    return variants;
  }

  private static createAnswerFromMessage(host: AgentMessageManagerHost, message: ChatMessage): AgentAnswer {
    return AgentAnswerHelper.createAnswerFromMessage(
      message,
      host.createMessageId(`variant-${message.id}`)
    );
  }

  private static applyAnswerMeta(message: ChatMessage, variants: Array<AgentAnswer>): void {
    AgentAnswerHelper.applyAnswerMeta(message, variants);
  }

  private static syncMessageToActiveAnswer(host: AgentMessageManagerHost, message: ChatMessage): void {
    if (message.role !== MessageRole.Assistant) {
      return;
    }

    const variants: Array<AgentAnswer> = AgentMessageManager.ensureAnswers(host, message);
    if (variants.length === 0) {
      return;
    }

    const activeVersion: AgentAnswer = variants[message.activeAnswerIndex];
    AgentAnswerHelper.syncMessageToAnswer(message, activeVersion);
  }

  private static applyActiveAnswerToMessage(host: AgentMessageManagerHost, message: ChatMessage): void {
    if (message.role !== MessageRole.Assistant) {
      return;
    }

    const variants: Array<AgentAnswer> = AgentMessageManager.ensureAnswers(host, message);
    if (variants.length === 0) {
      return;
    }

    const activeVersion: AgentAnswer = variants[message.activeAnswerIndex];
    AgentAnswerHelper.applyAnswerToMessage(message, activeVersion);
  }

  private static replaceAnswers(host: AgentMessageManagerHost, messageId: string, variants: Array<AgentAnswer>): void {
    host.answersByMessageId.set(messageId, variants);
  }

  private static syncMessageUiState(message: ChatMessage): void {
    if (message.role !== MessageRole.Assistant) {
      message.showActions = false;
      return;
    }
    message.showActions = message.visibleContent.trim().length > 0 && !message.isStreaming;
  }

  private static patchMessage(target: ChatMessage, source: ChatMessage): void {
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
    target.answerCount = source.answerCount;
    target.activeAnswerIndex = source.activeAnswerIndex;
    target.showActions = source.showActions;
  }

  private static getActiveAnswer(host: AgentMessageManagerHost, message: ChatMessage): AgentAnswer | null {
    const variants: Array<AgentAnswer> = AgentMessageManager.ensureAnswers(host, message);
    if (variants.length === 0) {
      return null;
    }
    return variants[message.activeAnswerIndex];
  }

  private static cloneAnswers(host: AgentMessageManagerHost, messageId: string): Array<AgentAnswer> {
    const variants: Array<AgentAnswer> | undefined = host.answersByMessageId.get(messageId);
    if (variants === undefined) {
      return [];
    }
    const nextVersions: Array<AgentAnswer> = [];
    for (let index: number = 0; index < variants.length; index++) {
      nextVersions.push(variants[index].copy());
    }
    return nextVersions;
  }

  private static buildPendingAnswerForRetry(host: AgentMessageManagerHost, localMessageId: string): AgentAnswer {
    return AgentAnswerHelper.buildPendingAnswerForRetry(localMessageId, (prefix: string): string => {
      return host.createMessageId(prefix);
    });
  }

  private static applyMessageToList(host: AgentMessageManagerHost, messageIndex: number, nextMessage: ChatMessage): void {
    AgentMessageManager.syncMessageToActiveAnswer(host, nextMessage);
    AgentMessageManager.syncMessageUiState(nextMessage);
    AgentMessageManager.patchMessage(host.messages[messageIndex], nextMessage);
    host.messages = host.messages.slice();
  }

  private static findPairedUserMessageStartIndex(host: AgentMessageManagerHost, assistantMessageIndex: number): number {
    if (assistantMessageIndex <= 0 || assistantMessageIndex >= host.messages.length) {
      return -1;
    }

    let pairedUserMessageStartIndex: number = -1;
    for (let index: number = assistantMessageIndex - 1; index >= 0; index--) {
      const candidate: ChatMessage = host.messages[index];
      if (candidate.role === MessageRole.User) {
        pairedUserMessageStartIndex = index;
        continue;
      }
      if (candidate.role === MessageRole.Assistant) {
        break;
      }
    }
    return pairedUserMessageStartIndex;
  }

  private static resolveHistoryUserMessageParts(historyMessage: HiAgentHistoryMessage): Array<string> {
    if (historyMessage.userMessageParts.length > 0) {
      return historyMessage.userMessageParts;
    }
    if (historyMessage.userMessageContent.trim().length > 0) {
      return [historyMessage.userMessageContent];
    }
    if (historyMessage.query.trim().length > 0) {
      return [historyMessage.query];
    }
    return [];
  }

  private static buildAnswersFromHistoryMessage(host: AgentMessageManagerHost, historyMessage: HiAgentHistoryMessage): Array<AgentAnswer> {
    const variants: Array<AgentAnswer> = [];
    for (let index: number = 0; index < historyMessage.otherAnswers.length; index++) {
      variants.push(AgentMessageManager.buildAnswerFromAnswerInfo(host, historyMessage.otherAnswers[index]));
    }
    variants.sort((left: AgentAnswer, right: AgentAnswer) => left.createdAt - right.createdAt);

    if (historyMessage.answerInfo.messageId.trim().length > 0 || historyMessage.answerInfo.answer.trim().length > 0) {
      variants.push(AgentMessageManager.buildAnswerFromAnswerInfo(host, historyMessage.answerInfo));
    } else if (historyMessage.answer.trim().length > 0) {
      const fallbackAnswerInfo: HiAgentMessageAnswerInfo = new HiAgentMessageAnswerInfo(
        historyMessage.answer,
        historyMessage.messageId,
        historyMessage.createdTime,
        historyMessage.taskId
      );
      variants.push(AgentMessageManager.buildAnswerFromAnswerInfo(host, fallbackAnswerInfo));
    }
    return variants;
  }

  private static async ensureConversation(host: AgentMessageManagerHost, config: HiAgentConfig): Promise<string> {
    if (host.conversationId.trim().length > 0) {
      return host.conversationId.trim();
    }

    const conversation = await HiAgentService.createConversation(config);
    host.conversationId = conversation.appConversationId;
    host.upsertConversationItem(conversation.appConversationId, conversation.conversationName, '', Date.now());
    void host.refreshConversationList(false);
    host.scheduleConfigSave();
    return conversation.appConversationId;
  }

  private static completeAssistantMessage(host: AgentMessageManagerHost, localMessageId: string, statusText: string): void {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, localMessageId);
    if (messageIndex >= 0) {
      const nextMessage: ChatMessage = host.messages[messageIndex].copy();
      AgentMessageManager.applyMessagePhase(nextMessage, ChatMessagePhase.Finished, '已结束', nextMessage.lastEvent);
      nextMessage.streamCompleted = true;
      nextMessage.visibleContent = nextMessage.rawContent;
      nextMessage.isStreaming = false;
      AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
    }
    void AgentMessageManager.applyPendingConversationTitle(host, localMessageId);
    AgentMessageManager.finishSending(host, statusText);
  }

  private static failAssistantMessage(host: AgentMessageManagerHost, localMessageId: string, errorMessage: string): void {
    host.pendingConversationTitleByMessageId.delete(localMessageId);
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, localMessageId);
    if (messageIndex >= 0) {
      const nextMessage: ChatMessage = host.messages[messageIndex].copy();
      if (nextMessage.rawContent.trim().length === 0) {
        nextMessage.rawContent = '接口请求失败，请稍后重试。';
        nextMessage.visibleContent = '';
      }
      AgentMessageManager.applyMessagePhase(nextMessage, ChatMessagePhase.Error, '出错', 'error');
      nextMessage.streamCompleted = true;
      nextMessage.isStreaming = true;
      AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
      AgentMessageManager.startRevealTimer(host, localMessageId);
    }
    AgentMessageManager.finishSending(host, `请求失败：${errorMessage}`);
  }

  private static markAssistantStopped(host: AgentMessageManagerHost, localMessageId: string): void {
    host.pendingConversationTitleByMessageId.delete(localMessageId);
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = host.messages[messageIndex].copy();
    if (nextMessage.rawContent.trim().length === 0) {
      nextMessage.rawContent = '响应生成已停止~';
      nextMessage.visibleContent = '';
    }
    AgentMessageManager.applyMessagePhase(nextMessage, ChatMessagePhase.Stopped, '已停止', 'stopped');
    nextMessage.streamCompleted = true;
    nextMessage.isStreaming = true;
    AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
    AgentMessageManager.startRevealTimer(host, localMessageId);
  }

  private static finishSending(host: AgentMessageManagerHost, statusText: string): void {
    const localAssistantMessageId: string = host.activeAssistantMessageId;
    if (localAssistantMessageId.length > 0) {
      const messageIndex: number = AgentMessageManager.findMessageIndex(host, localAssistantMessageId);
      if (messageIndex >= 0) {
        const nextMessage: ChatMessage = host.messages[messageIndex].copy();
        if (nextMessage.rawContent.length > 0) {
          nextMessage.visibleContent = nextMessage.rawContent;
        }
        nextMessage.isStreaming = false;
        if (nextMessage.streamPhase !== ChatMessagePhase.Error && nextMessage.streamPhase !== ChatMessagePhase.Stopped) {
          nextMessage.streamCompleted = true;
        }
        AgentMessageManager.syncMessageUiState(nextMessage);
        AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
      }
      void AgentMessageManager.applyPendingConversationTitle(host, localAssistantMessageId);
    }
    if (host.activeStreamSession !== null) {
      host.activeStreamSession.close();
    }
    host.activeStreamSession = null;
    host.activeAssistantMessageId = '';
    host.isSending = false;
    host.statusText = statusText;
  }

  private static async applyPendingConversationTitle(host: AgentMessageManagerHost, localMessageId: string): Promise<void> {
    const pendingTitle: string | undefined = host.pendingConversationTitleByMessageId.get(localMessageId);
    if (pendingTitle === undefined || pendingTitle.trim().length === 0) {
      return;
    }
    host.pendingConversationTitleByMessageId.delete(localMessageId);
    const message: ChatMessage | null = AgentMessageManager.getMessageById(host, localMessageId);
    if (message === null) {
      return;
    }
    const appConversationId: string = message.conversationId.trim().length > 0 ? message.conversationId.trim() : host.conversationId.trim();
    if (appConversationId.length === 0) {
      return;
    }

    host.upsertConversationItem(appConversationId, pendingTitle, '', Date.now(), true);
    const config: HiAgentConfig = host.buildConfig();
    if (!config.isReady()) {
      return;
    }
    try {
      await HiAgentService.updateConversation(config, appConversationId, pendingTitle);
    } catch (_error) {
    }
  }

  private static bindPendingMessagesToConversation(host: AgentMessageManagerHost, appConversationId: string,
    assistantMessageId: string): void {
    if (appConversationId.trim().length === 0) {
      return;
    }

    let assistantBound: boolean = false;
    let userBound: boolean = false;
    for (let index: number = host.messages.length - 1; index >= 0; index--) {
      const nextMessage: ChatMessage = host.messages[index];
      if (!assistantBound && nextMessage.id === assistantMessageId) {
        nextMessage.conversationId = appConversationId;
        assistantBound = true;
        continue;
      }

      if (!userBound && nextMessage.role === MessageRole.User && nextMessage.conversationId.trim().length === 0) {
        nextMessage.conversationId = appConversationId;
        userBound = true;
      }

      if (assistantBound && userBound) {
        break;
      }
    }
    host.messages = host.messages.slice();
  }

  private static applyMessagePhase(message: ChatMessage, phase: ChatMessagePhase, label: string, eventName: string = ''): void {
    message.streamPhase = phase;
    message.statusLabel = label;
    if (eventName.length > 0) {
      message.lastEvent = eventName;
    }
  }

  private static updateAssistantPhase(host: AgentMessageManagerHost, localMessageId: string, phase: ChatMessagePhase,
    label: string, eventName: string = ''): void {
    const messageIndex: number = AgentMessageManager.findMessageIndex(host, localMessageId);
    if (messageIndex < 0) {
      return;
    }

    const nextMessage: ChatMessage = host.messages[messageIndex].copy();
    AgentMessageManager.applyMessagePhase(nextMessage, phase, label, eventName);
    AgentMessageManager.applyMessageToList(host, messageIndex, nextMessage);
  }

  private static resolveStreamPhase(message: ChatMessage, event: HiAgentStreamEvent, eventName: string): ChatMessagePhase {
    if (HiAgentEventHelper.isStoppedEvent(eventName)) {
      return ChatMessagePhase.Stopped;
    }
    if (AgentMessageManager.isTerminalEvent(eventName, event.status)) {
      return ChatMessagePhase.Finished;
    }
    if (AgentMessageManager.isAnsweringEvent(eventName, event)) {
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

  private static resolvePhaseLabel(phase: ChatMessagePhase, event: HiAgentStreamEvent, eventName: string,
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

  private static resolveStatusTextByPhase(host: AgentMessageManagerHost, phase: ChatMessagePhase, phaseLabel: string): string {
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
    return host.statusText;
  }

  private static shouldAppendAnswer(eventName: string, event: HiAgentStreamEvent): boolean {
    const normalizedAnswer: string = AgentTextUtils.normalizeStreamText(event.answer);
    if (normalizedAnswer.length === 0) {
      return false;
    }
    return eventName === 'message' || eventName === 'message_replace' || eventName.length === 0;
  }

  private static isAnsweringEvent(eventName: string, event: HiAgentStreamEvent): boolean {
    return eventName === 'message_output_start' ||
      eventName === 'message' ||
      eventName === 'message_replace' ||
      eventName === 'message_output_end' ||
      (eventName.length === 0 && AgentTextUtils.normalizeStreamText(event.answer).length > 0);
  }

  private static isKeepAliveEvent(eventName: string): boolean {
    return eventName === 'ping' || eventName === 'keepalive' || eventName === 'keep_alive';
  }

  private static isTerminalEvent(eventName: string, status: string): boolean {
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

  private static resolveServiceMessageId(message: ChatMessage, event: HiAgentStreamEvent, eventName: string): string {
    if (HiAgentEventHelper.isRootMessageEvent(eventName) && event.messageId.trim().length > 0) {
      return event.messageId.trim();
    }
    return message.serviceMessageId;
  }

  private static mergeStreamAnswer(currentContent: string, incomingContent: string, replaceAll: boolean = false): string {
    return AgentTextUtils.mergeStreamAnswer(currentContent, incomingContent, replaceAll);
  }

  private static buildAnswerFromAnswerInfo(host: AgentMessageManagerHost, answerInfo: HiAgentMessageAnswerInfo): AgentAnswer {
    return AgentAnswerHelper.buildAnswerFromAnswerInfo(answerInfo, (prefix: string): string => {
      return host.createMessageId(prefix);
    });
  }
}
