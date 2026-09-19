import type { CrawlProgress } from '../types/models';

export type PackageStatus = 'complete' | 'partial' | 'cancelled' | 'error';

export function resolvePackageStatus(progress: CrawlProgress): PackageStatus {
  if (progress.status === 'cancelled') return 'cancelled';
  if (progress.status === 'error') return 'error';
  if (progress.failed > 0 || progress.status !== 'complete') return 'partial';
  return 'complete';
}
