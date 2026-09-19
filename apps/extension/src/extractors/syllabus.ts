import type { SyllabusData, SyllabusSummary } from '../types/models';
import { cells, clean, dataRows, extractLabelValues, findTable, headerIndex, tableHeaders } from './dom';

function checked(row: Element, cellIndex: number): boolean {
  if (cellIndex < 0) return false;
  const input = cells(row)[cellIndex]?.querySelector('input[type="checkbox"]') as HTMLInputElement | null;
  return Boolean(input?.checked || input?.hasAttribute('checked'));
}

export function extractSyllabusResults(document: Document, baseUrl: string): SyllabusSummary[] {
  const table = findTable(document, ['IsActive']) ?? findTable(document, ['Is Active']);
  if (!table) return [];
  const headers = tableHeaders(table);
  const activeAt = headerIndex(headers, 'IsActive', 'Is Active');
  const approvedAt = headerIndex(headers, 'IsApproved', 'Is Approved');
  const codeAt = headerIndex(headers, 'Subject Code', 'Code');
  const nameAt = headerIndex(headers, 'Syllabus Name', 'Subject Name', 'Name');
  return dataRows(table).flatMap((row) => {
    const link = row.querySelector('a[href*="SyllabusDetails"]') as HTMLAnchorElement | null;
    const match = link?.getAttribute('href')?.match(/[?&]sylID=(\d+)/i);
    if (!link || !match) return [];
    const rowCells = cells(row);
    return [{
      id: match[1],
      code: codeAt >= 0 ? clean(rowCells[codeAt]?.textContent) : undefined,
      name: nameAt >= 0 ? clean(rowCells[nameAt]?.textContent) : clean(link.textContent),
      href: new URL(link.getAttribute('href')!, baseUrl).href,
      isActive: checked(row, activeAt),
      isApproved: checked(row, approvedAt),
    }];
  });
}

export function extractSyllabusDetail(document: Document, id: string): SyllabusData {
  const sections = Array.from(document.querySelectorAll('table')).map((table, index) => ({
    heading: clean(table.previousElementSibling?.textContent) || `Table ${index + 1}`,
    headers: tableHeaders(table),
    rows: dataRows(table).map((row) => cells(row).map((cell) => clean(cell.textContent))),
  })).filter((section) => section.headers.length || section.rows.length);
  return { id, metadata: extractLabelValues(document), sections };
}
