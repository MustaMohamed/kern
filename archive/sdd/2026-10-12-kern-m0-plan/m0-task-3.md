### Task 3: Licensing

**Files:**
- Create: `LICENSE`, `NOTICE`, `UPSTREAM.md`
- Create: `licenses/superpowers.LICENSE`, `licenses/pstack.LICENSE`, `licenses/pocock.LICENSE`, `licenses/addy.LICENSE`, `licenses/caveman.LICENSE`, `licenses/caveman.NOTICE`
- Test: `tests/licensing.test.mjs`

**Interfaces:**
- Consumes: `.upstream/<key>/` from Task 2.
- Produces: `UPSTREAM.md` table with columns `Key | Source | Version | Licence | Copyright | Commit | URL`; later tasks append to the NOTICE "File map" section as they port files (format: `- <kern path>: <key> <upstream path>`).

- [ ] **Step 1: Write the failing test**

```js
// tests/licensing.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');

function upstreamRows() {
  return read('UPSTREAM.md').split('\n')
    .filter((l) => /^\| [a-z]+ \|/.test(l))
    .map((l) => l.split('|').slice(1, -1).map((c) => c.trim()));
}

test('kern itself is MIT', () => {
  assert.match(read('LICENSE'), /^MIT License\n\nCopyright \(c\) 2026 Mustafa Mohamed/);
});

test('every upstream source has a licence file and a NOTICE entry', () => {
  const rows = upstreamRows();
  assert.deepEqual(rows.map((r) => r[0]).sort(), ['addy', 'caveman', 'pocock', 'pstack', 'superpowers']);
  const notice = read('NOTICE');
  for (const [key, , , , copyright, , url] of rows) {
    assert.ok(existsSync(new URL(`../licenses/${key}.LICENSE`, import.meta.url)), `licenses/${key}.LICENSE`);
    assert.ok(notice.includes(url), `NOTICE names ${url}`);
    assert.ok(notice.includes(copyright), `NOTICE carries "${copyright}"`);
  }
});

test('NOTICE reproduces caveman NOTICE verbatim', () => {
  assert.ok(read('NOTICE').includes(read('licenses/caveman.NOTICE').trim()));
});

test('caveman licence is Apache-2.0', () => {
  assert.match(read('licenses/caveman.LICENSE'), /Apache License\s+Version 2\.0, January 2004/);
});

test('NOTICE has a file map section', () => {
  assert.match(read('NOTICE'), /^## File map$/m);
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/licensing.test.mjs`
Expected: FAIL with `ENOENT: no such file or directory, open '.../LICENSE'`.

- [ ] **Step 3: Copy the licence texts**

```bash
mkdir -p licenses
cp .upstream/superpowers/LICENSE licenses/superpowers.LICENSE
cp .upstream/pstack/pstack/LICENSE licenses/pstack.LICENSE
cp .upstream/pocock/LICENSE licenses/pocock.LICENSE
cp .upstream/addy/LICENSE licenses/addy.LICENSE
cp .upstream/caveman/LICENSE licenses/caveman.LICENSE
cp .upstream/caveman/NOTICE licenses/caveman.NOTICE
head -3 licenses/*.LICENSE
```
Expected: four files start with `MIT License`, `licenses/caveman.LICENSE` starts with the Apache header. If `.upstream/pstack/pstack/LICENSE` is missing, stop and report: the MIT grant must be confirmed before any pstack text is ported.

- [ ] **Step 4: Write `LICENSE`**

```text
MIT License

Copyright (c) 2026 Mustafa Mohamed

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Write `UPSTREAM.md`**

```markdown
# Upstream sources

kern ports text and ideas from these sources. `scripts/fetch-upstream` clones each at its pin into `.upstream/<key>/`. Review upstream changes quarterly: `git -C .upstream/<key> fetch && git -C .upstream/<key> log --oneline <commit>..origin/HEAD`.

| Key | Source | Version | Licence | Copyright | Commit | URL |
|---|---|---|---|---|---|---|
| superpowers | obra/superpowers | 6.4.1 | MIT | Copyright (c) 2025 Jesse Vincent | 5bf4e78011075bcfc0dc295f0724994cd123ee71 | https://github.com/obra/superpowers |
| pstack | cursor/plugins, pstack/ | 0.15.17 | MIT | Copyright (c) 2026 Lauren Tan | 11713c6 | https://github.com/cursor/plugins |
| pocock | mattpocock/skills | 1.3.1 | MIT | Copyright (c) 2026 Matt Pocock | 49dd158 | https://github.com/mattpocock/skills |
| addy | addyosmani/agent-skills | 0.6.12 | MIT | Copyright (c) 2025 Addy Osmani | 1be8e34 | https://github.com/addyosmani/agent-skills |
| caveman | caveman | 3.2.0 | Apache-2.0 | Copyright 2026 Julius Brussee | installed plugin cache 3.2.0 | https://github.com/JuliusBrussee/caveman |

The `local` key in `fetch-upstream` copies the owner's adapted `recall`, `unslop`, `no-comments` and `comment-sicko` files; they are the owner's own work and need no entry here.
```

Before committing, compare each Copyright cell with line 3 of the matching `licenses/<key>.LICENSE` (or caveman's NOTICE line 2) and copy the exact wording from the licence file where it differs. The licence file is the authority.

- [ ] **Step 6: Write `NOTICE`**

Write the header, one block per source, then the caveman NOTICE verbatim, then the empty file map:

```text
kern
Copyright (c) 2026 Mustafa Mohamed
Licensed under the MIT License (see LICENSE).

kern contains material adapted from the following works. Each is used under
its licence; full texts are in licenses/.

superpowers, https://github.com/obra/superpowers
Copyright (c) 2025 Jesse Vincent. MIT License (licenses/superpowers.LICENSE).

pstack (cursor/plugins), https://github.com/cursor/plugins
Copyright (c) 2026 Lauren Tan. MIT License (licenses/pstack.LICENSE).

mattpocock/skills, https://github.com/mattpocock/skills
Copyright (c) 2026 Matt Pocock. MIT License (licenses/pocock.LICENSE).

addyosmani/agent-skills, https://github.com/addyosmani/agent-skills
Copyright (c) 2025 Addy Osmani. MIT License (licenses/addy.LICENSE).

caveman, https://github.com/JuliusBrussee/caveman
Copyright 2026 Julius Brussee. Apache License 2.0 (licenses/caveman.LICENSE).
kern's terse mode adapts ideas from caveman's mode rules and prompt parser. kern
does not use the caveman name or its other trademarks. Files changed from
caveman sources say so in their first lines. caveman's NOTICE follows.

----- caveman NOTICE -----
<paste the full content of licenses/caveman.NOTICE here, unchanged>
----- end caveman NOTICE -----

## File map
```

The angle-bracket line is an instruction to the executor, not file content: replace it with the file's text by running `sed -e '/<paste the full content/{r licenses/caveman.NOTICE' -e 'd;}' NOTICE > NOTICE.tmp && mv NOTICE.tmp NOTICE`, then confirm with `grep -c 'paste the full' NOTICE` printing `0`.

- [ ] **Step 7: Run the test to verify it passes**

Run: `node --test tests/licensing.test.mjs`
Expected: `# pass 5`, `# fail 0`.

- [ ] **Step 8: Commit**

```bash
git add -- LICENSE NOTICE UPSTREAM.md licenses tests/licensing.test.mjs
git commit -m "M0: add MIT licence, upstream licences, NOTICE and pins" -m "Apache-2.0 requires the caveman NOTICE to travel with derived work; the test keeps it verbatim."
```

---

