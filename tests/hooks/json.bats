#!/usr/bin/env bats
# hooks/lib/json.sh: string decoding, raw values, escaping, malformed input.

load ../helpers/common

setup() {
  # shellcheck source=hooks/lib/json.sh
  . "$(kern_root)/hooks/lib/json.sh"
}

@test "json_get decodes escapes and ignores a key-like string inside a value" {
  KERN_INPUT='{"description":"has \"command\": inside","command":"git commit -m \"a b\"\nnext \\ end"}'
  run json_get command
  [ "$status" -eq 0 ]
  [ "$output" = 'git commit -m "a b"
next \ end' ]
}

@test "json_get: absent key is 1, a non-string value is 1, unterminated input is 2" {
  KERN_INPUT='{"n":5}'
  run json_get missing
  [ "$status" -eq 1 ]
  run json_get n
  [ "$status" -eq 1 ]
  KERN_INPUT='{"a":"open'
  run json_get a
  [ "$status" -eq 2 ]
}

@test "json_get_raw returns objects, arrays and literals with nested braces in strings" {
  KERN_INPUT='{"tool_input":{"command":"echo }","x":[1,{"y":"]"}]},"n":12,"b":true}'
  run json_get_raw tool_input
  [ "$output" = '{"command":"echo }","x":[1,{"y":"]"}]}' ]
  run json_get_raw n
  [ "$output" = 12 ]
  run json_get_raw b
  [ "$output" = true ]
}

@test "json_escape round-trips quotes, backslashes, tabs and newlines" {
  run bash -c ". '$(kern_root)/hooks/lib/json.sh'; printf 'a \"q\"\tb\\\\c\nd' | json_escape"
  [ "$output" = 'a \"q\"\tb\\c\nd' ]
}

@test "json_escape output parses as a JSON string for every byte below 0x20" {
  s='a "q" \ b'
  for i in $(seq 1 31); do
    # shellcheck disable=SC2059 # the format is the octal escape
    printf -v c "\\$(printf '%03o' "$i")"
    s="$s$c."
  done
  printf '%s' "$s" >"$BATS_TEST_TMPDIR/raw"
  printf '"%s"' "$(printf '%s' "$s" | json_escape)" >"$BATS_TEST_TMPDIR/json"
  run node -e 'const fs = require("fs");
    process.exit(JSON.parse(fs.readFileSync(process.argv[1], "utf8")) === fs.readFileSync(process.argv[2], "utf8") ? 0 : 3)' \
    "$BATS_TEST_TMPDIR/json" "$BATS_TEST_TMPDIR/raw"
  [ "$status" -eq 0 ]
}

@test "json_ok accepts one object with surrounding whitespace and rejects the rest" {
  KERN_INPUT='  {"a":1}
'
  run json_ok
  [ "$status" -eq 0 ]
  KERN_INPUT='[1]'
  run json_ok
  [ "$status" -eq 1 ]
  KERN_INPUT=''
  run json_ok
  [ "$status" -eq 1 ]
}

@test "ti_get reads from TOOL_INPUT" {
  TOOL_INPUT='{"file_path":"/a b/c"}'
  run ti_get file_path
  [ "$output" = "/a b/c" ]
}

@test "a 200 KB value parses in under 5 seconds" {
  big=$(head -c 200000 /dev/zero | tr '\0' 'x')
  KERN_INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"$big\",\"file_path\":\"/f\"}}"
  start=$(date +%s)
  run json_get file_path
  [ "$output" = /f ]
  [ $(($(date +%s) - start)) -lt 5 ]
}

@test "json_get finds tool_input.command in a realistic PreToolUse payload" {
  KERN_INPUT=$(cat "$(kern_root)/tests/fixtures/payloads/pretooluse-subagent.json")
  run json_get command
  [ "$status" -eq 0 ]
  [ "$output" = "git -C /tmp/kern-fixture log --oneline -1" ]
}

@test "a found key with a missing or truncated value is 2 with no output" {
  KERN_INPUT='{"command":'
  run json_get command
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  KERN_INPUT='{"a":'
  run json_get_raw a
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  KERN_INPUT='{"a":}'
  run json_get_raw a
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "a 400 KB value scans in linear time: an absent key and tool_input each take about a second at most" {
  big=$(head -c 400000 /dev/zero | tr '\0' 'x')
  KERN_INPUT="{\"tool_name\":\"Write\",\"tool_input\":{\"content\":\"$big\",\"file_path\":\"/f\"}}"
  start=$(date +%s)
  run json_get agent_type
  [ "$status" -eq 1 ]
  [ $(($(date +%s) - start)) -le 1 ]
  start=$(date +%s)
  run json_get_raw tool_input
  [ "$status" -eq 0 ]
  [ ${#output} -gt 400000 ]
  [ $(($(date +%s) - start)) -le 1 ]
}

@test "589 KB of structural input outside strings scans in linear time" {
  nums=$(head -c 300000 /dev/zero | tr '\0' '1' | sed 's/1/1,/g')
  KERN_INPUT="{\"tool_name\":\"mcp__x\",\"tool_input\":{\"a\":[${nums}1]}}"
  [ ${#KERN_INPUT} -gt 589000 ]
  start=$(date +%s)
  run json_get agent_type
  [ "$status" -eq 1 ]
  [ $(($(date +%s) - start)) -le 2 ]
}
