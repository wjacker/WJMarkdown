export enum MarkdownBlockType {
  Paragraph = 'paragraph',
  Heading = 'heading',
  Code = 'code',
  Quote = 'quote',
  UnorderedList = 'unorderedList',
  TaskList = 'taskList',
  OrderedList = 'orderedList',
  Divider = 'divider',
  Table = 'table',
  Image = 'image'
}

export enum InlineTokenStyle {
  Plain = 0,
  Bold = 1,
  Italic = 2,
  Code = 4,
  Strike = 8
}

export class InlineToken {
  id: string;
  text: string;
  style: number;
  href: string;

  constructor(id: string, text: string, style: number = InlineTokenStyle.Plain, href: string = '') {
    this.id = id;
    this.text = text;
    this.style = style;
    this.href = href;
  }
}

export class MarkdownBlock {
  id: string;
  type: MarkdownBlockType;
  level: number = 0;
  tokens: Array<InlineToken> = [];
  items: Array<Array<InlineToken>> = [];
  taskStates: Array<boolean> = [];
  headers: Array<Array<InlineToken>> = [];
  rows: Array<Array<Array<InlineToken>>> = [];
  language: string = '';
  code: string = '';
  startNumber: number = 1;
  imageAlt: string = '';
  imageUrl: string = '';

  constructor(id: string, type: MarkdownBlockType) {
    this.id = id;
    this.type = type;
  }
}
