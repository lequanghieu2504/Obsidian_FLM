import type { SyllabusCell, SyllabusControl, SyllabusData, SyllabusSummary } from '../types/models';
import { cells, clean, dataRows, findTable, headerIndex, tableHeaders } from './dom';

function checked(row: Element, cellIndex: number): boolean {
  if (cellIndex < 0) return false;
  const input = cells(row)[cellIndex]?.querySelector('input[type="checkbox"]') as HTMLInputElement | null;
  return Boolean(input?.checked || input?.hasAttribute('checked'));
}

function controlData(element: Element): SyllabusControl {
  const tag = element.tagName.toLowerCase() as SyllabusControl['tag'];
  const name = element.getAttribute('name') ?? undefined;
  if (tag === 'select') {
    const options = Array.from(element.querySelectorAll('option')) as HTMLOptionElement[];
    let selected = options.filter((option) => option.selected || option.hasAttribute('selected'));
    if (!selected.length && !element.hasAttribute('multiple') && options.length) selected = [options[0]];
    return {
      tag,
      name,
      selectedOptions: selected.map((option) => ({ text: clean(option.textContent), value: option.getAttribute('value') ?? clean(option.textContent) })),
    };
  }
  if (tag === 'textarea') {
    const textarea = element as HTMLTextAreaElement;
    return { tag, name, value: textarea.value || clean(textarea.textContent) };
  }
  const input = element as HTMLInputElement;
  const type = (input.getAttribute('type') || 'text').toLowerCase();
  const result: SyllabusControl = { tag, type, name, value: input.value || input.getAttribute('value') || undefined };
  if (type === 'checkbox' || type === 'radio') result.checked = Boolean(input.checked || input.hasAttribute('checked'));
  return result;
}

function richCell(cell: Element, baseUrl: string): SyllabusCell {
  const controls = Array.from(cell.querySelectorAll('input, textarea, select')).map(controlData);
  const links = Array.from(cell.querySelectorAll('a[href]')).map((link) => {
    const href = link.getAttribute('href') ?? '';
    let absolute = href;
    try { absolute = new URL(href, baseUrl).href; } catch { /* Preserve the original malformed href. */ }
    return { text: clean(link.textContent), href: absolute };
  });
  const textSource = cell.cloneNode(true) as Element;
  for (const control of textSource.querySelectorAll('input, textarea, select')) control.remove();
  return { text: clean(textSource.textContent), links, controls };
}

function displayValue(cell: SyllabusCell): string {
  const controlValues = cell.controls.flatMap((control) => {
    if (control.checked !== undefined) return [String(control.checked)];
    if (control.selectedOptions) return control.selectedOptions.map((option) => option.text || option.value);
    return control.value ? [control.value] : [];
  });
  return [cell.text, ...controlValues].filter(Boolean).join(' · ');
}

function extractSyllabusMetadata(document: Document, baseUrl: string): Record<string, string> {
  const values: Record<string, string> = {};
  for (const row of document.querySelectorAll('tr')) {
    const rowCells = cells(row);
    if (rowCells.length !== 2) continue;
    const key = clean(rowCells[0].textContent).replace(/:$/, '');
    const value = displayValue(richCell(rowCells[1], baseUrl));
    if (key) values[key] = value;
  }
  for (const term of document.querySelectorAll('dt')) {
    const key = clean(term.textContent).replace(/:$/, '');
    const sibling = term.nextElementSibling;
    const value = sibling ? displayValue(richCell(sibling, baseUrl)) : '';
    if (key) values[key] = value;
  }
  return values;
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

export function extractSyllabusDetail(document: Document, id: string, baseUrl = 'https://flm.fpt.edu.vn'): SyllabusData {
  const sections = Array.from(document.querySelectorAll('table')).map((table, index) => {
    const richRows = dataRows(table).map((row) => cells(row).map((cell) => richCell(cell, baseUrl)));
    return {
      heading: clean(table.previousElementSibling?.textContent) || `Table ${index + 1}`,
      headers: tableHeaders(table),
      rows: richRows.map((row) => row.map(displayValue)),
      richRows,
    };
  }).filter((section) => section.headers.length || section.rows.length);
  return { id, metadata: extractSyllabusMetadata(document, baseUrl), sections };
}
