/**
 * RiskyBird Unittest
 *
 * Running: make test
 *
 *   This file is part of RiskyBird
 *
 *   RiskyBird is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   RiskyBird is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with RiskyBird.  If not, see <http://www.gnu.org/licenses/>.
 *
 * @author Julien Verlaguet
 * @author Alok Menghrajani
 */

import stdlib.tests

function expect_parse(rule_str, s) {
  p = RegexpParser.parse(s)
  r = RegexpStringPrinter.pretty_print(p)
  OK.check_equal("test [{rule_str}]: {s}", r, s)
}

function expect_fail(rule_str, s) {
  p = RegexpParser.parse(s)
  OK.ok_ko("test [{rule_str}]: {s}", Option.is_none(p))
}

function expect_lint_error(string rule_str, string s, lint_rule_type expected_lint_error) {
  p = RegexpParser.parse(s)
  match(p) {
    case {none}: OK.fail("test [{rule_str}]: {s} FAILED TO PARSE!")
    case {some: tree}:
      lint_result r = RegexpLinter.regexp(tree)
      OK.ok_ko("test [{rule_str}]: {s}", Set.mem(expected_lint_error, r.matched_rules))
  }
}

function expect_clean_lint(string rule_str, string s) {
  p = RegexpParser.parse(s)
  match(p) {
    case {none}: OK.fail("test [{rule_str}]: {s} FAILED TO PARSE!")
    case {some: tree}:
      lint_result r = RegexpLinter.regexp(tree)
      OK.ok_ko("test [{rule_str}]: {s}", Set.is_empty(r.matched_rules))
  }
}

// empty regexp
expect_parse("empty regexp", "")
expect_clean_lint("empty regexp", "")

// alternatives
expect_parse("alternative", "a|bde|efg")

// assertions
expect_parse("anchored at beginning", "^abc")
expect_parse("anchored at end", "abc$")
expect_parse("anchored in an alternative", "a|^b")
expect_parse("anchored in an alternative", "^a|^b")
expect_parse("anchored in an alternative", "a$|b")
expect_parse("anchored in an alternative", "a$|b$")
expect_parse("word boundary", "\\bfoo\\b")
expect_parse("word boundary", "\\Bthing")
expect_parse("look ahead", "(?=abc|def)")
expect_parse("look ahead", "(?!abc|def)")

expect_lint_error("not always anchored", "^ab|c", {inconsistent_start_anchors});
expect_lint_error("not always anchored", "ab|c$", {inconsistent_end_anchors});
expect_lint_error("not always anchored", "^a$|b|c", {inconsistent_start_anchors});
expect_lint_error("not always anchored", "^a$|b|c", {inconsistent_end_anchors});

// quantifiers
expect_parse("zero or more quantifier", "a*")
expect_parse("one or more quantifier", "a+")
expect_parse("zero or one quantifier", "a?")
expect_parse("exactly 4 quantifier", "a\{4\}")
expect_parse("at least 20 quantifier", "a\{20,\}")
expect_parse("range quantifier", "a\{4,4\}")
expect_parse("range quantifier", "a\{4,100\}")

expect_lint_error("invalid quantifier", "a\{4,2\}", {incorrect_quantifier})
expect_lint_error("possible improvement", "a\{4,4\}", {non_ideal_quantifier})

// non greedy quantifiers
expect_parse("zero or more non greedy", "x??")
expect_parse("non greedy one or more quantifier", "a+?")
expect_parse("non greedy zero or more quantifier", "a*?")
expect_parse("non greedy exactly 4 quantifier", "a\{4\}?")
expect_parse("non greedy at least 20 quantifier", "a\{20,\}?")
expect_parse("non greedy range quantifier", "a\{4,4\}?")
expect_parse("non greedy range quantifier", "a\{4,100\}?")

expect_lint_error("non greedy exactly 4 quantifier", "a\{4\}?", {useless_non_greedy})

// atoms
expect_parse("dot", "a.c")
expect_parse("non capturing group", "abc(?:xyz)")
expect_parse("group with reference", "(a)\\1")
expect_parse("class range", "[a-z]")
expect_parse("class range", "[a-cde-f]")
expect_parse("special characters", "a\\d")
expect_parse("special characters", "a\\D");
expect_parse("special characters", "a\\s");
expect_parse("special characters", "a\\S");
expect_parse("special characters", "a\\w");
expect_parse("special characters", "a\\W");

expect_lint_error("group which doesn't exist", "(a)\\2", {incorrect_reference})
expect_lint_error("group which doesn't yet exist", "\\1(a)", {incorrect_reference})
expect_lint_error("group which doesn't yet exist", "(a\\1)", {incorrect_reference})
expect_lint_error("group which doesn't yet exist", "((a)\\1)", {incorrect_reference})
expect_lint_error("group not referenced", "(a)", {unused_group})
expect_lint_error("group not referenced", "((x) (y))\\1\\2", {unused_group})

// character sets and ranges
expect_parse("a set of characters", "[abc]")
expect_parse("a range of characters", "[a-m]")
expect_parse("a negative set of characters", "[^abc]")
expect_parse("a negative range of characters", "[^a-m]")
expect_parse("a set and range", "[abcx-z]")
expect_parse("a negative set and range", "[^abcx-z]")
expect_parse("escaped -", "[a\\-c]")
expect_parse("front -", "[-ac]")
expect_parse("middle -", "[a-c-e]")
expect_parse("end -", "[abc-]")
expect_parse("special characters", "[?.]")
expect_parse("special characters in a range", "[.-?]")

expect_lint_error("overlapping ranges", "[a-mb-z]", {non_optimal_class_range})
expect_lint_error("included ranges", "[a-md-g]", {non_optimal_class_range})
expect_lint_error("character from range", "[a-zx]", {non_optimal_class_range})
expect_lint_error("duplicate character", "[xabcx]", {non_optimal_class_range})
expect_lint_error("contiguous ranges", "[a-cde-f]", {non_optimal_class_range})
expect_lint_error("repeated ranges", "[a-ca-c]", {non_optimal_class_range})

expect_lint_error("complex overlapping", "[fg-ia-ec-j]", {non_optimal_class_range})
expect_lint_error("complex inclusion", "[fg-ia-ec-h]", {non_optimal_class_range})
expect_lint_error("invalid range", "[z-a]", {invalid_range_in_character_class})
expect_lint_error("useless range", "[x-x]", {non_optimal_class_range})
expect_lint_error("lazyness", "[0-9A-z]", {lazy_character_class})

// escape characters
expect_parse("control escape", "a\\n")
expect_parse("control letter", "a\\cj")
expect_parse("hex escape", "a\\x0ab")
expect_parse("unicode escape", "a\\u000ab")
expect_parse("identity escape", "a\\[b")

// class escapes
expect_parse("control escape", "[\\nz]")
expect_parse("control letter", "[\\cjz]")
expect_parse("hex escape", "[\\x0az]")
expect_parse("unicode escape", "[\\u000az]")
expect_parse("identity escape", "[\\[z]")
expect_parse("character class", "[\\dz]")

// other tests
expect_fail("open parenthesis", "abc(")
expect_fail("invalid quantifier combination", "^*ab")
expect_fail("invalid quantifier combination", "x+*")
expect_fail("invalid quantifier combination", "x\{2,3\}+")
expect_fail("invalid quantifier", "a\{-4,-2\}")
expect_fail("invalid quantifier", "a\{-4,\}")
expect_fail("invalid quantifier", "a\{-4\}")

expect_fail("invalid character", "a//")

