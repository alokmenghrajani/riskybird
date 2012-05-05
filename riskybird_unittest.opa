/**
 * RiskyBird
 * Regular expression authors best friend
 *
 * Running: make test
 */

import stdlib.tests

function expect_parse(rule_str, s) {
  p = RegexpParser.parse(s)
  r = RegexpStringPrinter.pretty_print(p)
  OK.check_equal("test [{rule_str}]: {s}", s, r)
}

function expect_fail(rule_str, s) {
  p = RegexpParser.parse(s)
  OK.ok_ko("test [{rule_str}]: {s}", Option.is_none(p))
}

expect_parse("simple expression", "a|bc+")
expect_parse("non greedy match", "a*?")

expect_fail("open parenthesis", "abc(")
expect_fail("invalid quantifier", "^*ab")
