export enum MarkdownBlockType {
  Paragraph = 'paragraph',
  Heading = 'heading',
  Code = 'code',
  Math = 'math',
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
  Strike = 8,
  Math = 16
}

export enum MarkdownTableAlignment {
  None = 0,
  Left = 1,
  Center = 2,
  Right = 3
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

export class MarkdownListItem {
  id: string;
  checked: boolean = false;
  blocks: Array<MarkdownBlock> = [];

  constructor(id: string) {
    this.id = id;
  }
}

export class MarkdownBlock {
  id: string;
  type: MarkdownBlockType;
  level: number = 0;
  tokens: Array<InlineToken> = [];
  items: Array<Array<InlineToken>> = [];
  taskStates: Array<boolean> = [];
  listItems: Array<MarkdownListItem> = [];
  children: Array<MarkdownBlock> = [];
  headers: Array<Array<InlineToken>> = [];
  rows: Array<Array<Array<InlineToken>>> = [];
  tableAlignments: Array<MarkdownTableAlignment> = [];
  language: string = '';
  code: string = '';
  math: string = '';
  mathDisplay: boolean = false;
  startNumber: number = 1;
  imageAlt: string = '';
  imageUrl: string = '';
  imageTitle: string = '';

  constructor(id: string, type: MarkdownBlockType) {
    this.id = id;
    this.type = type;
  }
}
