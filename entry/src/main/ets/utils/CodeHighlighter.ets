import { CodeLine, CodeSegment, CodeTokenKind } from '../models/CodeHighlightModels';

export class CodeHighlighter {
  private static segmentCounter: number = 0;

  static highlight(code: string, language: string): Array<CodeLine> {
    CodeHighlighter.segmentCounter = 0;
    const lines: Array<string> = code.replace(/\r\n/g, '\n').split('\n');
    const highlightedLines: Array<CodeLine> = [];

    for (let index: number = 0; index < lines.length; index++) {
      const codeLine: CodeLine = new CodeLine(`code-line-${index}`, index + 1);
      codeLine.segments = CodeHighlighter.highlightLine(lines[index], language);
      highlightedLines.push(codeLine);
    }

    return highlightedLines;
  }

  private static highlightLine(line: string, language: string): Array<CodeSegment> {
    const segments: Array<CodeSegment> = [];
    let cursor: number = 0;

    while (cursor < line.length) {
      const commentMarker: string = CodeHighlighter.getCommentMarker(language);
      if (commentMarker.length > 0 && line.startsWith(commentMarker, cursor)) {
        segments.push(CodeHighlighter.createSegment(line.substring(cursor), CodeTokenKind.Comment));
        break;
      }

      const currentChar: string = line[cursor];
      if (CodeHighlighter.isQuote(currentChar)) {
        const stringEnd: number = CodeHighlighter.findStringEnd(line, cursor, currentChar);
        segments.push(CodeHighlighter.createSegment(line.substring(cursor, stringEnd), CodeTokenKind.String));
        cursor = stringEnd;
        continue;
      }

      if (CodeHighlighter.isNumberStart(line, cursor)) {
        const numberEnd: number = CodeHighlighter.findNumberEnd(line, cursor);
        segments.push(CodeHighlighter.createSegment(line.substring(cursor, numberEnd), CodeTokenKind.Number));
        cursor = numberEnd;
        continue;
      }

      if (CodeHighlighter.isIdentifierStart(currentChar)) {
        const identifierEnd: number = CodeHighlighter.findIdentifierEnd(line, cursor);
        const identifier: string = line.substring(cursor, identifierEnd);
        segments.push(CodeHighlighter.createSegment(identifier, CodeHighlighter.getIdentifierKind(identifier, language)));
        cursor = identifierEnd;
        continue;
      }

      if (CodeHighlighter.isOperator(currentChar)) {
        segments.push(CodeHighlighter.createSegment(currentChar, CodeTokenKind.Operator));
        cursor++;
        continue;
      }

      const plainEnd: number = CodeHighlighter.findPlainEnd(line, cursor);
      segments.push(CodeHighlighter.createSegment(line.substring(cursor, plainEnd), CodeTokenKind.Plain));
      cursor = plainEnd;
    }

    if (segments.length === 0) {
      segments.push(CodeHighlighter.createSegment(' ', CodeTokenKind.Plain));
    }

    return segments;
  }

  private static getCommentMarker(language: string): string {
    const normalizedLanguage: string = language.toLowerCase();
    if (normalizedLanguage === 'ts' || normalizedLanguage === 'tsx' || normalizedLanguage === 'js' ||
      normalizedLanguage === 'jsx' || normalizedLanguage === 'javascript' || normalizedLanguage === 'typescript' ||
      normalizedLanguage === 'arkts' || normalizedLanguage === 'java' || normalizedLanguage === 'c' ||
      normalizedLanguage === 'cpp' || normalizedLanguage === 'jsonc') {
      return '//';
    }
    if (normalizedLanguage === 'sh' || normalizedLanguage === 'bash' || normalizedLanguage === 'zsh' ||
      normalizedLanguage === 'yml' || normalizedLanguage === 'yaml' || normalizedLanguage === 'python' ||
      normalizedLanguage === 'py' || normalizedLanguage === 'ruby' || normalizedLanguage === 'markdown' ||
      normalizedLanguage === 'md') {
      return '#';
    }
    return '';
  }

