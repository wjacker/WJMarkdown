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

export class AgentAnswer {
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

  copy(): AgentAnswer {
    const nextVersion: AgentAnswer = new AgentAnswer(this.id, this.rawContent, this.visibleContent);
    nextVersion.serviceMessageId = this.serviceMessageId;
    nextVersion.taskId = this.taskId;
    nextVersion.createdAt = this.createdAt;
    nextVersion.feedback = this.feedback;
    nextVersion.isStreaming = this.isStreaming;
    nextVersion.streamCompleted = this.streamCompleted;
    nextVersion.streamPhase = this.streamPhase;
    nextVersion.statusLabel = this.statusLabel;
    nextVersion.lastEvent = this.lastEvent;
    return nextVersion;
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
  answerCount: number;
  activeAnswerIndex: number;
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
    this.answerCount = 0;
    this.activeAnswerIndex = 0;
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
    nextMessage.answerCount = this.answerCount;
    nextMessage.activeAnswerIndex = this.activeAnswerIndex;
    nextMessage.showActions = this.showActions;
    return nextMessage;
  }
}
