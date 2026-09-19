export type DocumentFactory = (html: string) => Document;

export const clean = (value: string | null | undefined): string =>
  (value ?? '').replace(/\s+/g, ' ').trim();

export const normalizeHeader = (value: string): string =>
  clean(value).toLowerCase().replace(/[^a-z0-9]+/g, '');

export const cells = (row: Element): HTMLTableCellElement[] =>
  Array.from(row.querySelectorAll(':scope > th, :scope > td')) as HTMLTableCellElement[];

export const tableHeaders = (table: Element): string[] => {
  const row = table.querySelector('thead tr') ?? table.querySelector('tr');
  return row ? cells(row).map((cell) => normalizeHeader(cell.textContent ?? '')) : [];
};

export function findTable(document: Document, requiredHeaders: string[]): HTMLTableElement | undefined {
  const wanted = requiredHeaders.map(normalizeHeader);
  return Array.from(document.querySelectorAll('table')).find((table) => {
    const headers = tableHeaders(table);
    return wanted.every((header) => headers.includes(header));
  }) as HTMLTableElement | undefined;
}

export function headerIndex(headers: string[], ...names: string[]): number {
  const normalized = names.map(normalizeHeader);
  return headers.findIndex((header) => normalized.includes(header));
}

export function dataRows(table: Element): HTMLTableRowElement[] {
  const rows = Array.from(table.querySelectorAll('tr')) as HTMLTableRowElement[];
  const headerRow = table.querySelector('thead tr') ?? rows.find((row) => row.querySelector(':scope > th'));
  return rows.filter((row) => row !== headerRow && cells(row).some((cell) => clean(cell.textContent) || cell.querySelector('input, textarea, select')));
}

export function extractLabelValues(document: ParentNode): Record<string, string> {
  const values: Record<string, string> = {};
  for (const row of document.querySelectorAll('tr')) {
    const rowCells = cells(row);
    if (rowCells.length !== 2) continue;
    const key = clean(rowCells[0].textContent).replace(/:$/, '');
    const value = clean(rowCells[1].textContent);
    if (key && value) values[key] = value;
  }
  for (const element of document.querySelectorAll('dt')) {
    const key = clean(element.textContent).replace(/:$/, '');
    const value = clean(element.nextElementSibling?.textContent);
    if (key && value) values[key] = value;
  }
  return values;
}

export const lookup = (values: Record<string, string>, ...labels: string[]): string | undefined => {
  const entries = Object.entries(values);
  return entries.find(([key]) => labels.some((label) => normalizeHeader(key) === normalizeHeader(label)))?.[1];
};
