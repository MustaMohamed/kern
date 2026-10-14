# is_test(p): p is a test file path. floor-scan and probe both load this file, so they agree on what a
# test is. Run with -v print_tests=1 to print the test paths among input lines.
function is_test(p) {
  return p ~ /(^|\/)(test|tests|__tests__|spec|specs)\// || p ~ /[._-](test|spec)\.[A-Za-z0-9]+$/ || p ~ /_test\.go$/ || p ~ /(^|\/)test_[^\/]*\.py$/
}
print_tests && is_test($0) { print }
