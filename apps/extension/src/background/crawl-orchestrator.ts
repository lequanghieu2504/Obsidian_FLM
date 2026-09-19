import { parseHTML } from 'linkedom';
import { isAuthenticationPage } from '../extractors/auth';
import { extractComboDetail, extractComboList } from '../extractors/combo';
import { extractCurriculum } from '../extractors/curriculum';
import { extractSyllabusDetail, extractSyllabusResults } from '../extractors/syllabus';
import { PackageBuilder } from '../transport/package-builder';
import type { ComboDetail, ComboSummary, CrawlProgress, CurriculumData, SyllabusData } from '../types/models';
import { uniqueRealSubjectCodes } from '../utils/subjects';

const FLM = 'https://flm.fpt.edu.vn';
const delay = (ms: number, signal: AbortSignal) => new Promise<void>((resolve, reject) => {
  const timer = setTimeout(resolve, ms);
  signal.addEventListener('abort', () => { clearTimeout(timer); reject(signal.reason); }, { once: true });
});

interface Source { html: string; url: string }
interface FailedSubject { code: string; reason: string }

export class CrawlOrchestrator {
  private controller?: AbortController;
  private readonly sources = new Map<string, Source>();
  private curriculum?: CurriculumData;
  private combos: ComboSummary[] = [];
  private comboDetails: ComboDetail[] = [];
  private syllabi: SyllabusData[] = [];
  private failedSubjects: FailedSubject[] = [];
  private progress: CrawlProgress = { status: 'idle', seComboCount: 0, uniqueSubjectCount: 0, completed: 0, failed: 0, canExport: false, canRetry: false };

  constructor(private readonly requestDelayMs = 400, private readonly retries = 2) {}
  getProgress(): CrawlProgress { return { ...this.progress }; }
  cancel(): void { this.controller?.abort(new DOMException('Crawl cancelled', 'AbortError')); }

  async start(curriculumId: string): Promise<void> {
    this.controller?.abort();
    this.controller = new AbortController();
    this.sources.clear(); this.combos = []; this.comboDetails = []; this.syllabi = []; this.failedSubjects = [];
    this.progress = { status: 'crawling', curriculumId, seComboCount: 0, uniqueSubjectCount: 0, completed: 0, failed: 0, canExport: false, canRetry: false };
    try {
      const curriculumSource = await this.fetchPage(`${FLM}/gui/role/student/CurriculumDetails?curid=${encodeURIComponent(curriculumId)}`);
      const curriculumDocument = this.document(curriculumSource);
      const curriculum = extractCurriculum(curriculumDocument, curriculumId);
      if (!curriculum.metadata.curriculumCode && curriculum.subjects.length === 0) throw new Error('Curriculum page did not contain the expected FLM structure');
      this.curriculum = curriculum;
      this.sources.set('raw/curriculum.html', curriculumSource);
      Object.assign(this.progress, { curriculumCode: curriculum.metadata.curriculumCode, curriculumName: curriculum.metadata.name });

      const comboSource = await this.fetchPage(`${FLM}/Compo/ViewComBo?cur_id=${encodeURIComponent(curriculumId)}`);
      const combos = extractComboList(this.document(comboSource), comboSource.url);
      this.combos = combos;
      this.sources.set('raw/combo-list.html', comboSource);
      this.progress.seComboCount = combos.length;
      for (const combo of combos) {
        const source = await this.fetchPage(combo.href);
        const detail = extractComboDetail(this.document(source), combo.id);
        this.comboDetails.push(detail);
        this.sources.set(`raw/combo-details/${combo.id}.html`, source);
      }
      const subjects = uniqueRealSubjectCodes([...curriculum.subjects, ...this.comboDetails.flatMap((combo) => combo.subjects)]);
      this.progress.uniqueSubjectCount = subjects.length;
      await this.crawlSubjects(subjects);
      this.progress.status = this.controller.signal.aborted ? 'cancelled' : 'complete';
    } catch (error) {
      this.progress.status = this.controller.signal.aborted ? 'cancelled' : 'error';
      this.progress.error = error instanceof Error ? error.message : String(error);
    } finally {
      this.progress.canExport = Boolean(this.curriculum);
      this.progress.canRetry = this.failedSubjects.length > 0;
      this.progress.currentSubject = undefined;
    }
  }

