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

@test "decode turns \u0001 to \u007f into the character" {
  # Each escape in lower and upper hex case; \u0001 stays the byte 0x01, which decode uses for an
  # escaped backslash while it works, and \u0022 and \u005c give a quote and a backslash.
  local i o c hex json want
  for f in '%04x' '%04X'; do
    json="" want=""
    for i in $(seq 1 127); do
      printf -v hex "$f" "$i"
      printf -v o '%03o' "$i"
      # shellcheck disable=SC2059 # the format is the octal escape
      printf -v c "\\$o"
      json="$json\\u$hex."
      want="$want$c."
    done
    KERN_INPUT="{\"a\":\"$json\"}"
    run json_get a
    [ "$status" -eq 0 ]
    [ "$output" = "$want" ]
  done
  KERN_INPUT='{"a":"\u0041\u002f\u004a\u004A"}'
  run json_get a
  [ "$output" = 'A/JJ' ]
  # Decoded once: an escaped backslash before u0041 is text, and so is a backslash \u005c gives.
  KERN_INPUT='{"a":"\\u0041","b":"\u005cu0041","c":"\\\u0041"}'
  run json_get a
  [ "$output" = '\u0041' ]
  run json_get b
  [ "$output" = '\u0041' ]
  run json_get c
  [ "$output" = '\A' ]
}

@test "decode refuses \u0000" {
  # bash cannot hold the byte, so a value holding the escape is not read, and prints nothing.
  KERN_INPUT='{"a":"x\u0000y","b":"ok"}'
  run json_get a
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run json_get b
  [ "$status" -eq 0 ]
  [ "$output" = ok ]
  KERN_INPUT='{"a":"x\\u0000y"}'
  run json_get a
  [ "$status" -eq 0 ]
  [ "$output" = 'x\u0000y' ]
}

@test "decode leaves \u0080 and above as text" {
  KERN_INPUT='{"a":"\u00e9 \u0080 \u00FF \u0100 \ud83d\ude00"}'
  run json_get a
  [ "$status" -eq 0 ]
  [ "$output" = '\u00e9 \u0080 \u00FF \u0100 \ud83d\ude00' ]
}

@test "json_ok refuses a \u escape of a byte kern's parsers hold as a mark: 0x01 and 0x1c to 0x1f" {
  # git_words reads 0x1f as its in-record newline and 0x1d and 0x1e as record tags, G16 and G18 mark
  # words with 0x1c and 0x1d, awk joins array subscripts with 0x1c, and G13 starts a line with 0x01.
  # decode would hand any of them to a guard as the byte, so the hook input fails closed instead.
  for e in 0001 001c 001d 001e 001f 001F 001C; do
    KERN_INPUT="{\"tool_input\":{\"command\":\"ls a\\u${e}b\"}}"
    run json_ok
    [ "$status" -eq 1 ] || { echo "\\u$e was taken"; return 1; }
    # An escaped backslash before the u is text.
    KERN_INPUT="{\"tool_input\":{\"command\":\"ls a\\\\u${e}b\"}}"
    run json_ok
    [ "$status" -eq 0 ] || { echo "\\\\u$e was refused"; return 1; }
  done
  # Other control characters are no mark: a Write's content may hold an ESC or a bell.
  for e in 0002 0007 001b 001B 0018; do
    KERN_INPUT="{\"tool_input\":{\"content\":\"a\\u${e}b\"}}"
    run json_ok
    [ "$status" -eq 0 ] || { echo "\\u$e was refused"; return 1; }
  done
}

@test "a hook input holding a \u0000 escape is not parseable, so the call asks, or is denied under autopilot" {
  # json_get refuses the escape, so a guard would read the field as absent; json_ok fails instead.
  KERN_INPUT='{"tool_input":{"content":"x\u0000"}}'
  run json_ok
  [ "$status" -eq 1 ]
  KERN_INPUT='{"tool_input":{"content":"x\\u0000"}}'
  run json_ok
  [ "$status" -eq 0 ]
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  run_guard "$(tool_payload Write "\"file_path\":\"$R/a.md\",\"content\":\"x\\u0000\"")"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"needs user approval: kern G0: hook input not parseable"'* ]] || false
  set_autopilot on
  run_guard "$(tool_payload Write "\"file_path\":\"$R/a.md\",\"content\":\"x\\u0000\"")"
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload Write "\"file_path\":\"$R/a.md\",\"content\":\"x\\\\u0000\"")"
  [ "$(decision_of "$output")" = none ]
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

@test "when tr cannot trim the hook input, json_ok fails and the call asks, or is denied under autopilot" {
  # json_ok trims the input with one tr -d pass; a tr that did not run (a fork refused under load) leaves
  # the text empty, which is not an object, so the dispatcher calls unparseable and fails closed (P1
  # review Minor 3). The stub fails only that tr call, whose set holds the two bytes \t.
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  read_fails tr '*\\t*'
  run_guard "$(bash_payload ls)"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" == *'"needs user approval: kern G0: hook input not parseable"'* ]] || false
  set_autopilot on
  run_guard "$(bash_payload ls)"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'"kern G0: hook input not parseable (autopilot: nobody to ask)"'* ]] || false
  [ "$(read_failures tr)" -gt 0 ]
  read_fails tr '*\\t*' 0
  set_autopilot off
  run_guard "$(bash_payload ls)"
  [ "$(decision_of "$output")" = none ]
}
