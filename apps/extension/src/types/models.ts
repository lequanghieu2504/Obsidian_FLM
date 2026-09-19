export interface CurriculumMetadata {
  curriculumId: string;
  curriculumCode?: string;
  name?: string;
  englishName?: string;
  description?: string;
  decision?: string;
}

export interface Plo { code: string; description: string }

export interface CurriculumSubject {
  code: string;
  name?: string;
  semester?: string;
  credits?: string;
  prerequisite?: string;
  isPlaceholder: boolean;
}

export interface CurriculumData {
  metadata: CurriculumMetadata;
  plos: Plo[];
  subjects: CurriculumSubject[];
}

export interface ComboSummary { id: string; code: string; name?: string; href: string }
export interface ComboDetail { id: string; name?: string; note?: string; subjects: CurriculumSubject[] }

export interface SyllabusSummary {
  id: string;
  code?: string;
  name?: string;
  href: string;
  isActive: boolean;
  isApproved: boolean;
}

export interface SyllabusData {
  id: string;
  metadata: Record<string, string>;
  sections: Array<{ heading: string; headers: string[]; rows: string[][] }>;
}

export interface FailedSubject {
  code: string;
  reason: string;
}

export interface CrawlProgress {
  status: 'idle' | 'crawling' | 'cancelled' | 'complete' | 'error';
  curriculumId?: string;
  curriculumCode?: string;
  curriculumName?: string;
  seComboCount: number;
  uniqueSubjectCount: number;
  completed: number;
  failed: number;
  failures: FailedSubject[];
  currentSubject?: string;
  error?: string;
  canExport: boolean;
  canRetry: boolean;
}
