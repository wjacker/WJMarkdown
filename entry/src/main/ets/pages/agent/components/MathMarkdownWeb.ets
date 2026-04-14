import web_webview from '@ohos.web.webview';
import { hilog } from '@kit.PerformanceAnalysisKit';
import pasteboard from '@ohos.pasteboard';
import { promptAction } from '@kit.ArkUI';
import { MarkdownHtmlRenderer } from '../utils/MarkdownHtmlRenderer';

const MATH_DEBUG_DOMAIN: number = 0x3202;
const MATH_DEBUG_TAG: string = 'MathMarkdownWeb';
@Component
export struct MathMarkdownWeb {
  @Prop content: string = '';
  @Prop isAssistant: boolean = true;
  @State private webReady: boolean = false;
  @State private showFallback: boolean = true;
  @State private debugLog: string = '';

  private controller: web_webview.WebviewController = new web_webview.WebviewController();
  private controllerAttached: boolean = false;
  private shellLoaded: boolean = false;
  private lastInjectedHtml: string = '';

  aboutToAppear(): void {
    this.appendDebug(`aboutToAppear contentLength=${this.content.length}`);
    try {
      web_webview.WebviewController.initializeWebEngine();
      this.appendDebug('initializeWebEngine success');
    } catch (_error) {
      this.webReady = false;
      this.appendDebug('initializeWebEngine failed');
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.showFallback) {
        Text(this.content)
          .width('100%')
          .fontSize(15)
          .lineHeight(24)
          .fontColor(this.isAssistant ? '#1E293B' : '#F8FAFC')
          .wordBreak(WordBreak.BREAK_WORD)
      }

      Web({ src: $rawfile('mathjax/math-shell.html'), controller: this.controller, renderMode: RenderMode.SYNC_RENDER })
        .width('100%')
        .layoutMode(WebLayoutMode.FIT_CONTENT)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .verticalScrollBarAccess(false)
        .horizontalScrollBarAccess(false)
        .backgroundColor('#00000000')
        .visibility(this.showFallback ? Visibility.Hidden : Visibility.Visible)
        .onControllerAttached(() => {
          this.controllerAttached = true;
          this.appendDebug('onControllerAttached');
        })
        .onPageEnd(() => {
          this.appendDebug('onPageEnd');
          this.shellLoaded = true;
          void this.collectShellDiagnostics('onPageEnd');
          void this.injectContentIfNeeded();
        })
    }
    .width('100%')
  }

  private async injectContentIfNeeded(): Promise<void> {
    if (!this.controllerAttached || !this.shellLoaded) {
      this.appendDebug('injectContentIfNeeded skipped: shell not ready');
      return;
    }

    const html: string = MarkdownHtmlRenderer.render(this.content);
    if (html === this.lastInjectedHtml) {
      this.appendDebug('injectContentIfNeeded skipped: html unchanged');
      return;
    }

    this.lastInjectedHtml = html;
    this.webReady = false;
    this.showFallback = true;
    this.appendDebug(`injectContentIfNeeded start htmlLength=${html.length}`);

    try {
      const payload: string = JSON.stringify(html);
      const textColor: string = JSON.stringify(this.isAssistant ? '#1E293B' : '#F8FAFC');
      const injectResult: string = await this.controller.runJavaScript(
        `(function () {
          var root = document.getElementById('root');
          var shellReady = !!window.__mathShellReady;
          var hasMathJax = typeof window.MathJax !== 'undefined';
          if (!root) {
            return JSON.stringify({
              stage: 'inject',
              shellReady: shellReady,
              hasMathJax: hasMathJax,
              hasRoot: false,
              bodyLength: document && document.body ? document.body.innerHTML.length : 0,
              scriptCount: document.scripts ? document.scripts.length : 0,
              readyState: document.readyState || '',
              href: location.href || ''
            });
          }

          document.body.style.color = ${textColor};
          root.innerHTML = ${payload};
          return JSON.stringify({
            stage: 'inject',
            shellReady: shellReady,
            hasMathJax: hasMathJax,
            hasRoot: true,
            rootLength: root.innerHTML.length,
            bodyLength: document && document.body ? document.body.innerHTML.length : 0,
            scriptCount: document.scripts ? document.scripts.length : 0,
            readyState: document.readyState || '',
            href: location.href || ''
          });
        })();`
      );
      this.appendDebug(`injectContentIfNeeded syncInject=${injectResult.replace(/\n/g, ' ')}`);
      const injectDiagnostics: InjectDiagnostics | null = InjectDiagnostics.fromJson(injectResult);
      this.logInjectDiagnostics('injectContentIfNeeded', injectDiagnostics);

      const result: string = await this.controller.runJavaScript(
        `(function () {
          if (!window.__mathShellReady || !window.renderMathContent) {
            return 'shell-not-ready';
          }
          window.__mathRenderStatus = 'started';
          return window.renderMathContent(${payload}, { textColor: ${textColor} });
        })();`
      );
      const normalizedResult: string = result.replace(/"/g, '').trim();
      this.appendDebug(`injectContentIfNeeded result=${normalizedResult}`);
      let shellDiagnostics: ShellDiagnostics | null = await this.collectShellDiagnostics('injectContentIfNeeded');
      this.logRenderDecision('injectContentIfNeeded', normalizedResult, injectDiagnostics, shellDiagnostics);
      let shouldShowWeb: boolean = this.shouldTreatAsReady(injectDiagnostics, shellDiagnostics);
      this.webReady = shouldShowWeb;
      this.showFallback = !shouldShowWeb;
      this.appendDebug(`injectContentIfNeeded webReady=${this.webReady} showFallback=${this.showFallback}`);
    } catch (_error) {
      this.webReady = false;
      this.showFallback = true;
      this.appendDebug('injectContentIfNeeded threw exception');
    }
  }

  private async collectShellDiagnostics(stage: string): Promise<ShellDiagnostics | null> {
    const diagnostics: ShellDiagnostics | null = await this.readShellDiagnostics();
    this.logShellDiagnostics(stage, diagnostics);
    return diagnostics;
  }

  private async readShellDiagnostics(): Promise<ShellDiagnostics | null> {
    try {
      const result: string = await this.controller.runJavaScript(
        `(function () {
          var root = document.getElementById('root');
          return JSON.stringify({
            shellReady: !!window.__mathShellReady,
            hasRenderMathContent: typeof window.renderMathContent === 'function',
            hasMathRenderStatus: typeof window.__mathRenderStatus !== 'undefined',
            mathRenderStatus: typeof window.__mathRenderStatus !== 'undefined' ? window.__mathRenderStatus : '',
            hasMathJax: typeof window.MathJax !== 'undefined',
            hasStartup: !!(window.MathJax && window.MathJax.startup),
            hasStartupPromise: !!(window.MathJax && window.MathJax.startup && window.MathJax.startup.promise),
            hasTypesetPromise: !!(window.MathJax && window.MathJax.typesetPromise),
            hasRoot: !!root,
            rootLength: root ? root.innerHTML.length : 0,
            bodyLength: document && document.body ? document.body.innerHTML.length : 0,
            scriptCount: document.scripts ? document.scripts.length : 0,
            mjxCount: document.querySelectorAll('mjx-container').length,
            svgCount: document.querySelectorAll('svg[data-mml-node]').length,
            readyState: document.readyState || '',
            href: location.href || '',
            title: document.title || ''
          });
        })();`
      );
      return ShellDiagnostics.fromJson(result);
    } catch (_error) {
      return null;
    }
  }

  private logShellDiagnostics(stage: string, diagnostics: ShellDiagnostics | null): void {
    if (diagnostics === null) {
      this.appendDebug(`${stage} shell diagnostics failed`);
      return;
    }
    this.appendDebug(`${stage} shell=${diagnostics.toLogString()}`);
  }

  private logInjectDiagnostics(stage: string, diagnostics: InjectDiagnostics | null): void {
    if (diagnostics === null) {
      this.appendDebug(`${stage} inject diagnostics failed`);
      return;
    }
    this.appendDebug(`${stage} inject=${diagnostics.toLogString()}`);
  }

  private logRenderDecision(stage: string, result: string, injectDiagnostics: InjectDiagnostics | null,
    shellDiagnostics: ShellDiagnostics | null): void {
    if (injectDiagnostics === null) {
      this.appendDebug(`${stage} renderDecision={"result":"${result}","ready":false,"reason":"inject-diagnostics-null"}`);
      return;
    }

    const ready: boolean = this.shouldTreatAsReady(injectDiagnostics, shellDiagnostics);
    this.appendDebug(
      `${stage} renderDecision={"result":"${result}","ready":${ready},` +
      `"injectShellReady":${injectDiagnostics.shellReady},"injectHasMathJax":${injectDiagnostics.hasMathJax},` +
      `"injectHasRoot":${injectDiagnostics.hasRoot},"injectRootLength":${injectDiagnostics.rootLength},` +
      `"injectBodyLength":${injectDiagnostics.bodyLength},"injectScriptCount":${injectDiagnostics.scriptCount},` +
      `"injectReadyState":"${injectDiagnostics.readyState}","injectHref":"${injectDiagnostics.href}",` +
      `"shellAvailable":${shellDiagnostics !== null}}`);
  }

  private shouldTreatAsReady(injectDiagnostics: InjectDiagnostics | null, shellDiagnostics: ShellDiagnostics | null): boolean {
    if (injectDiagnostics === null) {
      return false;
    }

    const injectReady: boolean = injectDiagnostics.shellReady &&
      injectDiagnostics.hasRoot &&
      injectDiagnostics.bodyLength > 0 &&
      injectDiagnostics.scriptCount > 0 &&
      injectDiagnostics.readyState.length > 0 &&
      injectDiagnostics.href.length > 0;

    if (!injectReady) {
      return false;
    }

    if (shellDiagnostics !== null && shellDiagnostics.mjxCount > 0) {
      return true;
    }

    if (shellDiagnostics !== null && shellDiagnostics.svgCount > 0) {
      return true;
    }

    return injectDiagnostics.hasMathJax;
  }

  private appendDebug(message: string): void {
    const nextLine: string = `[MathDebug] ${message}`;
    this.debugLog = this.debugLog.length > 0 ? `${this.debugLog}\n${nextLine}` : nextLine;
    hilog.info(MATH_DEBUG_DOMAIN, MATH_DEBUG_TAG, '%{public}s', nextLine);
  }

  @Builder
  private DebugPanelBuilder() {
    Column({ space: 6 }) {
      Row() {
        Text('Math Debug')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#B45309')

        Blank()

        Text('Copy')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2563EB')
          .padding({ top: 4, right: 8, bottom: 4, left: 8 })
          .backgroundColor('#FFFFFF')
          .borderRadius(999)
          .onClick(() => {
            void this.copyDebugLog();
          })
      }
      .width('100%')

      Text(this.debugLog.length > 0 ? this.debugLog : '[MathDebug] no logs')
        .width('100%')
        .fontSize(10)
        .lineHeight(16)
        .fontColor('#92400E')
        .fontFamily('monospace')
        .wordBreak(WordBreak.BREAK_WORD)
    }
    .width('100%')
    .padding(10)
    .borderRadius(12)
    .backgroundColor('#FFF7ED')
    .border({
      width: 1,
      color: '#FED7AA'
    })
  }

  private async copyDebugLog(): Promise<void> {
    if (this.debugLog.trim().length === 0) {
      this.showToast('当前还没有可复制的调试日志');
      return;
    }

    try {
      this.logDebugDump();
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.debugLog);
      await systemPasteboard.setData(data);
      this.showToast('已复制调试日志');
    } catch (_error) {
      this.logDebugDump();
      this.showToast('复制调试日志失败');
    }
  }

  private logDebugDump(): void {
    const lines: Array<string> = this.debugLog.split('\n');
    hilog.info(MATH_DEBUG_DOMAIN, MATH_DEBUG_TAG, '%{public}s', '[MathDebugDump] ===== START =====');
    for (let index: number = 0; index < lines.length; index++) {
      hilog.info(MATH_DEBUG_DOMAIN, MATH_DEBUG_TAG, '%{public}s', `[MathDebugDump] ${lines[index]}`);
    }
    hilog.info(MATH_DEBUG_DOMAIN, MATH_DEBUG_TAG, '%{public}s', '[MathDebugDump] ===== END =====');
  }

  private showToast(message: string): void {
    promptAction.showToast({
      message: message
    });
  }

}

