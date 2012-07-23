/**
 * RiskyBird Unittest
 *
 * Running: make test
 *
 *
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

function Test.result expect_parse(res, string test_name, string regexp) {
  p = RegexpParser.parse(regexp)
  pp = RegexpStringPrinter.pretty_print(p)
  Test.expect_equals(res, test_name, pp, regexp)
}

function expect_fail(res, string test_name, string regexp) {
  p = RegexpParser.parse(regexp)
  Test.expect_none(res, test_name, p, "")
}

function expect_lint_error(res, string test_name, string regexp, lint_rule_type expected_lint_error) {
  p = RegexpParser.parse(regexp)
  match(p) {
    case {none}: Test.fail(res, test_name, "{regexp} FAILED TO PARSE!")
    case {some: tree}:
      lint_result r = RegexpLinter.regexp(tree)
      Test.expect_true(res, test_name, Set.mem(expected_lint_error, r.matched_rules), "")
  }
}

function expect_clean_lint(res, string test_name, string regexp) {
  p = RegexpParser.parse(regexp)
  match(p) {
    case {none}:
      Test.fail(res, test_name, "{regexp} FAILED TO PARSE!")
    case {some: tree}:
      lint_result r = RegexpLinter.regexp(tree)
      Test.expect_true(res, test_name, Set.is_empty(r.matched_rules), "")
  }
}

function run_tests() {
  t = Test.begin()

  t = expect_clean_lint(t, "character range", "[\\x00-\\x0a]")

  // empty regexp
  t = expect_parse(t, "empty regexp", "")
  t =  expect_clean_lint(t, "almost empty regexp", " ")

  // alternatives
  t = expect_parse(t, "alternative", "a|bde|efg")

  // assertions
  t = expect_parse(t, "anchored at beginning", "^abc")
  t = expect_parse(t, "anchored at end", "abc$")
  t = expect_parse(t, "anchored in an alternative", "a|^b")
  t = expect_parse(t, "anchored in an alternative", "^a|^b")
  t = expect_parse(t, "anchored in an alternative", "a$|b")
  t = expect_parse(t, "anchored in an alternative", "a$|b$")
  t = expect_parse(t, "word boundary", "\\bfoo\\b")
  t = expect_parse(t, "word boundary", "\\Bthing")
  t = expect_parse(t, "look ahead", "(?=abc|def)")
  t = expect_parse(t, "look ahead", "(?!abc|def)")

  t = expect_lint_error(t, "not always anchored", "^ab|c", {inconsistent_start_anchors});
  t = expect_lint_error(t, "not always anchored", "ab|c$", {inconsistent_end_anchors});
  t = expect_lint_error(t, "not always anchored", "^a$|b|c", {inconsistent_start_anchors});
  t = expect_lint_error(t, "not always anchored", "^a$|b|c", {inconsistent_end_anchors});

  // quantifiers
  t = expect_parse(t, "zero or more quantifier", "a*")
  t = expect_parse(t, "one or more quantifier", "a+")
  t = expect_parse(t, "zero or one quantifier", "a?")
  t = expect_parse(t, "exactly 4 quantifier", "a\{4\}")
  t = expect_parse(t, "at least 20 quantifier", "a\{20,\}")
  t = expect_parse(t, "range quantifier", "a\{4,4\}")
  t = expect_parse(t, "range quantifier", "a\{4,100\}")

  t = expect_lint_error(t, "invalid quantifier", "a\{4,2\}", {incorrect_quantifier})
  t = expect_lint_error(t, "possible improvement", "a\{4,4\}", {non_ideal_quantifier})

  t = expect_lint_error(t, "quantifier ?", "a\{0,1\}", {non_ideal_quantifier})
  t = expect_lint_error(t, "quantifier *", "a\{0,\}", {non_ideal_quantifier})
  t = expect_lint_error(t, "quantifier +", "a\{1,\}", {non_ideal_quantifier})
  t = expect_lint_error(t, "useless quantifier", "a\{1\}", {non_ideal_quantifier})
  t = expect_lint_error(t, "useless quantifier", "a\{0\}", {non_ideal_quantifier})

  // non greedy quantifiers
  t = expect_parse(t, "zero or more non greedy", "x??")
  t = expect_parse(t, "non greedy one or more quantifier", "a+?")
  t = expect_parse(t, "non greedy zero or more quantifier", "a*?")
  t = expect_parse(t, "non greedy exactly 4 quantifier", "a\{4\}?")
  t = expect_parse(t, "non greedy at least 20 quantifier", "a\{20,\}?")
  t = expect_parse(t, "non greedy range quantifier", "a\{4,4\}?")
  t = expect_parse(t, "non greedy range quantifier", "a\{4,100\}?")

  t = expect_lint_error(t, "non greedy exactly 4 quantifier", "a\{4\}?", {useless_non_greedy})

  // atoms
  t = expect_parse(t, "dot", "a.c")
  t = expect_parse(t, "non capturing group", "abc(?:xyz)")
  t = expect_parse(t, "group with reference", "(a)\\1")
  t = expect_parse(t, "class range", "[a-z]")
  t = expect_parse(t, "class range", "[a-cde-f]")
  t = expect_parse(t, "special characters", "a\\d")
  t = expect_parse(t, "special characters", "a\\D");
  t = expect_parse(t, "special characters", "a\\s");
  t = expect_parse(t, "special characters", "a\\S");
  t = expect_parse(t, "special characters", "a\\w");
  t = expect_parse(t, "special characters", "a\\W");

  t = expect_lint_error(t, "group which doesn't exist", "(a)\\2", {incorrect_reference})
  t = expect_lint_error(t, "group which doesn't yet exist", "\\1(a)", {incorrect_reference})
  t = expect_lint_error(t, "group which doesn't yet exist", "(a\\1)", {incorrect_reference})
  t = expect_lint_error(t, "group which doesn't yet exist", "((a)\\1)", {incorrect_reference})
  t = expect_lint_error(t, "group not referenced", "(a)", {unused_group})
  t = expect_lint_error(t, "group not referenced", "((x) (y))\\1\\2", {unused_group})

  // character sets and ranges
  t = expect_parse(t, "a set of characters", "[abc]")
  t = expect_parse(t, "a range of characters", "[a-m]")
  t = expect_parse(t, "a negative set of characters", "[^abc]")
  t = expect_parse(t, "a negative range of characters", "[^a-m]")
  t = expect_parse(t, "a set and range", "[abcx-z]")
  t = expect_parse(t, "a negative set and range", "[^abcx-z]")
  t = expect_parse(t, "escaped -", "[a\\-c]")
  t = expect_parse(t, "front -", "[-ac]")
  t = expect_parse(t, "middle -", "[a-c-e]")
  t = expect_parse(t, "end -", "[abc-]")
  t = expect_parse(t, "special characters", "[?.]")
  t = expect_parse(t, "special characters in a range", "[.-?]")

  t = expect_lint_error(t, "overlapping ranges", "[a-mb-z]", {non_optimal_class_range})
  t = expect_lint_error(t, "included ranges", "[a-md-g]", {non_optimal_class_range})
  t = expect_lint_error(t, "character from range", "[a-zx]", {non_optimal_class_range})
  t = expect_lint_error(t, "duplicate character", "[xabcx]", {non_optimal_class_range})
  t = expect_lint_error(t, "contiguous ranges", "[a-cde-f]", {non_optimal_class_range})
  t = expect_lint_error(t, "repeated ranges", "[a-ca-c]", {non_optimal_class_range})

  t = expect_lint_error(t, "complex overlapping", "[fg-ia-ec-j]", {non_optimal_class_range})
  t = expect_lint_error(t, "complex inclusion", "[fg-ia-ec-h]", {non_optimal_class_range})
  t = expect_lint_error(t, "invalid range", "[z-a]", {invalid_range_in_character_class})
  t = expect_lint_error(t, "useless range", "[x-x]", {non_optimal_class_range})
  t = expect_lint_error(t, "lazyness", "[0-9A-z]", {lazy_character_class})

  t = expect_lint_error(t, "overlapping ranges", "[\\x10-\\x20\\x15-\\x25]", {non_optimal_class_range})
  t = expect_lint_error(t, "overlapping ranges", "[\\x10-\\x70a-e]", {non_optimal_class_range})
  t = expect_lint_error(t, "character from range", "[\\00-\\0a\\cj]", {non_optimal_class_range})
  t = expect_lint_error(t, "character from range", "[\\00-\\0a\\n]", {non_optimal_class_range})
  t = expect_clean_lint(t, "character range", "[\\x00-\\x0a]")

  t = expect_lint_error(t, "empty character class", "foo[]bar", {empty_character_class})

  t = expect_clean_lint(t, "character range", "[.-]")
  t = expect_clean_lint(t, "\\[ in character range", "[\\[]")
  t = expect_clean_lint(t, "\\] in character range", "[\\]]")
  t = expect_clean_lint(t, "\\\\ in character range", "[\\\\]")

  // escape characters
  t = expect_parse(t, "control escape", "a\\n")
  t = expect_parse(t, "control letter", "a\\cj")
  t = expect_parse(t, "hex escape", "a\\x0ab")
  t = expect_parse(t, "unicode escape", "a\\u000ab")
  t = expect_parse(t, "identity escape", "a\\[b")

  t = expect_lint_error(t, "escaped char", "\\i", {improve_escaped_char})
  t = expect_lint_error(t, "escaped char", "\\cj", {improve_escaped_char})
  t = expect_lint_error(t, "escaped char", "\\x0a", {improve_escaped_char})
  t = expect_lint_error(t, "escaped char", "\\x61", {improve_escaped_char})
  t = expect_clean_lint(t, "escaped char", "\\$")
  t = expect_lint_error(t, "escaped char", "\\u0065", {improve_escaped_char})

  // class escapes
  t = expect_parse(t, "control escape", "[\\nz]")
  t = expect_parse(t, "control letter", "[\\cjz]")
  t = expect_parse(t, "hex escape", "[\\x0az]")
  t = expect_parse(t, "unicode escape", "[\\u000az]")
  t = expect_parse(t, "identity escape", "[\\[z]")
  t = expect_parse(t, "character class", "[\\dz]")

  // other tests
  t = expect_fail(t, "open parenthesis", "abc(t, ")
  t = expect_fail(t, "invalid quantifier combination", "^*ab")
  t = expect_fail(t, "invalid quantifier combination", "x+*")
  t = expect_fail(t, "invalid quantifier combination", "x\{2,3\}+")
  t = expect_fail(t, "invalid quantifier", "a\{-4,-2\}")
  t = expect_fail(t, "invalid quantifier", "a\{-4,\}")
  t = expect_fail(t, "invalid quantifier", "a\{-4\}")
  t = expect_fail(t, "invalid character", "a//")

  Test.end(t)
}
run_tests()

