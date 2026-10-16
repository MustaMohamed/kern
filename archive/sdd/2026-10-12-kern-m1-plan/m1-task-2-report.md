# M1 Task 2 report

Status: DONE. Brief code transcribed verbatim, no deviations.

## RED (before hooks/lib/json.sh)
```
1..7
not ok 1 json_get decodes escapes and ignores a key-like string inside a value
# (from function `setup' in test file tests/hooks/json.bats, line 8)
#   `. "$(kern_root)/hooks/lib/json.sh"' failed
# /Users/musta/Code/projects/kern/tests/hooks/json.bats: line 8: /Users/musta/Code/projects/kern/hooks/lib/json.sh: No such file or directory
```
All 7 failed in setup: json.sh: No such file or directory.

## GREEN
```
1..7
ok 1 json_get decodes escapes and ignores a key-like string inside a value
ok 2 json_get: absent key is 1, a non-string value is 1, unterminated input is 2
ok 3 json_get_raw returns objects, arrays and literals with nested braces in strings
ok 4 json_escape round-trips quotes, backslashes, tabs and newlines
ok 5 json_ok accepts one object with surrounding whitespace and rejects the rest
ok 6 ti_get reads from TOOL_INPUT
ok 7 a 200 KB value parses in under 5 seconds
```

## shellcheck (json.sh, common.bash, run-bats)
Only SC2016 (info) at json.sh:8 on the single-quoted awk program (intentional: awk, no shell expansion wanted). No other findings. CI shellchecks only scripts/fetch-upstream and scripts/ci-local today, so this does not fail CI.

## Files
tests/helpers/common.bash, tests/run-bats (chmod +x), hooks/lib/json.sh, tests/hooks/json.bats.

## Concerns
SC2016 info only; add a `# shellcheck disable=SC2016` if json.sh is later added to CI shellcheck.

## Fix round 1
json.sh END: exit 2 when value position is past the buffer (`k > n`); raw mode exit 2 when the scanned end is before the value start (`e < k`, covers `{"a":}`). `{"command":"ls" garbage` still returns 0 with `ls` (complete string). Tests: 200 KB test now puts content before file_path; new realistic-payload test (fixture pretooluse-subagent.json); new malformed test.
RED: test 9 failed (status not 2); tests 7, 8 passed before fix.
GREEN: 9 ok, 0 failures.
1..9
ok 1 json_get decodes escapes and ignores a key-like string inside a value
ok 2 json_get: absent key is 1, a non-string value is 1, unterminated input is 2
ok 3 json_get_raw returns objects, arrays and literals with nested braces in strings
ok 4 json_escape round-trips quotes, backslashes, tabs and newlines
ok 5 json_ok accepts one object with surrounding whitespace and rejects the rest
ok 6 ti_get reads from TOOL_INPUT
ok 7 a 200 KB value parses in under 5 seconds
ok 8 json_get finds tool_input.command in a realistic PreToolUse payload
ok 9 a found key with a missing or truncated value is 2 with no output
