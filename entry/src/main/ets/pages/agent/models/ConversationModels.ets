export class AgentConversationItem {
  appConversationId: string;
  title: string;
  createdAt: number;
  isPinned: boolean;

  constructor(
    appConversationId: string = '',
    title: string = '',
    createdAt: number = 0,
    isPinned: boolean = false
  ) {
    this.appConversationId = appConversationId;
    this.title = title;
    this.createdAt = createdAt;
    this.isPinned = isPinned;
  }

  copy(): AgentConversationItem {
    return new AgentConversationItem(
      this.appConversationId,
      this.title,
      this.createdAt,
      this.isPinned
    );
  }
}

export class AgentConversationHelper {
  static buildDisplayTitle(item: AgentConversationItem): string {
    const title: string = item.title.trim();
    if (title.length > 0) {
      return title;
    }
    return item.appConversationId.length > 0 ? item.appConversationId : '未命名会话';
  }

  static sort(items: Array<AgentConversationItem>): Array<AgentConversationItem> {
    const nextItems: Array<AgentConversationItem> = [];
    for (let index: number = 0; index < items.length; index++) {
      nextItems.push(items[index].copy());
    }
    nextItems.sort((left: AgentConversationItem, right: AgentConversationItem) => {
      if (left.isPinned !== right.isPinned) {
        return left.isPinned ? -1 : 1;
      }
      return right.createdAt - left.createdAt;
    });
    return nextItems;
  }

  static buildDateLabel(createdAt: number): string {
    if (createdAt <= 0) {
      return '';
    }
    const date: Date = new Date(createdAt);
    const month: string = `${date.getMonth() + 1}`.padStart(2, '0');
    const day: string = `${date.getDate()}`.padStart(2, '0');
    return `${month}-${day}`;
  }

  static buildGroupTitle(createdAt: number): string {
    if (createdAt <= 0) {
      return '更早';
    }
    const now: Date = new Date();
    const currentYear: number = now.getFullYear();
    const currentMonth: number = now.getMonth();
    const currentDay: number = now.getDate();
    const date: Date = new Date(createdAt);
    if (date.getFullYear() === currentYear && date.getMonth() === currentMonth && date.getDate() === currentDay) {
      return '今天';
    }
    return AgentConversationHelper.buildDateLabel(createdAt);
  }
}

export class AgentConversationSection {
  title: string;
  items: Array<AgentConversationItem>;

  constructor(title: string = '', items: Array<AgentConversationItem> = []) {
    this.title = title;
    this.items = items;
  }
}
