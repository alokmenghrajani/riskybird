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
expect_parse("zero or more non greedy", "x??")
expect_parse("non greedy one or more quantifier", "a+?")
expect_parse("non greedy zero or more quantifier", "a*?")
expect_parse("non greedy exactly 4 quantifier", "a\{4\}?")
expect_lint_error("non greedy exactly 4 quantifier", "a\{4\}?")
expect_parse("non greedy at least 4 quantifier", "a\{4,\}?")
expect_parse("non greedy range quantifier", "a\{4,4\}?")
expect_parse("non greedy range quantifier", "a\{4,9\}?")

// grouping
expect_parse("group", "(a)\\1")
expect_parse("non capturing group", "(?:a)")

// alternatives
expect_parse("alternative", "a|bc+|d")

// character sets and ranges
expect_parse("a set of characters", "[abc]")
expect_parse("a range of characters", "[a-m]")
expect_parse("a negative set of characters", "[^abc]")
expect_parse("a negative range of characters", "[^a-m]")
expect_parse("a set and range", "[abcx-z]")
expect_parse("a negative set and range", "[^abcx-z]")

// sets matching -
expect_parse("escaped -", "[a\\-c]")
expect_parse("front -", "[-ac]")
expect_parse("middle -", "[a-c-e]")
expect_parse("end -", "[abc-]")

// lint rule for ranges
expect_lint_error("overlapping ranges", "[a-mb-z]")
expect_lint_error("included ranges", "[a-md-g]")
expect_lint_error("character from range", "[a-zx]")
expect_lint_error("complex overlapping", "[fg-ia-ec-j]")
expect_lint_error("complex inclusion", "[fg-ia-ec-h]")
expect_lint_error("invalid range", "[z-a]")

// other tests

expect_fail("open parenthesis", "abc(")
expect_fail("invalid quantifier combination", "^*ab")
expect_fail("invalid quantifier combination", "x+*")
expect_fail("invalid quantifier combination", "x\{2,3\}+")
expect_fail("invalid quantifier", "a\{-4,-2\}")
expect_fail("invalid quantifier", "a\{-4,\}")

expect_lint_error("invalid quantifier", "a\{4,2\}")
expect_lint_error("possible improvement", "a\{4,4\}")
