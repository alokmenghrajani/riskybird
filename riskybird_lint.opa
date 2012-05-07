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

/* The ranges seen so far (when analysing ranges) */
//type lranges = list(range)

/* The state when checking items */
//type item_state = {
//  lstatus status,
//  lranges ranges,
//}

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

//  function bool range_is_included(range r1, range r2) {
//    r1.rstart >= r2.rstart && r1.rend <= r2.rend
//  }

  /* Checks whether the range r is already covered by the list of
   * ranges l. So r = [a-b], lr = [[a-d]] ==> true
   * using fold is an overkill since we need to handle the case
   * where the list is empty anyway
   */
//  function bool range_exists(range r, lranges lr) {
//    match(lr) {
//      case {nil}: false
//      case {~hd, ~tl}:
//       range_is_included(r, hd) || range_exists(r, tl)
//    }
//  }
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

/*
  function lstatus elementary(lstatus st, elementary elt) {
    match(elt) {
      case {eset:{items:l, ...}}:
        lranges ranges = []
        state = { status: st, ~ranges }
        range_status = List.fold_left(item, state, l)
        lreturn(st, range_status.status)
      case _: st
     }
   }

  function item_state item(item_state state, item it) {
    match(it) {
      case {irange: r}:
        if (r.rstart > r.rend) {
          e = {error: {lint_rule: 4, title: "Invalid range in character class",
          body: "The character class contains an invalid range."}}
          {status: e, ranges: state.ranges}
        } else if (r.rstart == r.rend) {
          e = {error: {lint_rule: 5, title: "Useless range in character class",
          body: "The character class contains a useless range."}}
          {status: e, ranges: state.ranges}
        } else if (RegexpLinterHelper.range_exists(r, state.ranges)) {
          status = {error: {range_not_used: r}}
          { ~status, ranges: state.ranges }
        } else if (r.rstart == "A" && r.rend == "z") {
          e = {error: {lint_rule: 6, title: "Progammer laziness",
          body: "When you write A-z instead of A-Za-z, you are including 6 extra characters!"}}
          {status: e, ranges: state.ranges}
        } else {
          ranges = List.cons(r, state.ranges)
          { status: state.status, ~ranges }
        }
      case _: state
    }
  }
*/

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
      case {eset:{items:l, ...}}:
        List.fold(do_item, l, res)
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
