import { AgentAnswer, ChatMessage, ChatMessagePhase, MessageFeedback } from '../models/ChatModels';
import { HiAgentMessageAnswerInfo } from '../models/HiAgentModels';

export class AgentAnswerHelper {
  static createAnswerFromMessage(message: ChatMessage, fallbackId: string): AgentAnswer {
    const answer: AgentAnswer = new AgentAnswer(
      message.serviceMessageId.length > 0 ? message.serviceMessageId : fallbackId,
      message.rawContent,
      message.visibleContent
    );
    answer.serviceMessageId = message.serviceMessageId;
    answer.taskId = message.taskId;
    answer.createdAt = message.createdAt;
    answer.feedback = message.feedback;
    answer.isStreaming = message.isStreaming;
    answer.streamCompleted = message.streamCompleted;
    answer.streamPhase = message.streamPhase;
    answer.statusLabel = message.statusLabel;
    answer.lastEvent = message.lastEvent;
    return answer;
  }

  static applyAnswerMeta(message: ChatMessage, answers: Array<AgentAnswer>): void {
    message.answerCount = answers.length;
    if (answers.length === 0) {
      message.activeAnswerIndex = 0;
      return;
    }
    if (message.activeAnswerIndex < 0) {
      message.activeAnswerIndex = 0;
    }
    if (message.activeAnswerIndex >= answers.length) {
      message.activeAnswerIndex = answers.length - 1;
    }
  }

  static syncMessageToAnswer(message: ChatMessage, answer: AgentAnswer): void {
    answer.rawContent = message.rawContent;
    answer.visibleContent = message.visibleContent;
    answer.serviceMessageId = message.serviceMessageId;
    answer.taskId = message.taskId;
    answer.createdAt = message.createdAt;
    answer.feedback = message.feedback;
    answer.isStreaming = message.isStreaming;
    answer.streamCompleted = message.streamCompleted;
    answer.streamPhase = message.streamPhase;
    answer.statusLabel = message.statusLabel;
    answer.lastEvent = message.lastEvent;
  }

  static applyAnswerToMessage(message: ChatMessage, answer: AgentAnswer): void {
    message.rawContent = answer.rawContent;
    message.visibleContent = answer.visibleContent;
    message.serviceMessageId = answer.serviceMessageId;
    message.taskId = answer.taskId;
    message.createdAt = answer.createdAt;
    message.feedback = answer.feedback;
    message.isStreaming = answer.isStreaming;
    message.streamCompleted = answer.streamCompleted;
    message.streamPhase = answer.streamPhase;
    message.statusLabel = answer.statusLabel;
    message.lastEvent = answer.lastEvent;
  }

  static buildAnswerMergeKey(answer: AgentAnswer): string {
    if (answer.serviceMessageId.trim().length > 0) {
      return `id:${answer.serviceMessageId.trim()}`;
    }
    const rawKey: string = answer.rawContent.trim();
    if (rawKey.length > 0) {
      return `raw:${rawKey}`;
    }
    return `local:${answer.id}`;
  }

  static buildPendingAnswerForRetry(localMessageId: string, createMessageId: (prefix: string) => string): AgentAnswer {
    const pendingVersion: AgentAnswer = new AgentAnswer(createMessageId(`answer-version-${localMessageId}`));
    pendingVersion.createdAt = Date.now();
    pendingVersion.isStreaming = true;
    pendingVersion.streamCompleted = false;
    pendingVersion.streamPhase = ChatMessagePhase.Sending;
    pendingVersion.statusLabel = '发送中';
    pendingVersion.lastEvent = 'query_again';
    return pendingVersion;
  }

  static buildAnswerFromAnswerInfo(answerInfo: HiAgentMessageAnswerInfo, createMessageId: (prefix: string) => string): AgentAnswer {
    const answer: AgentAnswer = new AgentAnswer(
      answerInfo.messageId.length > 0 ? answerInfo.messageId : createMessageId('answer'),
      answerInfo.answer,
      answerInfo.answer
    );
    answer.serviceMessageId = answerInfo.messageId;
    answer.taskId = answerInfo.taskId;
    answer.createdAt = answerInfo.createdTime * 1000;
    answer.feedback = AgentAnswerHelper.toMessageFeedback(answerInfo.like);
    answer.isStreaming = false;
    answer.streamCompleted = true;
    answer.streamPhase = ChatMessagePhase.Finished;
    answer.statusLabel = '已结束';
    return answer;
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
