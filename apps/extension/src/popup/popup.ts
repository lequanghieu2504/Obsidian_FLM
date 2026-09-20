import type { CrawlProgress, FlmRole } from '../types/models';

type Detection = { valid: boolean; curriculumId?: string; curriculumCode?: string; curriculumName?: string; role?: FlmRole };
const element = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const crawl = element<HTMLButtonElement>('crawl');
const cancel = element<HTMLButtonElement>('cancel');
const retry = element<HTMLButtonElement>('retry');
const exportButton = element<HTMLButtonElement>('export');
let detection: Detection = { valid: false };
let timer: number | undefined;

function render(progress: CrawlProgress): void {
  element('details').hidden = false;
  const code = progress.curriculumCode ?? detection.curriculumCode;
  element('curriculum').textContent = code || (progress.curriculumId ? `ID #${progress.curriculumId}` : (detection.curriculumId ? `ID #${detection.curriculumId}` : '—'));
  element('combos').textContent = String(progress.seComboCount);
  element('subjects').textContent = String(progress.uniqueSubjectCount);
  element('completed').textContent = String(progress.completed);
  element('failed').textContent = String(progress.failed);
  const processed = progress.completed + progress.failed;
  const total = progress.uniqueSubjectCount;
  const percent = total ? Math.min(100, Math.round((processed / total) * 100)) : 0;
  element('progress').textContent = `${processed} / ${total}`;
  element('current').textContent = progress.currentSubject ? `Crawling ${progress.currentSubject}` : progress.status === 'idle' ? 'Ready to crawl' : progress.status;
  element<HTMLElement>('progress-fill').style.width = `${percent}%`;
  document.querySelector<HTMLElement>('.progress-track')?.setAttribute('aria-valuenow', String(percent));
  const statusBadge = element('status-badge');
  statusBadge.textContent = progress.status;
  statusBadge.className = `status-badge ${progress.status}`;
  const error = element('error');
  error.textContent = progress.error ?? '';
  error.hidden = !progress.error;
  const failuresPanel = element<HTMLElement>('failures-panel');
  const failures = element<HTMLUListElement>('failures');
  failures.replaceChildren(...progress.failures.map((failure) => {
    const item = document.createElement('li');
    const code = document.createElement('strong');
    code.textContent = failure.code;
    item.append(code, document.createTextNode(` — ${failure.reason}`));
    return item;
  }));
  failuresPanel.hidden = progress.failures.length === 0;
  element('failure-count').textContent = String(progress.failures.length);
  const active = progress.status === 'crawling';
  crawl.disabled = !detection.valid || active;
  cancel.disabled = !active;
  retry.disabled = active || !progress.canRetry;
  exportButton.disabled = active || !progress.canExport;
  element('export-label').textContent = progress.canExport && progress.status !== 'complete' ? 'Export partial' : 'Export';
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
    ? `Curriculum #${detection.curriculumId} ready · ${detection.role ?? 'student'}`
    : 'Open an FLM Curriculum page';
  element('page-title').textContent = detection.valid ? 'FLM Connected' : 'No Curriculum Detected';
  element('page-card').className = `page-card ${detection.valid ? 'valid' : 'invalid'}`;
  await refresh();
}

crawl.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'START_CRAWL', curriculumId: detection.curriculumId, role: detection.role }); void refresh(); });
cancel.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'CANCEL_CRAWL' }); void refresh(); });
retry.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'RETRY_FAILED' }); void refresh(); });
exportButton.addEventListener('click', () => { void chrome.runtime.sendMessage({ type: 'EXPORT_PACKAGE' }); });
void initialize();
