export enum MessageRole {
  User = 'user',
  Assistant = 'assistant'
}

export enum ChatMessagePhase {
  Idle = 'idle',
  Sending = 'sending',
  Thinking = 'thinking',
  Answering = 'answering',
  Finished = 'finished',
  Stopped = 'stopped',
  Error = 'error'
}

export enum MessageFeedback {
  None = 'none',
  Like = 'like',
  Dislike = 'dislike'
}

export class ChatAnswerVariant {
  id: string;
  rawContent: string;
  visibleContent: string;
  serviceMessageId: string;
  taskId: string;
  createdAt: number;
  feedback: MessageFeedback;
  isStreaming: boolean;
  streamCompleted: boolean;
  streamPhase: ChatMessagePhase;
  statusLabel: string;
  lastEvent: string;

  constructor(id: string, rawContent: string = '', visibleContent: string = rawContent) {
    this.id = id;
    this.rawContent = rawContent;
    this.visibleContent = visibleContent;
    this.serviceMessageId = '';
    this.taskId = '';
    this.createdAt = Date.now();
    this.feedback = MessageFeedback.None;
    this.isStreaming = false;
    this.streamCompleted = true;
    this.streamPhase = ChatMessagePhase.Idle;
    this.statusLabel = '';
    this.lastEvent = '';
  }

  copy(): ChatAnswerVariant {
    const nextVariant: ChatAnswerVariant = new ChatAnswerVariant(this.id, this.rawContent, this.visibleContent);
    nextVariant.serviceMessageId = this.serviceMessageId;
    nextVariant.taskId = this.taskId;
    nextVariant.createdAt = this.createdAt;
    nextVariant.feedback = this.feedback;
    nextVariant.isStreaming = this.isStreaming;
    nextVariant.streamCompleted = this.streamCompleted;
    nextVariant.streamPhase = this.streamPhase;
    nextVariant.statusLabel = this.statusLabel;
    nextVariant.lastEvent = this.lastEvent;
    return nextVariant;
  }
}

@Observed
export class ChatMessage {
  id: string;
  role: MessageRole;
  rawContent: string;
  visibleContent: string;
  isStreaming: boolean;
  streamCompleted: boolean;
  streamPhase: ChatMessagePhase;
  statusLabel: string;
  lastEvent: string;
  conversationId: string;
  queryId: string;
  serviceMessageId: string;
  taskId: string;
  createdAt: number;
  feedback: MessageFeedback;
  answerVersionCount: number;
  activeAnswerVersionIndex: number;
  showActions: boolean;

  constructor(
    id: string,
    role: MessageRole,
    rawContent: string,
    visibleContent: string = rawContent,
    isStreaming: boolean = false,
    streamCompleted: boolean = !isStreaming
  ) {
    this.id = id;
    this.role = role;
    this.rawContent = rawContent;
    this.visibleContent = visibleContent;
    this.isStreaming = isStreaming;
    this.streamCompleted = streamCompleted;
    this.streamPhase = isStreaming ? ChatMessagePhase.Sending : ChatMessagePhase.Idle;
    this.statusLabel = '';
    this.lastEvent = '';
    this.conversationId = '';
    this.queryId = '';
    this.serviceMessageId = '';
    this.taskId = '';
    this.createdAt = Date.now();
    this.feedback = MessageFeedback.None;
    this.answerVersionCount = 0;
    this.activeAnswerVersionIndex = 0;
    this.showActions = false;
  }

  static user(id: string, content: string): ChatMessage {
    return new ChatMessage(id, MessageRole.User, content, content, false);
  }

  static assistant(id: string, content: string, visibleContent: string = '', isStreaming: boolean = true): ChatMessage {
    return new ChatMessage(id, MessageRole.Assistant, content, visibleContent, isStreaming, !isStreaming);
  }

  cloneWithVisibleContent(visibleContent: string, isStreaming: boolean): ChatMessage {
    const nextMessage: ChatMessage = this.copy();
    nextMessage.visibleContent = visibleContent;
    nextMessage.isStreaming = isStreaming;
    return nextMessage;
  }

  copy(): ChatMessage {
    const nextMessage: ChatMessage = new ChatMessage(
      this.id,
      this.role,
      this.rawContent,
      this.visibleContent,
      this.isStreaming,
      this.streamCompleted
    );
    nextMessage.streamPhase = this.streamPhase;
    nextMessage.statusLabel = this.statusLabel;
    nextMessage.lastEvent = this.lastEvent;
    nextMessage.conversationId = this.conversationId;
    nextMessage.queryId = this.queryId;
    nextMessage.serviceMessageId = this.serviceMessageId;
    nextMessage.taskId = this.taskId;
    nextMessage.createdAt = this.createdAt;
    nextMessage.feedback = this.feedback;
    nextMessage.answerVersionCount = this.answerVersionCount;
    nextMessage.activeAnswerVersionIndex = this.activeAnswerVersionIndex;
    nextMessage.showActions = this.showActions;
    return nextMessage;
  }
}
