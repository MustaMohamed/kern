#!/usr/bin/env bats
# tests/scripts/floor-scan.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  mkdir -p test src .github/workflows
  printf "test('sum', () => {\n  expect(sum(1, 2)).toBe(3);\n  expect(sum(0, 0)).toBe(0);\n});\n" > test/sum.test.js
  printf "test('old', () => {\n  expect(1).toBe(1);\n});\n" > test/old.test.js
  printf "export function run() {\n  return 1;\n}\n" > src/a.js
  printf '# Readme\n' > README.md
  printf "module.exports = {\n  coverageThreshold: { global: {\n    branches: 80,\n    lines: 90,\n  } },\n};\n" > jest.config.js
  printf '{\n  "compilerOptions": {\n    "strict": true\n  }\n}\n' > tsconfig.json
  printf '{\n  "rules": {\n    "no-console": "error"\n  }\n}\n' > .eslintrc.json
  printf 'jobs:\n  test:\n    steps:\n      - run: npm ci\n      - run: npm test\n' > .github/workflows/ci.yml
  git add . && git commit --quiet -m base && git push --quiet origin main
}

scan() {
  git add -A
  git diff --cached > "$TMP/d.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/floor-scan" "$TMP/d.diff"
}

has() { printf '%s\n' "$output" | grep -qE "$1" || { echo "no match for $1 in:"; echo "$output"; false; }; }
count() { printf '%s\n' "$output" | grep -cE "$1" || true; }

@test "each floor move is reported with its class" {
  printf "test('sum', () => {\n  expect(sum(1, 2)).toBe(3);\n});\ntest.skip('later', () => {});\n" > test/sum.test.js
  rm test/old.test.js
  printf "export function run() {\n  // eslint-disable-next-line no-console\n  console.log('debug');\n  try { go(); } catch (e) {}\n  // TODO: handle errors\n  return 1;\n}\n" > src/a.js
  printf '# Readme\nTODO: write docs\n' > README.md
  scan
  [ "$status" -eq 1 ]
  has $'^src/a\\.js:2\tsilenced-checker\t'
  has $'^src/a\\.js:3\tdebug-print\t'
  has $'^src/a\\.js:4\tunfinished-work\t'
  has $'^src/a\\.js:5\tunfinished-work\t'
  has $'^test/sum\\.test\\.js:4\ttest-made-easier\t'
  has $'^test/sum\\.test\\.js:3\tassertion-removed\t'
  has $'^test/old\\.test\\.js:0\ttest-deleted\t'
  [ "$(count '^README\.md:')" -eq 0 ]
}

