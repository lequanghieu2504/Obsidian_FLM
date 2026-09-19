import { parseHTML } from 'linkedom';
import { describe, expect, it } from 'vitest';
import { isAuthenticationPage } from '../src/extractors/auth';
import { extractComboDetail, extractComboList } from '../src/extractors/combo';
import { extractCurriculum, isSeComboPlaceholder } from '../src/extractors/curriculum';
import { extractSyllabusResults } from '../src/extractors/syllabus';
import { uniqueRealSubjectCodes } from '../src/utils/subjects';
import { PackageBuilder } from '../src/transport/package-builder';

const doc = (html: string) => parseHTML(html).document as unknown as Document;

describe('curriculum extraction', () => {
  const curriculum = doc(`
    <table><tr><td>CurriculumCode</td><td>SE_AI_2026</td></tr><tr><td>Name</td><td>Artificial Intelligence</td></tr>
      <tr><td>English Name</td><td>AI Programme</td></tr><tr><td>Description</td><td>Complete academic description.</td></tr></table>
    <table><tr><th>PLO</th><th>Description</th></tr><tr><td>PLO1</td><td>Apply foundational knowledge</td></tr></table>
    <table><tr><th>ID</th><th>Subject Code</th><th>Subject Name</th><th>Semester</th><th>Credits</th><th>Prerequisite</th></tr>
      <tr><td>1</td><td>CEA201</td><td>Computer Architecture</td><td>2</td><td>3</td><td>CSI106</td></tr>
      <tr><td>2</td><td>SE_COM*2</td><td>AI combo</td><td>5</td><td></td><td>Choose one</td></tr>
      <tr><td>3</td><td>PHE_COM*1</td><td>Physical education</td><td>1</td><td></td><td></td></tr>
    </table>`);

  it('extracts metadata, PLOs, subjects, and placeholders by table headers', () => {
    const value = extractCurriculum(curriculum, '3335');
    expect(value.metadata).toMatchObject({ curriculumId: '3335', curriculumCode: 'SE_AI_2026', name: 'Artificial Intelligence', description: 'Complete academic description.' });
    expect(value.plos).toEqual([{ code: 'PLO1', description: 'Apply foundational knowledge' }]);
    expect(value.subjects[0]).toMatchObject({ code: 'CEA201', semester: '2', credits: '3', prerequisite: 'CSI106', isPlaceholder: false });
    expect(value.subjects.slice(1).every((subject) => subject.isPlaceholder)).toBe(true);
    expect(isSeComboPlaceholder('SE_COM*4_ELE')).toBe(true);
    expect(isSeComboPlaceholder('PHE_COM*1')).toBe(false);
  });

  it('handles missing and malformed tables without throwing', () => {
    expect(extractCurriculum(doc('<table><tr><td>Name</td><td>Only metadata</td></tr></table>'), '9')).toMatchObject({ plos: [], subjects: [] });
  });
});

describe('combo extraction', () => {
  it('uses real links and retains only the SE_COM family', () => {
    const document = doc(`<table><tr><th>Combo ID</th><th>Combo Name</th><th>Action</th></tr>
      <tr><td>1</td><td>SE_COM5.2 - AI</td><td><a href="/Compo/Detail/340?curriculumID=3335">View</a></td></tr>
      <tr><td>2</td><td>PHE_COM1</td><td><a href="/Compo/Detail/341?curriculumID=3335">View</a></td></tr>
      <tr><td>3</td><td>OTHER</td><td><a href="/Compo/Detail/342?curriculumID=3335">View</a></td></tr></table>`);
    expect(extractComboList(document, 'https://flm.fpt.edu.vn/Compo/ViewComBo?cur_id=3335')).toEqual([
      { id: '340', code: 'SE_COM5.2', name: 'SE_COM5.2 - AI', href: 'https://flm.fpt.edu.vn/Compo/Detail/340?curriculumID=3335' },
    ]);
  });

  it('extracts combo metadata and preserves mixed-case codes', () => {
    const document = doc(`<table><tr><td>Combo Name</td><td>SE_COM5.2</td></tr><tr><td>Note</td><td>Choose this track</td></tr></table>
      <table><tr><th>ID</th><th>Subject Code</th><th>Subject Name</th><th>Semester</th><th>Note</th></tr>
      <tr><td>1</td><td>PRP201c</td><td>Python Programming</td><td>5</td><td>Core</td></tr></table>`);
    expect(extractComboDetail(document, '340')).toMatchObject({ id: '340', name: 'SE_COM5.2', note: 'Choose this track', subjects: [{ code: 'PRP201c', semester: '5' }] });
  });
});

