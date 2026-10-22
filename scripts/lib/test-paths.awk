# is_test(p): p is a test file path. floor-scan and probe both load this file, so they agree on what a
# test is. Run with -v print_tests=1 to print the test paths among input lines.
function is_test(p) {
  return p ~ /(^|\/)(test|tests|__tests__|spec|specs)\// || p ~ /[._-](test|spec)\.[A-Za-z0-9]+$/ || p ~ /_test\.go$/ || p ~ /(^|\/)test_[^\/]*\.py$/
}
# is_probe_keep(p): a path probe --exclude-tests keeps in its fork: a test, or data a test reads (test data
# and fixture dirs, snapshots, golden files). floor-scan uses is_test only. -v print_keep=1 prints them.
function is_probe_keep(p) {
  return is_test(p) || p ~ /(^|\/)(testdata|fixtures|__fixtures__|__snapshots__)\// || p ~ /\.(snap|golden)$/
}
print_tests && is_test($0) { print }
print_keep && is_probe_keep($0) { print }
