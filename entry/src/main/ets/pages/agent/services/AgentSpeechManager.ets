import textToSpeech from '@hms.ai.textToSpeech';
import { ChatMessage } from '../models/ChatModels';
import { AgentTextUtils } from '../utils/AgentTextUtils';

export interface AgentSpeechManagerHost {
  speakingMessageId: string;
  statusText: string;
  ttsEngine: textToSpeech.TextToSpeechEngine | null;

  getMessageById(messageId: string): ChatMessage | null;
  createMessageId(prefix: string): string;
  stringifyError(error: Object): string;
  showToast(message: string): void;
}

export class AgentSpeechManager {
  static async toggleSpeakMessage(host: AgentSpeechManagerHost, messageId: string): Promise<void> {
    if (host.speakingMessageId === messageId) {
      AgentSpeechManager.stopSpeakingMessage(host, true);
      return;
    }

    const message: ChatMessage | null = host.getMessageById(messageId);
    if (message === null) {
      return;
    }

    const speechText: string = AgentTextUtils.buildSpeechText(
      message.rawContent.length > 0 ? message.rawContent : message.visibleContent
    );
    if (speechText.length === 0) {
      host.showToast('当前回复还没有可播报的内容');
      return;
    }

    try {
      const engine: textToSpeech.TextToSpeechEngine = await AgentSpeechManager.ensureSpeechEngine(host);
      if (engine.isBusy()) {
        engine.stop();
      }
      host.speakingMessageId = messageId;
      engine.speak(speechText, {
        requestId: host.createMessageId(`tts-${messageId}`)
      });
      host.statusText = '正在播报这条回复。';
    } catch (error) {
      host.speakingMessageId = '';
      host.statusText = `播报失败：${host.stringifyError(error as Object)}`;
      host.showToast('播报失败，请确认设备支持语音播报');
    }
  }

  static stopSpeakingMessage(host: AgentSpeechManagerHost, showToast: boolean): void {
    if (host.ttsEngine !== null) {
      try {
        if (host.ttsEngine.isBusy()) {
          host.ttsEngine.stop();
        }
      } catch (_error) {
      }
    }
    host.speakingMessageId = '';
    if (showToast) {
      host.showToast('已停止播报');
    }
  }

  static shutdownSpeechEngine(host: AgentSpeechManagerHost): void {
    AgentSpeechManager.stopSpeakingMessage(host, false);
    if (host.ttsEngine === null) {
      return;
    }
    try {
      host.ttsEngine.shutdown();
    } catch (_error) {
    }
    host.ttsEngine = null;
  }

  private static async ensureSpeechEngine(host: AgentSpeechManagerHost): Promise<textToSpeech.TextToSpeechEngine> {
    if (host.ttsEngine !== null) {
      return host.ttsEngine;
    }

    let selectedVoice: textToSpeech.VoiceInfo | null = null;
    try {
      const voices: Array<textToSpeech.VoiceInfo> = await textToSpeech.listVoices({
        requestId: host.createMessageId('tts-voices'),
        online: 0
      });
      selectedVoice = AgentSpeechManager.selectPreferredVoice(voices);
    } catch (_error) {
      selectedVoice = null;
    }

    const engine: textToSpeech.TextToSpeechEngine = await textToSpeech.createEngine({
      language: selectedVoice !== null ? selectedVoice.language : 'zh-CN',
      person: selectedVoice !== null ? selectedVoice.person : 0,
      online: 0
    });

    const listener: textToSpeech.SpeakListener = {
      onStart: (_requestId: string, _response: textToSpeech.StartResponse): void => {
        host.statusText = '正在播报这条回复。';
      },
      onComplete: (_requestId: string, _response: textToSpeech.CompleteResponse): void => {
        host.speakingMessageId = '';
        host.statusText = '播报完成。';
      },
      onStop: (_requestId: string, _response: textToSpeech.StopResponse): void => {
        host.speakingMessageId = '';
        host.statusText = '已停止播报。';
      },
      onError: (_requestId: string, _errorCode: number, errorMessage: string): void => {
        host.speakingMessageId = '';
        host.statusText = `播报失败：${errorMessage}`;
        host.showToast('播报失败，请确认设备支持语音播报');
      }
    };
    engine.setListener(listener);
    host.ttsEngine = engine;
    return engine;
  }

  private static selectPreferredVoice(voices: Array<textToSpeech.VoiceInfo>): textToSpeech.VoiceInfo | null {
    if (voices.length === 0) {
      return null;
    }

    for (let index: number = 0; index < voices.length; index++) {
      if (voices[index].language === 'zh-CN') {
        return voices[index];
      }
    }
    for (let index: number = 0; index < voices.length; index++) {
      if (voices[index].language.startsWith('zh')) {
        return voices[index];
      }
    }
    return voices[0];
  }
}
