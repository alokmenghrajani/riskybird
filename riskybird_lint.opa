/**
 * Lint engine for regular expressions.
 *
 * The purpose of the lint engine is to detect common mistakes people make when
 * composing regular expressions.
 *
 * At some point, we might even suggest auto-fixes.
 *
 * TODO list:
 * - detect www., .com or .net and
 *    suggest replacing "." with "\.".
 *
 * - detect \/\/ and suggest using % % as the regexp seperator
 *
 * - detect error prone priority rules (e.g. ^ab|c$)
 */

/* The status of the linter */
type lint_result = {
  intset matched_rules,
  list(lint_error) errors,
  intset groups,
  intset groups_referenced,
}

type lint_error = {
  int lint_rule,
//  int element_id,
  string title,
  string body
}

module RegexpLinterRender {
  function option(xhtml) render(lint_result result) {
    match (result.errors) {
      case {nil}: {none}
      case _:
        t = List.fold(
          function(error, r) {
            <>
              <div class="alert-message block-message warning">
                <p>
                  <span class="icon32 icon-alert"/>
                  <strong>{error.title}</strong><br/>
                  {error.body}
                </p>
                <div class="alert-actions"/>
              </div>
              {r}
            </>
          },
          result.errors,
          <></>
        )
        {some: <div id="lint_rules" class="span8">{t}</div>}
    }
  }
}

module RegexpLinterHelper {
  /**
   * Checks all the groups have been referenced.
   */
  function lint_result check_groups(lint_result res) {
    recursive function bool f(int x, intset s) {
      if (x == 0) {
        id(true)
      } else if (IntSet.mem(x, s)) {
        f(x-1, s)
      } else {
        id(false)
      }
    }
    if (f(IntSet.height(res.groups), res.groups_referenced)) {
      id(res)
    } else {
      err = {
        lint_rule: 8,
        title: "unused group",
        body: "some groups are not referenced, consider using (?:...)"
      }
      RegexpLinter.add(res, err)
    }
  }

  /**
   * The easiest way to lint a character set is to rewrite
   * the set and then compare the results.
   */
  function lint_result check_set(rset set, lint_result res) {
    recursive function intset range_to_charmap(int start, int end, intset map) {
      map = IntSet.add(start, map)
      if (start == end) {
        id(map)
      } else {
        range_to_charmap(start+1, end, map)
      }
    }

    function intset set_to_charmap(item i, intset map) {
      match (i) {
        case {~ichar}:
          IntSet.add(int_of_first_char(ichar), map)
        case {irange: {~rstart, ~rend}}:
          range_to_charmap(int_of_first_char(rstart), int_of_first_char(rend), map)
      }
    }

    recursive function (list(item), map) charmap_to_range(int min, int max, intset map, list(item) items) {
      map = IntSet.remove(max, map)
      if (IntSet.mem(max+1, map)) {
        charmap_to_range(min, max+1, map, items)
      } else if (min == max) {
        item = {ichar: textToString(Text.from_character(min))}
        items = List.cons(item, items)
        (items, map)
      } else if (min+1 == max) {
        item = {ichar: textToString(Text.from_character(min))}
        items = List.cons(item, items)
        item = {ichar: textToString(Text.from_character(max))}
        items = List.cons(item, items)
        (items, map)
      } else {
        item = {irange: {rstart: textToString(Text.from_character(min)), rend: textToString(Text.from_character(max))}}
        items = List.cons(item, items)
        (items, map)
      }
    }

    recursive function charmap_to_set(intset map, list(item) items) {
      if (IntSet.is_empty(map)) {
        id(items)
      } else {
        (int min, _) = IntMap.min_binding(map)
        (items, map) = charmap_to_range(min, min, map, items)
        charmap_to_set(map, items)
      }
    }

    if (IntSet.mem(5, res.matched_rules) ||
        IntSet.mem(6, res.matched_rules) ||
        IntSet.mem(7, res.matched_rules)) {
      // if rules 5, 6 or 7 matched, we'll skip this one.
      id(res)
    } else {
      map = List.fold(set_to_charmap, set.items, IntMap.empty)
      new_set = {set with items: List.rev(charmap_to_set(map, []))}

      s1 = RegexpStringPrinter.print_set(new_set)
      s2 = RegexpStringPrinter.print_set(set)
      if (String.length(s1) < String.length(s2)) {
        err = {
          lint_rule: 9,
          title: "non optimal character range",
          body: "shorter way to write {s2}: {s1}"
        }
        RegexpLinter.add(res, err)
      } else {
        id(res)
      }
    }
  }
}