  async retryFailed(): Promise<void> {
    if (!this.curriculum || !this.failedSubjects.length) return;
    this.controller = new AbortController();
    const subjects = this.failedSubjects.map(({ code }) => code);
    this.failedSubjects = [];
    this.progress.failed = 0; this.progress.status = 'crawling'; this.progress.canRetry = false;
    await this.crawlSubjects(subjects);
    this.progress.status = this.controller.signal.aborted ? 'cancelled' : 'complete';
    this.progress.canRetry = this.failedSubjects.length > 0;
    this.progress.currentSubject = undefined;
  }

  buildPackage(): Blob {
    if (!this.curriculum) throw new Error('No crawl data is available');
    const archive = new PackageBuilder();
    for (const [path, source] of this.sources) archive.addText(path, source.html);
    archive.addJson('extracted/curriculum.json', this.curriculum);
    archive.addJson('extracted/combos.json', this.combos);
    for (const combo of this.comboDetails) archive.addJson(`extracted/combo-details/${combo.id}.json`, combo);
    for (const syllabus of this.syllabi) archive.addJson(`extracted/syllabi/${syllabus.id}.json`, syllabus);
    archive.addJson('manifest.json', {
      format: 'flm-curriculum-package', version: 1, createdAt: new Date().toISOString(),
      source: FLM, curriculumId: this.curriculum.metadata.curriculumId,
      counts: { combos: this.comboDetails.length, syllabi: this.syllabi.length, failedSubjects: this.failedSubjects.length },
      failures: this.failedSubjects,
    });
    return archive.build();
  }

  private async crawlSubjects(subjects: string[]): Promise<void> {
    for (const code of subjects) {
      if (this.controller!.signal.aborted) break;
      this.progress.currentSubject = code;
      try {
        const search = await this.fetchPage(`${FLM}/gui/role/student/SyllabusManagement?searchOn=Code&keyword=${encodeURIComponent(code)}`);
        const results = extractSyllabusResults(this.document(search), search.url).filter((item) => item.isActive);
        for (const result of results) {
          if (this.sources.has(`raw/syllabi/${result.id}.html`)) continue;
          const source = await this.fetchPage(result.href);
          this.sources.set(`raw/syllabi/${result.id}.html`, source);
          this.syllabi.push(extractSyllabusDetail(this.document(source), result.id));
        }
        this.progress.completed += 1;
      } catch (error) {
        this.failedSubjects.push({ code, reason: error instanceof Error ? error.message : String(error) });
        this.progress.failed = this.failedSubjects.length;
      }
    }
  }

  private document(source: Source): Document { return parseHTML(source.html).document as unknown as Document; }

  private async fetchPage(url: string): Promise<Source> {
    let lastError: unknown;
    for (let attempt = 0; attempt <= this.retries; attempt += 1) {
      this.controller!.signal.throwIfAborted();
      if (attempt || this.sources.size) await delay(this.requestDelayMs, this.controller!.signal);
      try {
        const response = await fetch(url, { credentials: 'include', signal: this.controller!.signal, redirect: 'follow' });
        if ([401, 403, 429].includes(response.status)) throw new Error(`FLM request stopped with HTTP ${response.status}`);
        if (!response.ok) throw new Error(`FLM request failed with HTTP ${response.status}`);
        const html = await response.text();
        const source = { html, url: response.url || url };
        if (isAuthenticationPage(this.document(source), source.url)) throw new Error('FLM authentication was lost; log in again before crawling');
        return source;
      } catch (error) {
        lastError = error;
        if (error instanceof DOMException && error.name === 'AbortError') throw error;
        const message = error instanceof Error ? error.message : '';
        if (/HTTP (401|403|429)|authentication was lost/.test(message)) throw error;
      }
    }
    throw lastError instanceof Error ? lastError : new Error('FLM request failed');
  }
}
