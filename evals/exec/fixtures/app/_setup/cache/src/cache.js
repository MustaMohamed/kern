import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

// The report's cache. Its entry sits in export-cache, the folder beside the main checkout, which every worktree of this
// repository shares. An entry of another version is ignored.
export const CACHE_VERSION = 1;

// cacheDir(): the export-cache folder beside the main checkout.
export const cacheDir = () => {
  const common = execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], { encoding: 'utf8' }).trim();
  return join(dirname(dirname(common)), 'export-cache');
};

// reportTotal(rows, dir): the cached total in dir/entry.json when that entry is of CACHE_VERSION, else the rows' totals added up.
export const reportTotal = (rows, dir = cacheDir()) => {
  const file = join(dir, 'entry.json');
  if (existsSync(file)) {
    const entry = JSON.parse(readFileSync(file, 'utf8'));
    if (entry.version === CACHE_VERSION) return entry.total;
  }
  return rows.reduce((total, row) => total + row.total, 0);
};