module RegexpLinter {

  function lint_result add(lint_result current, lint_error error) {
    if (IntSet.mem(error.lint_rule, current.matched_rules)) {
      id(current)
    } else {
      matched_rules = IntSet.add(error.lint_rule, current.matched_rules)
      errors = List.cons(error, current.errors)
      {current with ~matched_rules, ~errors}
    }
  }

  function lint_result regexp(regexp re) {
    lint_result res = {
      matched_rules: IntSet.empty,
      errors: [],
      groups: IntSet.empty,
      groups_referenced: IntSet.empty
    }
    res = do_regexp(re, res)

    RegexpLinterHelper.check_groups(res)
  }

  function lint_result do_regexp(regexp re, lint_result res) {
    List.fold(do_simple, re, res)
  }

  function lint_result do_simple(simple s, lint_result res) {
    List.fold(do_basic, s, res)
  }

  function lint_result do_basic(basic b, lint_result res) {
    match (b) {
      case {~id, ~belt, ~bpost, ~greedy}:
        // process postfix
        res = do_postfix(bpost, greedy, res)
        // process elementary
        do_elementary(belt, res)
      case _:
        res
    }
  }

  function lint_result do_postfix(postfix bpost, bool greedy, lint_result res) {
    match (bpost) {
      case {~min, ~max}:
        if (min > max) {
          err = {
            lint_rule: 1,
            title: "incorrect quantifier",
            body: "min is greater than max"
          }
          add(res, err)
        } else if (min == max) {
          err = {
            lint_rule: 2,
            title: "improve the quantifier",
            body: "\{{min},{max}\} can be written as \{{min}\}"
          }
          add(res, err)
        } else {
          id(res)
        }
      case {exact:_}:
        if (greedy == false) {
          err = {
            lint_rule: 3,
            title: "useless non greedy",
            body: "when matching an exact amount, using non greddy makes no sense"
          }
          add(res, err)
        } else {
          id(res)
        }
      case _:
        res
    }
  }

  function lint_result do_elementary(elementary e, lint_result res) {
    match (e) {
      case {~group_id, ~egroup}:
        res = do_regexp(egroup, res)
        {res with groups: IntSet.add(group_id, res.groups)}
      case {~group_ref}:
        res = if (IntSet.mem(group_ref, res.groups)) {
          id(res)
        } else {
          err = {
            lint_rule: 4,
            title: "incorrect reference",
            body: "\\{group_ref} refers to an invalid capture group"
          }
          add(res, err)
        }
        {res with groups_referenced: IntSet.add(group_ref, res.groups_referenced)}
      case {~eset}:
        res = List.fold(do_item, eset.items, res)
        RegexpLinterHelper.check_set(eset, res)
      case _:
        res
    }
  }

  function lint_result do_item(item i, lint_result res) {
    match (i) {
      case {irange: r}:
        if (r.rstart > r.rend) {
          err = {
            lint_rule: 5,
            title: "invalid range in character class",
            body: "[{r.rstart}-{r.rend}] is invalid."
          }
          add(res, err)
        } else if (r.rstart == r.rend) {
          err = {
            lint_rule: 6,
            title: "useless range in character class",
            body: "[{r.rstart}-{r.rend}] is useless."
          }
          add(res, err)
        } else if (r.rstart == "A" && r.rend == "z") {
          err = {
            lint_rule: 7,
            title: "programmer laziness",
            body: "When you write A-z instead of A-Za-z, you are including 6 extra characters!"
          }
          add(res, err)
        } else {
          id(res)
        }
      case _:
        res
    }
  }
}
