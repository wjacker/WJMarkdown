export class AgentTextUtils {
  static mergeStreamAnswer(currentContent: string, incomingContent: string, replaceAll: boolean = false): string {
    const normalizedIncomingContent: string = AgentTextUtils.normalizeStreamText(incomingContent);
    if (normalizedIncomingContent.length === 0) {
      return currentContent;
    }
    if (replaceAll || currentContent.length === 0) {
      return normalizedIncomingContent;
    }
    if (normalizedIncomingContent === currentContent) {
      return currentContent;
    }
    if (normalizedIncomingContent.startsWith(currentContent)) {
      return normalizedIncomingContent;
    }
    if (currentContent.endsWith(normalizedIncomingContent)) {
      return currentContent;
    }

    const overlapLength: number = AgentTextUtils.findStreamOverlapLength(currentContent, normalizedIncomingContent);
    if (overlapLength > 0) {
      return `${currentContent}${normalizedIncomingContent.substring(overlapLength)}`;
    }

    return `${currentContent}${normalizedIncomingContent}`;
  }

  static normalizeStreamText(content: string): string {
    let normalized: string = content.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    if (normalized.indexOf('\n') < 0 && normalized.includes('\\n')) {
      normalized = normalized.replace(/\\r\\n/g, '\n').replace(/\\n/g, '\n').replace(/\\t/g, '\t');
    }
    return normalized;
  }

  static shortenId(value: string): string {
    if (value.length <= 18) {
      return value;
    }
    return `${value.substring(0, 8)}...${value.substring(value.length - 6)}`;
  }

  static stringifyError(error: Object): string {
    if (typeof error === 'string') {
      return error;
    }
    if (typeof error === 'object' && error !== null) {
      const message: Object = (error as ESObject)['message'];
      if (typeof message === 'string' && message.length > 0) {
        return message;
      }
    }
    return `${error}`;
  }

  static buildSpeechText(content: string): string {
    const normalizedText: string = AgentTextUtils.normalizeStreamText(content);
    if (normalizedText.trim().length === 0) {
      return '';
    }

    let speechText: string = normalizedText
      .replace(/!\[([^\]]*)\]\([^)]+\)/g, '$1')
      .replace(/<img[^>]*alt=["']([^"']*)["'][^>]*>/gi, '$1')
      .replace(/<img[^>]*>/gi, '图片')
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      .replace(/```[\w-]*\n/g, '代码如下：\n')
      .replace(/```/g, '')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/^#{1,6}\s*/gm, '')
      .replace(/^>\s*/gm, '')
      .replace(/^[-*+]\s+/gm, '')
      .replace(/^\d+\.\s+/gm, '')
      .replace(/\|/g, ' ')
      .replace(/[*_~]/g, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim();

    if (speechText.length === 0) {
      speechText = normalizedText.trim();
    }
    return speechText;
  }

  private static findStreamOverlapLength(currentContent: string, incomingContent: string): number {
    const maxOverlap: number = Math.min(currentContent.length, incomingContent.length);
    for (let length: number = maxOverlap; length > 0; length--) {
      if (currentContent.substring(currentContent.length - length) === incomingContent.substring(0, length)) {
        return length;
      }
    }
    return 0;
  }
}
