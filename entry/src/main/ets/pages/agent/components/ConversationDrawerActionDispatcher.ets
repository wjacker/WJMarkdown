export enum ConversationDrawerActionType {
  Close = 'close',
  NewConversation = 'new_conversation',
  SelectConversation = 'select_conversation',
  ToggleMenu = 'toggle_menu',
  TogglePinned = 'toggle_pinned',
  OpenRename = 'open_rename',
  UpdateRenameDraft = 'update_rename_draft',
  ConfirmRename = 'confirm_rename',
  CancelRename = 'cancel_rename',
  DeleteConversation = 'delete_conversation'
}

export type ConversationDrawerActionHandler = (action: ConversationDrawerActionType, conversationId: string,
  payload: string) => void;

export class ConversationDrawerActionDispatcher {
  private static handler: ConversationDrawerActionHandler | null = null;

  static register(handler: ConversationDrawerActionHandler): void {
    ConversationDrawerActionDispatcher.handler = handler;
  }

  static clear(): void {
    ConversationDrawerActionDispatcher.handler = null;
  }

  static dispatch(action: ConversationDrawerActionType, conversationId: string = '', payload: string = ''): void {
    if (ConversationDrawerActionDispatcher.handler === null) {
      return;
    }
    ConversationDrawerActionDispatcher.handler(action, conversationId, payload);
  }
}
