/**
 * A slightly better unittest system
 *
 * Example usage:
 * function run_tests() {
 *   t = Test.begin()
 *   t = Test.pass(t, "test 1")
 *   t = Test.fail(t, "test 2", "this always fails")
 *   t = Test.expect_equals(t, "test 3", 2*8, 16)
 *   t = Test.expect_equals(t, "test 4", 2*8, 20)
 *   t = Test.expect_none(t, "test 5", {none}, "something is weird!")
 *   t = Test.expect_none(t, "test 6", {some: 1}, "something is weird!")
 *   t = Test.expect_true(t, "test 7", true, "hmmm...")
 *   t = Test.expect_true(t, "test 8", false, "hmmm...")
 *   t = Test.expect_false(t, "test 9", true, "hmmm...")
 *   t = Test.expect_false(t, "test 10", false, "hmmm...")
 *   Test.end(t)
 * }
 * run_tests()
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

import stdlib.system

type Test.result = {
  list(string) passed,
  list(string) failed,
}

module Test {
  function Test.result begin() {
    prerrln("Starting unittests")
    {passed: [], failed: []}
  }

  function void end(Test.result res) {
    prerrln("--------------------------------------------------------------------------------")
    prerrln("Passed: {List.length(res.passed)}")
    prerrln("Failed: {List.length(res.failed)}")
    prerrln("")
    if (List.is_empty(res.failed)) {
      System.exit(0)
    } else {
      prerrln("List of failed tests:")
      _ = List.map(function(s){prerrln("* {_fill(s, 78)}")}, res.failed)
      System.exit(List.length(res.failed));
    }
  }

  function pass(Test.result res, string test_name) {
    prerrln("{_fill(test_name, 40)}: PASS")
    {res with passed:List.cons(test_name, res.passed)}
  }

  function fail(Test.result res, string test_name, string extra_message) {
    right = ": FAIL {extra_message}"
    right = _fill(right, 40)
    prerrln("{_fill(test_name, 40)}{right}")
    {res with failed:List.cons(test_name, res.failed)}
  }

  function expect_equals(Test.result res, string test_name, 'a test_value, 'a expected_value) {
    if (test_value == expected_value) {
      pass(res, test_name)
    } else {
      extra_message = "(expecting {expected_value}, got {test_value})"
      fail(res, test_name, extra_message)
    }
  }

  function expect_none(Test.result res, string test_name, option('a) test_value, string extra_message) {
    expect_true(res, test_name, Option.is_none(test_value), extra_message)
  }

  function expect_some(Test.result res, string test_name, option('a) test_value, string extra_message) {
    expect_true(res, test_name, Option.is_some(test_value), extra_message)
  }

  function expect_true(Test.result res, string test_name, bool test_value, string extra_message) {
    if (test_value) {
      pass(res, test_name)
    } else {
      fail(res, test_name, extra_message)
    }
  }

  function expect_false(Test.result res, string test_name, bool test_value, string extra_message) {
    if (test_value) {
      fail(res, test_name, extra_message)
    } else {
      pass(res, test_name)
    }
  }

  function string _fill(string s, int l) {
    if (String.length(s) > l) {
      "{String.substring(0, l-3, s)}..."
    } else {
      String.pad_right(" ", l, s)
    }
  }
}
