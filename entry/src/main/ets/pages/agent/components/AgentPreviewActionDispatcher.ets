export enum AgentPreviewActionType {
  SelectQuery = 'select_query'
}

export type AgentPreviewActionHandler = (action: AgentPreviewActionType, payload: string) => void;

export class AgentPreviewActionDispatcher {
  private static handler: AgentPreviewActionHandler | null = null;

  static register(handler: AgentPreviewActionHandler): void {
    AgentPreviewActionDispatcher.handler = handler;
  }

  static clear(): void {
    AgentPreviewActionDispatcher.handler = null;
  }

  static dispatch(action: AgentPreviewActionType, payload: string): void {
    if (AgentPreviewActionDispatcher.handler === null) {
      return;
    }
    AgentPreviewActionDispatcher.handler(action, payload);
  }
}