@test "a clean diff exits 0 with no output" {
  printf "export function run() {\n  return 2;\n}\n" > src/a.js
  scan
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "focused tests count as test-made-easier" {
  printf "test.only('sum', () => {\n  expect(sum(1, 2)).toBe(3);\n  expect(sum(0, 0)).toBe(0);\n});\n" > test/sum.test.js
  scan
  [ "$status" -eq 1 ]
  has $'^test/sum\\.test\\.js:1\ttest-made-easier\t'
}

@test "type escapes and other suppressions are silenced-checker" {
  printf "export function run(x) {\n  const a = x as any;\n  const b = x as unknown as string;\n  # pragma: no cover\n  # nosec\n  # pyright: ignore\n  // NOLINT\n  return a;\n}\n" > src/a.js
  scan
  [ "$(count $'\tsilenced-checker\t')" -eq 6 ]
}

@test "a Rust #[ignore] is test-made-easier" {
  printf '#[test]\n#[ignore]\nfn slow() {}\n' > test/slow.rs
  scan
  has $'^test/slow\\.rs:2\ttest-made-easier\t'
}

@test "a lowered coverage threshold is bar-lowered; a raised one is not" {
  sed -i.bak 's/branches: 80/branches: 70/; s/lines: 90/lines: 95/' jest.config.js && rm jest.config.js.bak
  scan
  [ "$status" -eq 1 ]
  has $'^jest\\.config\\.js:3\tbar-lowered\tthreshold branches moved from 80 to 70$'
  [ "$(count 'lines moved')" -eq 0 ]
}

@test "strict typing turned off or removed is bar-lowered" {
  printf '{\n  "compilerOptions": {\n    "strict": false\n  }\n}\n' > tsconfig.json
  scan
  has $'^tsconfig\\.json:3\tbar-lowered\t"strict": false'
  has $'^tsconfig\\.json:3\tbar-lowered\tstrict removed'
}

@test "a lint rule turned off is bar-lowered" {
  printf '{\n  "rules": {\n    "no-console": "off"\n  }\n}\n' > .eslintrc.json
  scan
  has $'^\\.eslintrc\\.json:3\tbar-lowered\t'
}

@test "a CI step removed or made non-blocking is bar-lowered" {
  printf 'jobs:\n  test:\n    continue-on-error: true\n    steps:\n      - run: npm ci\n' > .github/workflows/ci.yml
  scan
  has $'^\\.github/workflows/ci\\.yml:3\tbar-lowered\tcontinue-on-error: true'
  has $'^\\.github/workflows/ci\\.yml:5\tbar-lowered\tCI step removed: '
}

@test "a ratchet.<metric> key guards its value in both directions" {
  mkdir -p .claude
  printf 'ratchet.bundle: size.json:limit:max\nratchet.score: score.json:floor\n' > .claude/kern.local.yml
  printf '{ "limit": 100 }\n' > size.json
  printf '{ "floor": 60 }\n' > score.json
  git add size.json score.json && git commit --quiet -m sizes
  printf '{ "limit": 120 }\n' > size.json
  printf '{ "floor": 50 }\n' > score.json
  scan
  has $'^size\\.json:1\tbar-lowered\tratchet\\.bundle moved from 100 to 120$'
  has $'^score\\.json:1\tbar-lowered\tratchet\\.score moved from 60 to 50$'
}

@test "a reformatted or moved assertion is not removed" {
  printf "test('sum', () => {\n  expect(sum(0, 0)).toBe(0);\n  expect( sum(1, 2) ).toBe( 3 )\n});\n" > test/sum.test.js
  scan
  [ "$status" -eq 0 ]
  [ "$(count 'assertion-removed')" -eq 0 ]
}

@test "a renamed test file is not a deleted test" {
  git mv test/old.test.js test/older.test.js
  scan
  [ "$status" -eq 0 ]
  [ "$(count 'test-deleted')" -eq 0 ]
}

@test "content lines that start with ++ or -- are content, not headers" {
  printf 'let i = 0;\n--i;\n' > src/b.js
  git add src/b.js && git commit --quiet -m b
  printf 'let i = 0;\n++i;\nconsole.log(i);\n' > src/b.js
  scan
  has $'^src/b\\.js:3\tdebug-print\t'
  [ "$(count '^src/b\.js:2')" -eq 0 ]
}

@test "an untracked new file is scanned through its intent-to-add diff" {
  printf 'debugger;\n' > src/new.js
  git add -N src/new.js
  git diff > "$TMP/n.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/floor-scan" "$TMP/n.diff"
  has $'^src/new\\.js:1\tdebug-print\t'
}

@test "a wt-diff package is read past its header sections" {
  wt=$(bash "$KERN_ROOT/scripts/wt-new" fs 2> /dev/null)
  t0=$(bash "$KERN_ROOT/scripts/wt-snap" "$wt")
  printf "export function run() {\n  debugger;\n}\n" > "$wt/src/a.js"
  pkg=$(bash "$KERN_ROOT/scripts/wt-diff" "$wt" "$t0" --out "$TMP/p.diff" | head -n 1)
  run --separate-stderr bash "$KERN_ROOT/scripts/floor-scan" "$pkg"
  [ "$status" -eq 1 ]
  has $'^src/a\\.js:2\tdebug-print\t'
}

@test "input with no diff --git header exits 2; an unreadable input exits 2" {
  printf 'M\tsrc/a.js\n' > "$TMP/notdiff"
  run --separate-stderr bash "$KERN_ROOT/scripts/floor-scan" "$TMP/notdiff"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no diff --git header"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/floor-scan" "$TMP/missing.diff"
  [ "$status" -eq 2 ]
}

@test "suppressions in a doc file are not hits" {
  printf '# Readme\nUse `// eslint-disable` sparingly. console.log is fine in examples.\n' > README.md
  scan
  [ "$status" -eq 0 ]
}

@test "removed assertions in JUnit, Rust, unittest and testify styles are assertion-removed" {
  printf 'class FooTest {\n  void t() {\n    assertEquals(3, sum(1, 2));\n  }\n}\n' > test/FooTest.java
  mkdir -p tests
  printf '#[test]\nfn t() {\n    assert_eq!(1, 1);\n    debug_assert!(true);\n    assert_ne!(1, 2);\n}\n' > tests/t.rs
  printf 'class T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 1)\n' > test/test_a.py
  printf 'func TestA(t *testing.T) {\n\trequire.Equal(t, 1, 1)\n\tassert.Equal(t, 2, 2)\n}\n' > test/a_test.go
  git add -A && git commit --quiet -m styles
  printf 'class FooTest {\n  void t() {\n  }\n}\n' > test/FooTest.java
  printf '#[test]\nfn t() {\n}\n' > tests/t.rs
  printf 'class T(unittest.TestCase):\n    def test_a(self):\n        pass\n' > test/test_a.py
  printf 'func TestA(t *testing.T) {\n}\n' > test/a_test.go
  scan
  [ "$status" -eq 1 ]
  has $'^test/FooTest\\.java:3\tassertion-removed\t'
  has $'^tests/t\\.rs:3\tassertion-removed\t'
  has $'^tests/t\\.rs:4\tassertion-removed\t'
  has $'^tests/t\\.rs:5\tassertion-removed\t'
  has $'^test/test_a\\.py:3\tassertion-removed\t'
  has $'^test/a_test\\.go:2\tassertion-removed\t'
  has $'^test/a_test\\.go:3\tassertion-removed\t'
}

@test "a removed require('y') import in a test file is not an assertion" {
  printf "const x = require('y');\ntest('a', () => {});\n" > test/imp.test.js
  git add -A && git commit --quiet -m imp
  printf "test('a', () => {});\n" > test/imp.test.js
  scan
  [ "$(count 'assertion-removed')" -eq 0 ]
}

@test "every threshold on one line is checked" {
  printf '{ "branches": 80, "lines": 90 }\n' > package.json
  git add -A && git commit --quiet -m pkg
  printf '{ "branches": 80, "lines": 50 }\n' > package.json
  scan
  [ "$status" -eq 1 ]
  has $'^package\\.json:1\tbar-lowered\tthreshold lines moved from 90 to 50$'
  [ "$(count 'branches moved')" -eq 0 ]
}