class InjectDiagnostics {
  shellReady: boolean = false;
  hasMathJax: boolean = false;
  hasRoot: boolean = false;
  rootLength: number = 0;
  bodyLength: number = 0;
  scriptCount: number = 0;
  readyState: string = '';
  href: string = '';

  static fromJson(jsonText: string): InjectDiagnostics | null {
    try {
      const data: ESObject | null = parseJavaScriptJsonObject(jsonText);
      if (data === null) {
        return null;
      }
      const diagnostics: InjectDiagnostics = new InjectDiagnostics();
      diagnostics.shellReady = typeof data['shellReady'] === 'boolean' ? (data['shellReady'] as boolean) : false;
      diagnostics.hasMathJax = typeof data['hasMathJax'] === 'boolean' ? (data['hasMathJax'] as boolean) : false;
      diagnostics.hasRoot = typeof data['hasRoot'] === 'boolean' ? (data['hasRoot'] as boolean) : false;
      diagnostics.rootLength = typeof data['rootLength'] === 'number' ? (data['rootLength'] as number) : 0;
      diagnostics.bodyLength = typeof data['bodyLength'] === 'number' ? (data['bodyLength'] as number) : 0;
      diagnostics.scriptCount = typeof data['scriptCount'] === 'number' ? (data['scriptCount'] as number) : 0;
      diagnostics.readyState = typeof data['readyState'] === 'string' ? (data['readyState'] as string) : '';
      diagnostics.href = typeof data['href'] === 'string' ? (data['href'] as string) : '';
      return diagnostics;
    } catch (_error) {
      return null;
    }
  }

