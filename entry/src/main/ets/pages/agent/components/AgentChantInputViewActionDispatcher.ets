export enum AgentChantInputViewActionType {
  Voice = 'voice',
  SubmitOrStop = 'submit_or_stop'
}

export type AgentChantInputViewActionHandler = (action: AgentChantInputViewActionType) => void;

export class AgentChantInputViewActionDispatcher {
  private static handler: AgentChantInputViewActionHandler | null = null;

  static register(handler: AgentChantInputViewActionHandler): void {
    AgentChantInputViewActionDispatcher.handler = handler;
  }

  static clear(): void {
    AgentChantInputViewActionDispatcher.handler = null;
  }

  static dispatch(action: AgentChantInputViewActionType): void {
    if (AgentChantInputViewActionDispatcher.handler === null) {
      return;
    }
    AgentChantInputViewActionDispatcher.handler(action);
  }
}
