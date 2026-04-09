import { ChatAnswerVariant, ChatMessage, ChatMessagePhase, MessageFeedback } from '../models/ChatModels';
import { HiAgentMessageAnswerInfo } from '../models/HiAgentModels';

export class AgentVariantHelper {
  static createAnswerVariantFromMessage(message: ChatMessage, fallbackId: string): ChatAnswerVariant {
    const variant: ChatAnswerVariant = new ChatAnswerVariant(
      message.serviceMessageId.length > 0 ? message.serviceMessageId : fallbackId,
      message.rawContent,
      message.visibleContent
    );
    variant.serviceMessageId = message.serviceMessageId;
    variant.taskId = message.taskId;
    variant.createdAt = message.createdAt;
    variant.feedback = message.feedback;
    variant.isStreaming = message.isStreaming;
    variant.streamCompleted = message.streamCompleted;
    variant.streamPhase = message.streamPhase;
    variant.statusLabel = message.statusLabel;
    variant.lastEvent = message.lastEvent;
    return variant;
  }

  static applyAnswerVariantMeta(message: ChatMessage, variants: Array<ChatAnswerVariant>): void {
    message.answerVersionCount = variants.length;
    if (variants.length === 0) {
      message.activeAnswerVersionIndex = 0;
      return;
    }
    if (message.activeAnswerVersionIndex < 0) {
      message.activeAnswerVersionIndex = 0;
    }
    if (message.activeAnswerVersionIndex >= variants.length) {
      message.activeAnswerVersionIndex = variants.length - 1;
    }
  }

  static syncMessageToVariant(message: ChatMessage, variant: ChatAnswerVariant): void {
    variant.rawContent = message.rawContent;
    variant.visibleContent = message.visibleContent;
    variant.serviceMessageId = message.serviceMessageId;
    variant.taskId = message.taskId;
    variant.createdAt = message.createdAt;
    variant.feedback = message.feedback;
    variant.isStreaming = message.isStreaming;
    variant.streamCompleted = message.streamCompleted;
    variant.streamPhase = message.streamPhase;
    variant.statusLabel = message.statusLabel;
    variant.lastEvent = message.lastEvent;
  }

  static applyVariantToMessage(message: ChatMessage, variant: ChatAnswerVariant): void {
    message.rawContent = variant.rawContent;
    message.visibleContent = variant.visibleContent;
    message.serviceMessageId = variant.serviceMessageId;
    message.taskId = variant.taskId;
    message.createdAt = variant.createdAt;
    message.feedback = variant.feedback;
    message.isStreaming = variant.isStreaming;
    message.streamCompleted = variant.streamCompleted;
    message.streamPhase = variant.streamPhase;
    message.statusLabel = variant.statusLabel;
    message.lastEvent = variant.lastEvent;
  }

  static buildVariantMergeKey(variant: ChatAnswerVariant): string {
    if (variant.serviceMessageId.trim().length > 0) {
      return `id:${variant.serviceMessageId.trim()}`;
    }
    const rawKey: string = variant.rawContent.trim();
    if (rawKey.length > 0) {
      return `raw:${rawKey}`;
    }
    return `local:${variant.id}`;
  }

  static buildPendingQueryAgainVariant(localMessageId: string, createMessageId: (prefix: string) => string): ChatAnswerVariant {
    const pendingVariant: ChatAnswerVariant = new ChatAnswerVariant(createMessageId(`variant-${localMessageId}`));
    pendingVariant.createdAt = Date.now();
    pendingVariant.isStreaming = true;
    pendingVariant.streamCompleted = false;
    pendingVariant.streamPhase = ChatMessagePhase.Sending;
    pendingVariant.statusLabel = '发送中';
    pendingVariant.lastEvent = 'query_again';
    return pendingVariant;
  }

  static buildVariantFromAnswerInfo(answerInfo: HiAgentMessageAnswerInfo, createMessageId: (prefix: string) => string): ChatAnswerVariant {
    const variant: ChatAnswerVariant = new ChatAnswerVariant(
      answerInfo.messageId.length > 0 ? answerInfo.messageId : createMessageId('answer'),
      answerInfo.answer,
      answerInfo.answer
    );
    variant.serviceMessageId = answerInfo.messageId;
    variant.taskId = answerInfo.taskId;
    variant.createdAt = answerInfo.createdTime * 1000;
    variant.feedback = AgentVariantHelper.toMessageFeedback(answerInfo.like);
    variant.isStreaming = false;
    variant.streamCompleted = true;
    variant.streamPhase = ChatMessagePhase.Finished;
    variant.statusLabel = '已结束';
    return variant;
  }

  static toLikeType(feedback: MessageFeedback): number {
    if (feedback === MessageFeedback.Like) {
      return 1;
    }
    if (feedback === MessageFeedback.Dislike) {
      return -1;
    }
    return 0;
  }

  static toMessageFeedback(likeType: number): MessageFeedback {
    if (likeType > 0) {
      return MessageFeedback.Like;
    }
    if (likeType < 0) {
      return MessageFeedback.Dislike;
    }
    return MessageFeedback.None;
  }
}
