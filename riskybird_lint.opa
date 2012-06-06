/**
 * Lint engine for regular expressions.
 *
 * The purpose of the lint engine is to detect common mistakes people make when
 * composing regular expressions.
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
  string title,
  string body,
  option(string) patch,
}

module RegexpLinterRender {
  function option(xhtml) render(lint_result result) {
    match (result.errors) {
      case {nil}: {none}
      case _:
        t = List.fold(
          function(error, r) {
            patch = match (error.patch) {
              case {none}: <></>
              case {~some}:
              <>i.e. {some}</>
            }
            <>
              <div class="alert-message block-message warning">
                <p>
                  <span class="icon32 icon-alert"/>
                  <strong>{error.title}</strong><br/>
                  {error.body}<br/>
                  {patch}
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

/**
 * Provides lint rules to detect inconsistent anchors.
 *
 * We first find all the first and last basic elements in the
 * regexp by diving inside the groups. We then check that these
 * elements all have the same anchor_start or anchor_end.
 */
type check_anchors = {
  bool at_start,
  list(bool) result
}

type check_anchors_result = {
  option(bool) first,
  bool result
}

module RegexpLinterAnchor {
  function lint_result check_anchors(regexp re, lint_result res) {
    res = check_anchors2(true, re, res)
    res = check_anchors2(false, re, res)
    res
  }

  function lint_result check_anchors2(bool at_start, regexp re, lint_result res) {
    r = get_anchor_regexp(re, {at_start:at_start, result:[]})

    // check if r contains all true or all false
    bool ok = list_check_all_same(r.result)

    if (ok == false) {
      err = if (at_start) {
        {
          lint_rule: 10,
          title: "inconsistent anchors",
          body: "start anchor is only applied in some cases",
          patch: {none}
        }
      } else {
        {
          lint_rule: 11,
          title: "inconsistent anchors",
          body: "end anchor is only applied in some cases",
          patch: {none}
        }
      }
      RegexpLinter.add(res, err)
    } else {
      res;
    }
  }

  function check_anchors get_anchor_regexp(regexp re, check_anchors r) {
    List.fold(get_anchor_simple, re, r)
  }

  function check_anchors get_anchor_simple(simple s, check_anchors r) {
    if (r.at_start == true) {
      match (s) {
        case {~hd, ~tl}: get_anchor_basic(hd, r)
        case []: {at_start:true, result:[false]}        // WTF!!
      }
    } else {
      match (s) {
        case [hd]: get_anchor_basic(hd, r)
        case {~hd, ~tl}: get_anchor_simple(tl, r)
        case []: {at_start:false, result:[false]}  // WTF!
      }
    }
  }

  function check_anchors get_anchor_basic(basic b, check_anchors r) {
    if (r.at_start == true) {
      match (b) {
        case {anchor_start}: {at_start:true, result:List.cons(true, r.result)}
        case {anchor_end}: {at_start:true, result:List.cons(false, r.result)}
        case {~belt, ...}: get_anchor_elementary(belt, r)
      }
    } else {
      match (b) {
        case {anchor_start}: {at_start:false, result:List.cons(false, r.result)}
        case {anchor_end}: {at_start:false, result:List.cons(true, r.result)}
        case {~belt, ...}: get_anchor_elementary(belt, r)
      }
    }
  }

  function check_anchors get_anchor_elementary(elementary belt, check_anchors r) {
    match (belt) {
      case {~egroup, ...}: get_anchor_regexp(egroup, r)
      case {~ncgroup, ...}: get_anchor_regexp(ncgroup, r)
      case _: {at_start: r.at_start, result: List.cons(false, r.result)}
    }
  }
}

module RegexpLinterHelper {
  /**
   * Checks if all the groups have been referenced.
   */
  function lint_result check_groups(regexp re, lint_result res) {
    recursive function option(int) f(int x, intset s) {
      if (x == 0) {
        {none}
      } else if (IntSet.mem(x, s)) {
        f(x-1, s)
      } else {
        {some: x}
      }
    }
    t = f(IntSet.height(res.groups), res.groups_referenced)
    match (t) {
      case {none}: res
      case {some: unused_group}:
        regexp new_regexp = RegexpFixUnreferencedGroup.regexp(re, unused_group)
        err = {
          lint_rule: 8,
          title: "unused group",
          body: "some groups are not referenced, consider using (?:...)",
          patch: {some:RegexpStringPrinter.print_simple_list(new_regexp)}
        }
        RegexpLinter.add(res, err)
    }
  }

  /**
   * The easiest way to lint a character set is to rewrite
   * the set and then compare the results. If the length
   * of the resulting set is shorter than the length
   * of the initial set, we will suggest a fix.
   *
   * TODO: consider suggesting a fix if the strings don't match?
   */
  function lint_result check_set(rset set, lint_result res) {
    recursive function intset range_to_charmap(int start, int end, intset map) {
      map = IntSet.add(start, map)
      if (start == end) {
        map;
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
        items;
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
      res;
    } else {
      map = List.fold(set_to_charmap, set.items, IntMap.empty)
      new_set = {set with items: List.rev(charmap_to_set(map, []))}

      s1 = RegexpStringPrinter.print_set(new_set)
      s2 = RegexpStringPrinter.print_set(set)
      if (String.length(s1) < String.length(s2)) {
        err = {
          lint_rule: 9,
          title: "non optimal character range",
          body: "shorter way to write {s2}: {s1}",
          patch: {none}
        }
        RegexpLinter.add(res, err)
      } else {
        res;
      }
    }
  }
}

module RegexpLinter {

  function lint_result add(lint_result current, lint_error error) {
    if (IntSet.mem(error.lint_rule, current.matched_rules)) {
      current;
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

    res = RegexpLinterHelper.check_groups(re, res)

    RegexpLinterAnchor.check_anchors(re, res)
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
            body: "min is greater than max",
            patch: {none}
          }
          add(res, err)
        } else if (min == max) {
          err = {
            lint_rule: 2,
            title: "improve the quantifier",
            body: "\{{min},{max}\} can be written as \{{min}\}",
            patch: {none}
          }
          add(res, err)
        } else {
          res;
        }
      case {exact:_}:
        if (greedy == false) {
          err = {
            lint_rule: 3,
            title: "useless non greedy",
            body: "when matching an exact amount, using non greddy makes no sense",
            patch: {none}
          }
          add(res, err)
        } else {
          res;
        }
      case _:
        res
    }
  }

  function lint_result do_elementary(elementary e, lint_result res) {
    match (e) {
      case {id:_, ~group_id, ~egroup}:
        res = do_regexp(egroup, res)
        {res with groups: IntSet.add(group_id, res.groups)}
      case {~group_ref}:
        res = if (IntSet.mem(group_ref, res.groups)) {
          res;
        } else {
          err = {
            lint_rule: 4,
            title: "incorrect reference",
            body: "\\{group_ref} refers to an invalid capture group",
            patch: {none}
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
            body: "[{r.rstart}-{r.rend}] is invalid.",
            patch: {none}
          }
          add(res, err)
        } else if (r.rstart == r.rend) {
          err = {
            lint_rule: 6,
            title: "useless range in character class",
            body: "[{r.rstart}-{r.rend}] is useless.",
            patch: {none}
          }
          add(res, err)
        } else if (r.rstart == "A" && r.rend == "z") {
          err = {
            lint_rule: 7,
            title: "programmer laziness",
            body: "When you write A-z instead of A-Za-z, you are including 6 extra characters!",
            patch: {none}
          }
          add(res, err)
        } else {
          res;
        }
      case _:
        res
    }
  }
}
