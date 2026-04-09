export enum ChatBubbleActionType {
  Copy = 'copy',
  Regenerate = 'regenerate',
  Delete = 'delete',
  Like = 'like',
  Dislike = 'dislike',
  Sound = 'sound',
  Previous = 'previous',
  Next = 'next'
}

export type ChatBubbleActionHandler = (messageId: string, action: ChatBubbleActionType) => void;

export class ChatBubbleActionDispatcher {
  private static handler: ChatBubbleActionHandler | null = null;

  static register(handler: ChatBubbleActionHandler): void {
    ChatBubbleActionDispatcher.handler = handler;
  }

  static clear(): void {
    ChatBubbleActionDispatcher.handler = null;
  }

  static dispatch(messageId: string, action: ChatBubbleActionType): void {
    if (ChatBubbleActionDispatcher.handler === null) {
      return;
    }
    ChatBubbleActionDispatcher.handler(messageId, action);
  }
}
