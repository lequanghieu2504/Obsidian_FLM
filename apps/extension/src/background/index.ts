import { CrawlOrchestrator } from './crawl-orchestrator';
import { normalizeFlmRole } from '../utils/flm-role';

const crawler = new CrawlOrchestrator();

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === 'GET_PROGRESS') { sendResponse(crawler.getProgress()); return; }
  if (message?.type === 'CANCEL_CRAWL') { crawler.cancel(); sendResponse({ ok: true }); return; }
  if (message?.type === 'START_CRAWL') {
    crawler.start(String(message.curriculumId), normalizeFlmRole(message.role)).then(() => sendResponse(crawler.getProgress()));
    return true;
  }
  if (message?.type === 'RETRY_FAILED') {
    crawler.retryFailed().then(() => sendResponse(crawler.getProgress()));
    return true;
  }
  if (message?.type === 'EXPORT_PACKAGE') {
    void (async () => {
      try {
        const bytes = new Uint8Array(await crawler.buildPackage().arrayBuffer());
        let binary = '';
        for (let offset = 0; offset < bytes.length; offset += 0x8000) binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
        const url = `data:application/zip;base64,${btoa(binary)}`;
        const id = crawler.getProgress().curriculumId ?? 'unknown';
        chrome.downloads.download({ url, filename: `curriculum-${id}.flmpkg`, saveAs: true }, () =>
          sendResponse({ ok: !chrome.runtime.lastError, error: chrome.runtime.lastError?.message }));
      } catch (error) { sendResponse({ ok: false, error: error instanceof Error ? error.message : String(error) }); }
    })();
    return true;
  }
});
