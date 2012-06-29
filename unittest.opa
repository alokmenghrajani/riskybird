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

// empty regexp
expect_parse("empty regexp", "")

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

// quantifiers
expect_parse("zero or more quantifier", "a*")
expect_parse("one or more quantifier", "a+")
expect_parse("zero or one quantifier", "a?")
expect_parse("exactly 4 quantifier", "a\{4\}")
expect_parse("at least 20 quantifier", "a\{20,\}")
expect_parse("range quantifier", "a\{4,4\}")
expect_parse("range quantifier", "a\{4,100\}")

// non greedy quantifiers
expect_parse("zero or more non greedy", "x??")
expect_parse("non greedy one or more quantifier", "a+?")
expect_parse("non greedy zero or more quantifier", "a*?")
expect_parse("non greedy exactly 4 quantifier", "a\{4\}?")
expect_parse("non greedy at least 20 quantifier", "a\{20,\}?")
expect_parse("non greedy range quantifier", "a\{4,4\}?")
expect_parse("non greedy range quantifier", "a\{4,100\}?")

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