  toLogString(): string {
    return `{"shellReady":${this.shellReady},"hasMathJax":${this.hasMathJax},"hasRoot":${this.hasRoot},` +
      `"rootLength":${this.rootLength},"bodyLength":${this.bodyLength},"scriptCount":${this.scriptCount},` +
      `"readyState":"${this.readyState}","href":"${this.href}"}`;
  }
}

class ShellDiagnostics {
  shellReady: boolean = false;
  hasRenderMathContent: boolean = false;
  hasMathRenderStatus: boolean = false;
  mathRenderStatus: string = '';
  hasMathJax: boolean = false;
  hasStartup: boolean = false;
  hasStartupPromise: boolean = false;
  hasTypesetPromise: boolean = false;
  hasRoot: boolean = false;
  rootLength: number = 0;
  bodyLength: number = 0;
  scriptCount: number = 0;
  mjxCount: number = 0;
  svgCount: number = 0;
  readyState: string = '';
  href: string = '';
  title: string = '';

  static fromJson(jsonText: string): ShellDiagnostics | null {
    try {
      const data: ESObject | null = parseJavaScriptJsonObject(jsonText);
      if (data === null) {
        return null;
      }
      const diagnostics: ShellDiagnostics = new ShellDiagnostics();
      diagnostics.shellReady = typeof data['shellReady'] === 'boolean' ? (data['shellReady'] as boolean) : false;
      diagnostics.hasRenderMathContent =
        typeof data['hasRenderMathContent'] === 'boolean' ? (data['hasRenderMathContent'] as boolean) : false;
      diagnostics.hasMathRenderStatus =
        typeof data['hasMathRenderStatus'] === 'boolean' ? (data['hasMathRenderStatus'] as boolean) : false;
      diagnostics.mathRenderStatus =
        typeof data['mathRenderStatus'] === 'string' ? (data['mathRenderStatus'] as string) : '';
      diagnostics.hasMathJax = typeof data['hasMathJax'] === 'boolean' ? (data['hasMathJax'] as boolean) : false;
      diagnostics.hasStartup = typeof data['hasStartup'] === 'boolean' ? (data['hasStartup'] as boolean) : false;
      diagnostics.hasStartupPromise =
        typeof data['hasStartupPromise'] === 'boolean' ? (data['hasStartupPromise'] as boolean) : false;
      diagnostics.hasTypesetPromise =
        typeof data['hasTypesetPromise'] === 'boolean' ? (data['hasTypesetPromise'] as boolean) : false;
      diagnostics.hasRoot = typeof data['hasRoot'] === 'boolean' ? (data['hasRoot'] as boolean) : false;
      diagnostics.rootLength = typeof data['rootLength'] === 'number' ? (data['rootLength'] as number) : 0;
      diagnostics.bodyLength = typeof data['bodyLength'] === 'number' ? (data['bodyLength'] as number) : 0;
      diagnostics.scriptCount = typeof data['scriptCount'] === 'number' ? (data['scriptCount'] as number) : 0;
      diagnostics.mjxCount = typeof data['mjxCount'] === 'number' ? (data['mjxCount'] as number) : 0;
      diagnostics.svgCount = typeof data['svgCount'] === 'number' ? (data['svgCount'] as number) : 0;
      diagnostics.readyState = typeof data['readyState'] === 'string' ? (data['readyState'] as string) : '';
      diagnostics.href = typeof data['href'] === 'string' ? (data['href'] as string) : '';
      diagnostics.title = typeof data['title'] === 'string' ? (data['title'] as string) : '';
      return diagnostics;
    } catch (_error) {
      return null;
    }
  }

  toLogString(): string {
    return `{"shellReady":${this.shellReady},"hasRenderMathContent":${this.hasRenderMathContent},` +
      `"hasMathRenderStatus":${this.hasMathRenderStatus},"mathRenderStatus":"${this.mathRenderStatus}",` +
      `"hasMathJax":${this.hasMathJax},"hasStartup":${this.hasStartup},"hasStartupPromise":${this.hasStartupPromise},` +
      `"hasTypesetPromise":${this.hasTypesetPromise},"hasRoot":${this.hasRoot},"rootLength":${this.rootLength},` +
      `"bodyLength":${this.bodyLength},"scriptCount":${this.scriptCount},"mjxCount":${this.mjxCount},` +
      `"svgCount":${this.svgCount},"readyState":"${this.readyState}","href":"${this.href}","title":"${this.title}"}`;
  }
}

function parseJavaScriptJsonObject(jsonText: string): ESObject | null {
  try {
    const parsed: Object = JSON.parse(jsonText) as Object;
    if (typeof parsed === 'string') {
      return JSON.parse(parsed as string) as ESObject;
    }
    return parsed as ESObject;
  } catch (_error) {
    return null;
  }
}
