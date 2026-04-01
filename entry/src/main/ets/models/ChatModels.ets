export enum MessageRole {
  User = 'user',
  Assistant = 'assistant'
}

export class ChatMessage {
  id: string;
  role: MessageRole;
  rawContent: string;
  visibleContent: string;
  isStreaming: boolean;
  streamCompleted: boolean;
  conversationId: string;
  serviceMessageId: string;
  taskId: string;
  createdAt: number;

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
    this.conversationId = '';
    this.serviceMessageId = '';
    this.taskId = '';
    this.createdAt = Date.now();
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
    nextMessage.conversationId = this.conversationId;
    nextMessage.serviceMessageId = this.serviceMessageId;
    nextMessage.taskId = this.taskId;
    nextMessage.createdAt = this.createdAt;
    return nextMessage;
  }
}
