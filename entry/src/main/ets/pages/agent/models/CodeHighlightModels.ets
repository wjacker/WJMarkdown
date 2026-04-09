export enum CodeTokenKind {
  Plain = 'plain',
  Keyword = 'keyword',
  String = 'string',
  Number = 'number',
  Comment = 'comment',
  Operator = 'operator',
  Type = 'type',
  Literal = 'literal'
}

export class CodeSegment {
  id: string;
  text: string;
  kind: CodeTokenKind;

  constructor(id: string, text: string, kind: CodeTokenKind) {
    this.id = id;
    this.text = text;
    this.kind = kind;
  }
}

export class CodeLine {
  id: string;
  lineNumber: number;
  segments: Array<CodeSegment> = [];

  constructor(id: string, lineNumber: number) {
    this.id = id;
    this.lineNumber = lineNumber;
  }
}
