import type { CurriculumSubject } from '../types/models';
import { isComboPlaceholder } from '../extractors/curriculum';

export function uniqueRealSubjectCodes(subjects: CurriculumSubject[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const subject of subjects) {
    const key = subject.code.trim().toLowerCase();
    if (!key || isComboPlaceholder(subject.code) || seen.has(key)) continue;
    seen.add(key);
    result.push(subject.code.trim());
  }
  return result;
}
