import type { ComboDetail, ComboSummary, CurriculumSubject } from '../types/models';

const isSePlaceholder = (code: string): boolean => /^SE_COM(?:\*|\b)/i.test(code.trim());

export function assertSeComboCoverage(subjects: CurriculumSubject[], combos: ComboSummary[]): void {
  if (subjects.some((subject) => isSePlaceholder(subject.code)) && combos.length === 0) {
    throw new Error('Curriculum contains SE_COM placeholders, but no SE combo could be parsed from the combo list');
  }
}

export function assertComboDetailHasSubjects(combo: ComboSummary, detail: ComboDetail): void {
  if (detail.subjects.length === 0) {
    throw new Error(`SE combo ${combo.code} (ID ${combo.id}) did not contain a recognizable subject table`);
  }
}
