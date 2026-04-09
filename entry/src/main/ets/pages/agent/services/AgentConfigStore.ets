import preferences from '@ohos.data.preferences';
import { AgentConversationItem } from '../models/ConversationModels';

export class AgentStoredConfig {
  apiUrl: string;
  apiKey: string;
  userId: string;
  conversationId: string;
  isConfigExpanded: boolean;

  constructor(
    apiUrl: string = '',
    apiKey: string = '',
    userId: string = 'demo-user',
    conversationId: string = '',
    isConfigExpanded: boolean = true
  ) {
    this.apiUrl = apiUrl;
    this.apiKey = apiKey;
    this.userId = userId;
    this.conversationId = conversationId;
    this.isConfigExpanded = isConfigExpanded;
  }
}

export class AgentConfigStore {
  private static readonly STORE_NAME: string = 'hiagent_chat_config';
  private static readonly KEY_API_URL: string = 'api_url';
  private static readonly KEY_API_KEY: string = 'api_key';
  private static readonly KEY_USER_ID: string = 'user_id';
  private static readonly KEY_CONVERSATION_ID: string = 'conversation_id';
  private static readonly KEY_CONFIG_EXPANDED: string = 'config_expanded';
  private static readonly KEY_CONVERSATIONS: string = 'conversation_items';

  static open(context: Context): preferences.Preferences {
    return preferences.getPreferencesSync(context, {
      name: AgentConfigStore.STORE_NAME
    });
  }

  static load(store: preferences.Preferences): AgentStoredConfig {
    return new AgentStoredConfig(
      AgentConfigStore.readString(store, AgentConfigStore.KEY_API_URL, ''),
      AgentConfigStore.readString(store, AgentConfigStore.KEY_API_KEY, ''),
      AgentConfigStore.readString(store, AgentConfigStore.KEY_USER_ID, 'demo-user'),
      AgentConfigStore.readString(store, AgentConfigStore.KEY_CONVERSATION_ID, ''),
      AgentConfigStore.readBoolean(store, AgentConfigStore.KEY_CONFIG_EXPANDED, true)
    );
  }

  static save(store: preferences.Preferences, config: AgentStoredConfig): void {
    store.putSync(AgentConfigStore.KEY_API_URL, config.apiUrl);
    store.putSync(AgentConfigStore.KEY_API_KEY, config.apiKey);
    store.putSync(AgentConfigStore.KEY_USER_ID, config.userId);
    store.putSync(AgentConfigStore.KEY_CONVERSATION_ID, config.conversationId);
    store.putSync(AgentConfigStore.KEY_CONFIG_EXPANDED, config.isConfigExpanded);
    store.flushSync();
  }

  static loadConversations(store: preferences.Preferences): Array<AgentConversationItem> {
    const rawValue: string = AgentConfigStore.readString(store, AgentConfigStore.KEY_CONVERSATIONS, '');
    if (rawValue.trim().length === 0) {
      return [];
    }

    try {
      const parsed: Array<ESObject> = JSON.parse(rawValue) as Array<ESObject>;
      const items: Array<AgentConversationItem> = [];
      for (let index: number = 0; index < parsed.length; index++) {
        const item: ESObject = parsed[index];
        items.push(new AgentConversationItem(
          AgentConfigStore.readObjectString(item, 'appConversationId'),
          AgentConfigStore.readObjectString(item, 'title'),
          AgentConfigStore.readObjectNumber(item, 'createdAt'),
          AgentConfigStore.readObjectBoolean(item, 'isPinned')
        ));
      }
      return items;
    } catch (_error) {
      return [];
    }
  }

  static saveConversations(store: preferences.Preferences, items: Array<AgentConversationItem>): void {
    store.putSync(AgentConfigStore.KEY_CONVERSATIONS, JSON.stringify(items));
    store.flushSync();
  }

  private static readString(store: preferences.Preferences, key: string, defaultValue: string): string {
    const value: preferences.ValueType = store.getSync(key, defaultValue);
    return typeof value === 'string' ? value : defaultValue;
  }

  private static readBoolean(store: preferences.Preferences, key: string, defaultValue: boolean): boolean {
    const value: preferences.ValueType = store.getSync(key, defaultValue);
    return typeof value === 'boolean' ? value : defaultValue;
  }

  private static readObjectString(source: ESObject, key: string): string {
    const value: Object = source[key];
    return typeof value === 'string' ? value : '';
  }

  private static readObjectNumber(source: ESObject, key: string): number {
    const value: Object = source[key];
    return typeof value === 'number' ? value : 0;
  }

  private static readObjectBoolean(source: ESObject, key: string): boolean {
    const value: Object = source[key];
    return typeof value === 'boolean' ? value : false;
  }
}
