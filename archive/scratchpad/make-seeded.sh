#!/usr/bin/env bash
# Writes evals/seeded-diffs/base/ and one <id>.diff per seeded move or decoy. Run once from the repo root.
set -euo pipefail
out=$PWD/evals/seeded-diffs
rm -rf "$out/base" "$out"/*.diff
mkdir -p "$out/base/src" "$out/base/test" "$out/base/.github/workflows"
b=$out/base
printf "import { sum } from '../src/sum.js';\ntest('sum', () => {\n  expect(sum(1, 2)).toBe(3);\n  expect(sum(0, 0)).toBe(0);\n});\n" > "$b/test/sum.test.js"
printf "test('old', () => {\n  expect(1).toBe(1);\n});\n" > "$b/test/old.test.js"
printf "export function sum(a, b) {\n  let i = 0;\n  --i;\n  return a + b;\n}\n" > "$b/src/sum.js"
printf '# Sum\n\nAdds two numbers.\n' > "$b/README.md"
printf "module.exports = {\n  coverageThreshold: { global: {\n    branches: 80,\n    lines: 90,\n  } },\n};\n" > "$b/jest.config.js"
printf '{\n  "compilerOptions": {\n    "strict": true\n  }\n}\n' > "$b/tsconfig.json"
printf 'jobs:\n  test:\n    steps:\n      - run: npm ci\n      - run: npm test\n' > "$b/.github/workflows/ci.yml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# case ID: a fresh repo from base, the edit in the function body run in it, the staged diff saved as ID.diff.
case_() {
  local id=$1
  rm -rf "$work/r" && cp -R "$b" "$work/r"
  (cd "$work/r" && git init -q && git add -A && git -c user.email=s@example.com -c user.name=s commit -q -m base && "edit_$id" && git add -A && git diff --cached) > "$out/$id.diff"
}
# before FILE LINE NEW: insert NEW above the line equal to LINE. swap FILE LINE NEW: replace that line.
before() { awk -v at="$2" -v add="$3" '$0 == at { print add } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
swap() { awk -v at="$2" -v to="$3" '$0 == at { print to; next } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
R='  return a + b;'
edit_s01-skip() { printf "test.skip('later', () => {});\n" >> test/sum.test.js; }
edit_s02-assert-removed() { swap test/sum.test.js '  expect(sum(0, 0)).toBe(0);' ''; grep -v '^$' test/sum.test.js > t && mv t test/sum.test.js; }
edit_s03-test-deleted() { rm test/old.test.js; }
edit_s04-ts-ignore() { before src/sum.js "$R" '  // @ts-ignore'; }
edit_s05-as-any() { swap src/sum.js "$R" '  return (a as any) + b;'; }
edit_s06-empty-catch() { before src/sum.js "$R" '  try { check(a); } catch (e) {}'; }
edit_s07-debug() { before src/sum.js "$R" '  console.log(a, b);'; }
edit_s08-coverage-lowered() { swap jest.config.js '    branches: 80,' '    branches: 70,'; }
edit_s09-strict-off() { swap tsconfig.json '    "strict": true' '    "strict": false'; }
edit_s10-ci-nonblocking() { before .github/workflows/ci.yml '    steps:' '    continue-on-error: true'; }
edit_s11-unknown-sha() { before src/sum.js "$R" '  // fixed in deadbee1cafe'; }
edit_s12-absolute-claim() { before src/sum.js "$R" '  // sum is never called before init'; }
edit_d01-reformatted-assert() { swap test/sum.test.js '  expect(sum(1, 2)).toBe(3);' '  expect( sum(1, 2) ).toBe( 3 )'; }
edit_d02-renamed-test() { git mv test/old.test.js test/legacy.test.js; }
edit_d03-doc-todo() { printf 'TODO: document the overflow case.\n' >> README.md; }
edit_d04-hex-colour() { printf "export const colour = '#a1b2c3d4';\n" >> src/sum.js; }
edit_d05-uuid() { printf "export const id = '123e4567-e89b-12d3-a456-426614174000';\n" >> src/sum.js; }
edit_d06-moved-assert() { swap test/sum.test.js '  expect(sum(1, 2)).toBe(3);' '  expect(sum(0, 0)).toBe(0);'; awk 'NR == 4 { print "  expect(sum(1, 2)).toBe(3);"; next } { print }' test/sum.test.js > t && mv t test/sum.test.js; }
edit_d07-decrement() { swap src/sum.js '  --i;' '  ++i;'; }
edit_d08-threshold-raised() { swap jest.config.js '    lines: 90,' '    lines: 95,'; }
for id in s01-skip s02-assert-removed s03-test-deleted s04-ts-ignore s05-as-any s06-empty-catch s07-debug \
  s08-coverage-lowered s09-strict-off s10-ci-nonblocking s11-unknown-sha s12-absolute-claim \
  d01-reformatted-assert d02-renamed-test d03-doc-todo d04-hex-colour d05-uuid d06-moved-assert d07-decrement d08-threshold-raised; do
  case_ "$id"
done