describe('subject collection', () => {
  it('deduplicates case-insensitively, preserves first casing, and excludes all placeholders', () => {
    const subject = (code: string) => ({ code, isPlaceholder: false });
    expect(uniqueRealSubjectCodes([subject('PRP201c'), subject('prp201C'), subject('CEA201'), subject('SE_COM*1'), subject('PHE_COM*2')])).toEqual(['PRP201c', 'CEA201']);
  });
});

describe('syllabus result extraction', () => {
  it('reads active and approved values from checkbox state and keeps all rows', () => {
    const document = doc(`<table><tr><th>Subject Code</th><th>Name</th><th>IsActive</th><th>IsApproved</th><th>Action</th></tr>
      <tr><td>PRP201c</td><td>Python</td><td><input type="checkbox" checked disabled></td><td><input type="checkbox" disabled></td><td><a href="/gui/role/student/SyllabusDetails?sylID=10">View</a></td></tr>
      <tr><td>PRP201c</td><td>Old Python</td><td><input type="checkbox" disabled></td><td><input type="checkbox" checked disabled></td><td><a href="/gui/role/student/SyllabusDetails?sylID=9">View</a></td></tr></table>`);
    const results = extractSyllabusResults(document, 'https://flm.fpt.edu.vn');
    expect(results.map(({ id, isActive, isApproved }) => ({ id, isActive, isApproved }))).toEqual([
      { id: '10', isActive: true, isApproved: false }, { id: '9', isActive: false, isApproved: true },
    ]);
    expect(results.filter((result) => result.isActive).map((result) => result.id)).toEqual(['10']);
  });

  it('returns no results for a missing result table', () => expect(extractSyllabusResults(doc('<p>none</p>'), 'https://flm.fpt.edu.vn')).toEqual([]));
});

describe('authentication detection', () => {
  it('detects a structural login form and a login redirect', () => {
    const login = doc('<form><input name="username"><input type="password"><button type="submit">Continue</button></form>');
    expect(isAuthenticationPage(login, 'https://flm.fpt.edu.vn/Account/Login')).toBe(true);
    expect(isAuthenticationPage(login, 'https://flm.fpt.edu.vn/gui/role/student/CurriculumDetails?curid=1')).toBe(true);
  });

  it('does not reject authenticated pages merely containing login-related text', () => {
    expect(isAuthenticationPage(doc('<main>Last login: today. Sign in history is available.</main>'), 'https://flm.fpt.edu.vn/gui/role/student/CurriculumDetails?curid=1')).toBe(false);
  });
});

describe('package builder', () => {
  it('creates a ZIP-compatible single-file package', async () => {
    const archive = new PackageBuilder();
    archive.addJson('manifest.json', { version: 1 });
    archive.addText('raw/curriculum.html', '<main>FLM</main>');
    const bytes = new Uint8Array(await archive.build().arrayBuffer());
    expect(Array.from(bytes.slice(0, 4))).toEqual([0x50, 0x4b, 0x03, 0x04]);
    expect(new TextDecoder().decode(bytes)).toContain('raw/curriculum.html');
    expect(Array.from(bytes.slice(-22, -18))).toEqual([0x50, 0x4b, 0x05, 0x06]);
  });
});
