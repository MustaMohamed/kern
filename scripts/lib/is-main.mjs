// True when the importing module is the script Node was started with, comparing real paths so a symlinked path still counts.
import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export function isMain(importMetaUrl) {
  if (!process.argv[1]) return false;
  try {
    return realpathSync(process.argv[1]) === realpathSync(fileURLToPath(importMetaUrl));
  } catch {
    return false;
  }
}
