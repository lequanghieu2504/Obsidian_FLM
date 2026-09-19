import type { CrawlProgress } from '../types/models';

type Detection = { valid: boolean; curriculumId?: string; curriculumCode?: string; curriculumName?: string };
const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const crawl = element<HTMLButtonElement>('crawl');
const cancel = element<HTMLButtonElement>('cancel');
const retry = element<HTMLButtonElement>('retry');
const exportButton = element<HTMLButtonElement>('export');
let detection: Detection = { valid: false };
let timer: number | undefined;

function render(progress: CrawlProgress): void {
  element('details').hidden = false;
  element('curriculum').textContent = [progress.curriculumCode ?? detection.curriculumCode, progress.curriculumName ?? detection.curriculumName, progress.curriculumId ?? detection.curriculumId].filter(Boolean).join(' · ');
  element('combos').textContent = String(progress.seComboCount);
  element('subjects').textContent = String(progress.uniqueSubjectCount);
  element('progress').textContent = `${progress.completed} completed · ${progress.failed} failed`;
  element('current').textContent = progress.currentSubject ?? progress.status;
  element('error').textContent = progress.error ?? '';
  const active = progress.status === 'crawling';
  crawl.disabled = !detection.valid || active;
  cancel.disabled = !active;
  retry.disabled = active || !progress.canRetry;
  exportButton.disabled = active || !progress.canExport;
  if (active && !timer) timer = window.setInterval(refresh, 500);
  if (!active && timer) { clearInterval(timer); timer = undefined; }
}

async function refresh(): Promise<void> { render(await chrome.runtime.sendMessage({ type: 'GET_PROGRESS' })); }

async function initialize(): Promise<void> {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  try {
    detection = tab.id ? await chrome.tabs.sendMessage(tab.id, { type: 'DETECT_CURRICULUM_PAGE' }) : { valid: false };
  } catch {
    // A tab that was already open when the extension was installed/reloaded may
    // not have the declarative content script yet. Inject it once and retry so
    // users do not have to guess which reload order Chrome expects.
    if (tab.id && /^https?:\/\/flm\.fpt\.edu\.vn\//i.test(tab.url ?? '')) {
      try {
        await chrome.scripting.executeScript({ target: { tabId: tab.id }, files: ['content.js'] });
        detection = await chrome.tabs.sendMessage(tab.id, { type: 'DETECT_CURRICULUM_PAGE' });
      } catch { detection = { valid: false }; }
    } else {
      detection = { valid: false };
    }
  }
  element('page-status').textContent = detection.valid
    ? `Curriculum detected (ID ${detection.curriculumId})`
    : 'Open an FLM Curriculum Details or Combo Management page before crawling.';
  await refresh();
}

crawl.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'START_CRAWL', curriculumId: detection.curriculumId }); void refresh(); });
cancel.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'CANCEL_CRAWL' }); void refresh(); });
retry.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'RETRY_FAILED' }); void refresh(); });
exportButton.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'EXPORT_PACKAGE' }); });
void initialize();
