import type { CurriculumData, CurriculumSubject, Plo } from '../types/models';
import { cells, clean, dataRows, extractLabelValues, findTable, headerIndex, lookup, tableHeaders } from './dom';

export const isComboPlaceholder = (code: string): boolean => /^[A-Z]+_COM(?:\*|\b)/i.test(code.trim());
export const isSeComboPlaceholder = (code: string): boolean => /^SE_COM(?:\*|\b)/i.test(code.trim());

export function extractCurriculum(document: Document, curriculumId: string): CurriculumData {
  const values = extractLabelValues(document);
  const subjectTable = findTable(document, ['Subject Code', 'Subject Name']);
  const ploTable = findTable(document, ['PLO']);
  const plos: Plo[] = [];
  if (ploTable) {
    const headers = tableHeaders(ploTable);
    const codeAt = Math.max(0, headerIndex(headers, 'PLO', 'PLO Code', 'Code'));
    const descriptionAt = headerIndex(headers, 'Description', 'PLO Description', 'Name');
    for (const row of dataRows(ploTable)) {
      const rowCells = cells(row);
      const code = clean(rowCells[codeAt]?.textContent);
      const description = clean(rowCells[descriptionAt >= 0 ? descriptionAt : codeAt + 1]?.textContent);
      if (code) plos.push({ code, description });
    }
  }
  const subjects: CurriculumSubject[] = [];
  if (subjectTable) {
    const headers = tableHeaders(subjectTable);
    const index = (...names: string[]) => headerIndex(headers, ...names);
    for (const row of dataRows(subjectTable)) {
      const rowCells = cells(row);
      const value = (...names: string[]) => { const at = index(...names); return at >= 0 ? clean(rowCells[at]?.textContent) : undefined; };
      const code = value('Subject Code', 'Code') ?? '';
      if (!code) continue;
      subjects.push({
        code,
        name: value('Subject Name', 'Name'),
        semester: value('Semester'),
        credits: value('Credits', 'Credit'),
        prerequisite: value('Prerequisite', 'Pre-requisite', 'Note'),
        isPlaceholder: isComboPlaceholder(code),
      });
    }
  }
  return {
    metadata: {
      curriculumId,
      curriculumCode: lookup(values, 'CurriculumCode', 'Curriculum Code', 'Code'),
      name: lookup(values, 'Name', 'Curriculum Name'),
      englishName: lookup(values, 'English Name'),
      description: lookup(values, 'Description'),
      decision: lookup(values, 'Decision'),
    },
    plos,
    subjects,
  };
}
