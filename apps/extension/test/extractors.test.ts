import { parseHTML } from 'linkedom';
import { describe, expect, it } from 'vitest';
import { isAuthenticationPage } from '../src/extractors/auth';
import { extractComboDetail, extractComboList } from '../src/extractors/combo';
import { extractCurriculum, isSeComboPlaceholder } from '../src/extractors/curriculum';
import { extractSyllabusDetail, extractSyllabusResults } from '../src/extractors/syllabus';
import { uniqueRealSubjectCodes } from '../src/utils/subjects';
import { assertComboDetailHasSubjects, assertSeComboCoverage } from '../src/utils/combo-validation';
import { resolvePackageStatus } from '../src/utils/package-status';
import { normalizeFlmRole, rolePage } from '../src/utils/flm-role';
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

  it('extracts credits from the live FLM NoCredit header', () => {
    const value = extractCurriculum(doc(`<table><tr><th>Subject Code</th><th>Subject Name</th><th>Semester</th><th>NoCredit</th></tr>
      <tr><td>PRF192</td><td>Programming Fundamentals</td><td>1</td><td>3</td></tr></table>`), '3335');
    expect(value.subjects[0]).toMatchObject({ code: 'PRF192', credits: '3' });
  });

  it('extracts live PLO headers, decision number, and curriculum action links', () => {
    const value = extractCurriculum(doc(`
      <table><tr><th>Field</th><th>Value</th></tr>
        <tr><td>DecisionNo MM/dd/yyyy:</td><td>1140/QĐ-ĐHFPT dated 09/11/2026</td></tr>
        <tr><td></td><td><a href="/PO/Index?id=3335">View PO</a><a href="/Compo/ViewComBo?cur_id=3335">View Combo</a><a href="/Elective/ViewElective?cur_id=3335">View Elective</a></td></tr></table>
      <table><tr><th>#</th><th>PLO Name</th><th>PLO Description</th></tr>
        <tr><td>1</td><td>PLO1</td><td>Apply foundational knowledge</td></tr></table>`), '3335');
    expect(value.metadata.decision).toBe('1140/QĐ-ĐHFPT dated 09/11/2026');
    expect(value.metadata.links).toEqual({
      'View PO': 'https://flm.fpt.edu.vn/PO/Index?id=3335',
      'View Combo': 'https://flm.fpt.edu.vn/Compo/ViewComBo?cur_id=3335',
      'View Elective': 'https://flm.fpt.edu.vn/Elective/ViewElective?cur_id=3335',
    });
    expect(value.plos).toEqual([{ code: 'PLO1', description: 'Apply foundational knowledge' }]);
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

describe('combo structural validation', () => {
  it('requires parsed combos when the curriculum contains SE placeholders', () => {
    expect(() => assertSeComboCoverage([{ code: 'SE_COM*1', isPlaceholder: true }], [])).toThrow(/no SE combo/i);
    expect(() => assertSeComboCoverage([{ code: 'PRF192', isPlaceholder: false }], [])).not.toThrow();
  });

  it('rejects an empty selected combo detail', () => {
    const combo = { id: '340', code: 'SE_COM5.2', href: 'https://flm.fpt.edu.vn/Compo/Detail/340' };
    expect(() => assertComboDetailHasSubjects(combo, { id: '340', subjects: [] })).toThrow(/SE_COM5\.2.*340/i);
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

describe('lossless syllabus detail extraction', () => {
  it('preserves checkbox state, inputs, textarea, selected options, and links', () => {
    const document = doc(`
      <table>
        <tr><td>IsScored</td><td><input type="checkbox" checked disabled></td></tr>
        <tr><td>IsPublished</td><td><input type="checkbox" disabled></td></tr>
        <tr><td>Credit</td><td><input name="credit" value="3"></td></tr>
        <tr><td>Tools</td><td></td></tr>
        <tr><td>Note</td><td><textarea>Academic note</textarea></td></tr>
        <tr><td>Level</td><td><select><option value="1">Basic</option><option value="2" selected>Advanced</option></select></td></tr>
        <tr><td>Material</td><td><a href="/material/10">Course book</a></td></tr>
      </table>`);
    const syllabus = extractSyllabusDetail(document, '10', 'https://flm.fpt.edu.vn/gui/role/student/SyllabusDetails?sylID=10');
    expect(syllabus.metadata).toMatchObject({ IsScored: 'true', IsPublished: 'false', Credit: '3', Tools: '', Note: 'Academic note', Level: 'Advanced' });
    expect(syllabus.sections[0].rows.map((row) => row[1])).toEqual(['true', 'false', '3', '', 'Academic note', 'Advanced', 'Course book']);
    expect(syllabus.sections[0].richRows[0][1].controls[0]).toMatchObject({ type: 'checkbox', checked: true });
    expect(syllabus.sections[0].richRows[1][1].controls[0]).toMatchObject({ type: 'checkbox', checked: false });
    expect(syllabus.sections[0].richRows[5][1].controls[0].selectedOptions).toEqual([{ text: 'Advanced', value: '2' }]);
    expect(syllabus.sections[0].richRows[6][1].links).toEqual([{ text: 'Course book', href: 'https://flm.fpt.edu.vn/material/10' }]);
  });
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
  const progress = (status: 'idle' | 'crawling' | 'cancelled' | 'complete' | 'error', failed = 0) => ({
    status, seComboCount: 0, uniqueSubjectCount: 0, completed: 0, failed, failures: [], canExport: true, canRetry: failed > 0,
  });

  it('marks incomplete, failed, cancelled, and errored crawls explicitly', () => {
    expect(resolvePackageStatus(progress('complete'))).toBe('complete');
    expect(resolvePackageStatus(progress('complete', 1))).toBe('partial');
    expect(resolvePackageStatus(progress('crawling'))).toBe('partial');
    expect(resolvePackageStatus(progress('cancelled'))).toBe('cancelled');
    expect(resolvePackageStatus(progress('error'))).toBe('error');
  });

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

describe('FLM role routing', () => {
  it('supports student and guest page paths without accepting arbitrary roles', () => {
    expect(rolePage('student', 'CurriculumDetails')).toBe('/gui/role/student/CurriculumDetails');
    expect(rolePage('guest', 'SyllabusManagement')).toBe('/gui/role/guest/SyllabusManagement');
    expect(normalizeFlmRole('guest')).toBe('guest');
    expect(normalizeFlmRole('admin')).toBe('student');
  });
});
