import type { FlmRole } from '../types/models';

export function normalizeFlmRole(value: unknown): FlmRole {
  return String(value).toLowerCase() === 'guest' ? 'guest' : 'student';
}

export function rolePage(role: FlmRole, page: 'CurriculumDetails' | 'SyllabusManagement'): string {
  return `/gui/role/${role}/${page}`;
}
