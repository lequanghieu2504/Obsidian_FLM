import type { ComboDetail, ComboSummary, CurriculumSubject } from '../types/models';
import { cells, clean, dataRows, extractLabelValues, findTable, headerIndex, lookup, tableHeaders } from './dom';

export const isSeCombo = (code: string): boolean => /^SE_COM(?:\d|\.|$)/i.test(code.trim());

export function extractComboList(document: Document, baseUrl: string): ComboSummary[] {
  const table = findTable(document, ['Combo ID', 'Combo Name']) ?? findTable(document, ['Combo Name']);
  if (!table) return [];
  const headers = tableHeaders(table);
  const idAt = headerIndex(headers, 'Combo ID', 'ID');
  const nameAt = headerIndex(headers, 'Combo Name', 'Name');
  const combos: ComboSummary[] = [];
  for (const row of dataRows(table)) {
    const link = row.querySelector('a[href*="/Compo/Detail/"]') as HTMLAnchorElement | null;
    if (!link) continue;
    const match = link.getAttribute('href')?.match(/\/Compo\/Detail\/(\d+)/i);
    const name = clean(cells(row)[nameAt]?.textContent || link.textContent);
    const code = name.match(/SE_COM[\w.]*/i)?.[0] ?? clean(cells(row)[idAt]?.textContent);
    if (!match || !isSeCombo(code)) continue;
    combos.push({ id: match[1], code, name, href: new URL(link.getAttribute('href')!, baseUrl).href });
  }
  return combos;
}

export function extractComboDetail(document: Document, id: string): ComboDetail {
  const values = extractLabelValues(document);
  const table = findTable(document, ['Subject Code', 'Subject Name']);
  const subjects: CurriculumSubject[] = [];
  if (table) {
    const headers = tableHeaders(table);
    const at = (...names: string[]) => headerIndex(headers, ...names);
    for (const row of dataRows(table)) {
      const rowCells = cells(row);
      const value = (...names: string[]) => { const index = at(...names); return index >= 0 ? clean(rowCells[index]?.textContent) : undefined; };
      const code = value('Subject Code', 'Code') ?? '';
      if (code) subjects.push({ code, name: value('Subject Name', 'Name'), semester: value('Semester'), prerequisite: value('Note'), isPlaceholder: false });
    }
  }
  return { id, name: lookup(values, 'Combo Name', 'Name'), note: lookup(values, 'Note'), subjects };
}
