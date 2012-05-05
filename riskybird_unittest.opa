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

function expect_lint_error(rule_str, s) {
  p = RegexpParser.parse(s)
  l =
    match(p) {
    case {none}: {ok}
    case {some: tree}: RegexpLinter.regexp(tree)
   }
  r = match (l) {
    case {ok}: false
    case _: true
  }
  OK.ok_ko("test [{rule_str}]: {s}", r)
}

// quantifiers
expect_parse("zero or one quantifier", "a?")
expect_parse("one or more quantifier", "a+")
expect_parse("zero or more quantifier", "a*")
expect_parse("exactly 4 quantifier", "a\{4\}")
expect_parse("at least 4 quantifier", "a\{4,\}")
expect_parse("range quantifier", "a\{4,4\}")
expect_parse("range quantifier", "a\{4,9\}")

// non greedy matches
expect_fail("invalid non greedy", "x??")
expect_parse("non greedy one or more quantifier", "a+?")
expect_parse("non greedy zero or more quantifier", "a*?")
expect_parse("WTF? non greedy exactly 4 quantifier", "a\{4\}?")
expect_parse("non greedy at least 4 quantifier", "a\{4,\}?")
expect_parse("non greedy range quantifier", "a\{4,4\}?")
expect_parse("non greedy range quantifier", "a\{4,9\}?")

// grouping
expect_parse("group", "(a)\1")
expect_parse("non capturing group", "(?:a)")

// alternatives
expect_parse("alternative", "a|bc+|d")

// other tests

expect_fail("open parenthesis", "abc(")
expect_fail("invalid quantifier combination", "^*ab")
expect_fail("invalid quantifier combination", "x+*")
expect_fail("invalid quantifier combination", "x\{2,3\}+")
expect_fail("invalid quantifier", "a\{-4,-2\}")
expect_fail("invalid quantifier", "a\{-4,\}")

expect_lint_error("invalid quantifier", "a\{4,2\}")
expect_lint_error("possible improvement", "a\{4,4\}")