  private static getIdentifierKind(identifier: string, language: string): CodeTokenKind {
    if (CodeHighlighter.isLiteral(identifier)) {
      return CodeTokenKind.Literal;
    }
    if (CodeHighlighter.isKeyword(identifier, language)) {
      return CodeTokenKind.Keyword;
    }
    if (identifier.length > 0 && identifier[0] >= 'A' && identifier[0] <= 'Z') {
      return CodeTokenKind.Type;
    }
    return CodeTokenKind.Plain;
  }

  private static isLiteral(identifier: string): boolean {
    return identifier === 'true' || identifier === 'false' || identifier === 'null' ||
      identifier === 'undefined' || identifier === 'this';
  }

  private static isKeyword(identifier: string, language: string): boolean {
    const normalizedLanguage: string = language.toLowerCase();
    return CodeHighlighter.getKeywords(normalizedLanguage).indexOf(identifier) >= 0;
  }

  private static getKeywords(language: string): Array<string> {
    if (language === 'json') {
      return [];
    }
    if (language === 'sh' || language === 'bash' || language === 'zsh') {
      return ['if', 'then', 'fi', 'for', 'do', 'done', 'echo', 'export', 'case', 'esac', 'while'];
    }
    return [
      'const', 'let', 'var', 'function', 'return', 'if', 'else', 'for', 'while', 'switch', 'case',
      'break', 'continue', 'import', 'from', 'export', 'class', 'extends', 'new', 'try', 'catch',
      'finally', 'throw', 'async', 'await', 'interface', 'type', 'enum', 'public', 'private', 'protected',
      'static', 'readonly'
    ];
  }

  private static findPlainEnd(line: string, startIndex: number): number {
    let cursor: number = startIndex;
    while (cursor < line.length) {
      const currentChar: string = line[cursor];
      if (CodeHighlighter.isQuote(currentChar) || CodeHighlighter.isIdentifierStart(currentChar) ||
        CodeHighlighter.isNumberStart(line, cursor) || CodeHighlighter.isOperator(currentChar)) {
        break;
      }
      cursor++;
    }
    return cursor > startIndex ? cursor : startIndex + 1;
  }

  private static findNumberEnd(line: string, startIndex: number): number {
    let cursor: number = startIndex;
    while (cursor < line.length) {
      const currentChar: string = line[cursor];
      if ((currentChar < '0' || currentChar > '9') && currentChar !== '.') {
        break;
      }
      cursor++;
    }
    return cursor;
  }

  private static findIdentifierEnd(line: string, startIndex: number): number {
    let cursor: number = startIndex;
    while (cursor < line.length && CodeHighlighter.isIdentifierPart(line[cursor])) {
      cursor++;
    }
    return cursor;
  }

  private static findStringEnd(line: string, startIndex: number, quote: string): number {
    let cursor: number = startIndex + 1;
    while (cursor < line.length) {
      if (line[cursor] === '\\') {
        cursor += 2;
        continue;
      }
      if (line[cursor] === quote) {
        cursor++;
        break;
      }
      cursor++;
    }
    return cursor;
  }

  private static isQuote(char: string): boolean {
    return char === '"' || char === '\'' || char === '`';
  }

  private static isIdentifierStart(char: string): boolean {
    return (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z') || char === '_' || char === '$';
  }

  private static isIdentifierPart(char: string): boolean {
    return CodeHighlighter.isIdentifierStart(char) || (char >= '0' && char <= '9');
  }

  private static isNumberStart(line: string, index: number): boolean {
    const char: string = line[index];
    if (char < '0' || char > '9') {
      return false;
    }
    if (index > 0 && CodeHighlighter.isIdentifierPart(line[index - 1])) {
      return false;
    }
    return true;
  }

  private static isOperator(char: string): boolean {
    return '{}[]()=+-*/<>!?:.,;|&'.indexOf(char) >= 0;
  }

  private static createSegment(text: string, kind: CodeTokenKind): CodeSegment {
    CodeHighlighter.segmentCounter++;
    return new CodeSegment(`code-segment-${CodeHighlighter.segmentCounter}`, text, kind);
  }
}
