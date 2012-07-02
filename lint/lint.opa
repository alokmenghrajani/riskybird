/**
 * Lint engine for regular expressions.
 *
 * The purpose of the lint engine is to detect common mistakes people make when
 * composing regular expressions.
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
              <div class="alert alert-error">
                <strong>{error.title}</strong><br/>
                {error.body}<br/>
                {patch}
              </div>
              {r}
            </>
          },
          result.errors,
          <></>
        )
        {some: <>{t}</>}
    }
  }
}

/**
 * Provides lint rules to detect inconsistent anchors.
 *
 * We first find all the first and last term elements in the
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
    List.fold(get_anchor_alternative, re, r)
  }

  function check_anchors get_anchor_alternative(alternative s, check_anchors r) {
    if (r.at_start == true) {
      match (s) {
        case {~hd, ~tl}: get_anchor_term(hd, r)
        case []: {at_start:true, result:[false]}        // WTF!!
      }
    } else {
      match (s) {
        case [hd]: get_anchor_term(hd, r)
        case {~hd, ~tl}: get_anchor_alternative(tl, r)
        case []: {at_start:false, result:[false]}  // WTF!
      }
    }
  }

  function check_anchors get_anchor_term(term term, check_anchors r) {
    if (r.at_start == true) {
      match (term) {
        case {assertion: {anchor_start}}: {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {anchor_end}}: {at_start:true, result:List.cons(false, r.result)}
        case {~atom, ...}: get_anchor_atom(atom, r)
      }
    } else {
      match (term) {
        case {assertion: {anchor_start}}: {at_start:false, result:List.cons(false, r.result)}
        case {assertion: {anchor_end}}: {at_start:false, result:List.cons(true, r.result)}
        case {~atom, ...}: get_anchor_atom(atom, r)
      }
    }
  }

  function check_anchors get_anchor_atom(atom atom, check_anchors r) {
    match (atom) {
      case {~group, ...}: get_anchor_regexp(group, r)
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
          patch: {some: RegexpStringPrinter.print_regexp(new_regexp)}
        }
        RegexpLinter.add(res, err)
    }
  }

  /**
   * The easiest way to lint a character set is to rewrite
   * the set and then compare the results. If the length
   * of the resulting set is shorter than the length
   * of the initial set, we will suggest a fix.
   */
  function lint_result check_set(regexp re, int character_class_id, character_class set, lint_result res) {
    recursive function intset range_to_charmap(int start, int end, intset map) {
      map = IntSet.add(start, map)
      if (start == end) {
        map;
      } else {
        range_to_charmap(start+1, end, map)
      }
    }

    function intset set_to_charmap(class_range i, intset map) {
      match (i) {
        case {~char}:
          IntSet.add(int_of_first_char(char), map)
        case {~start_char, ~end_char}:
          range_to_charmap(int_of_first_char(start_char), int_of_first_char(end_char), map)
      }
    }

    recursive function (list(class_range), map) charmap_to_range(int min, int max, intset map, list(class_range) class_ranges) {
      map = IntSet.remove(max, map)
      if (IntSet.mem(max+1, map)) {
        charmap_to_range(min, max+1, map, class_ranges)
      } else if (min == max) {
        class_range = {char: textToString(Text.from_character(min))}
        class_ranges = List.cons(class_range, class_ranges)
        (class_ranges, map)
      } else if (min+1 == max) {
        class_range = {char: textToString(Text.from_character(min))}
        class_ranges = List.cons(class_range, class_ranges)
        class_range = {char: textToString(Text.from_character(max))}
        class_ranges = List.cons(class_range, class_ranges)
        (class_ranges, map)
      } else {
        class_range = {start_char: textToString(Text.from_character(min)), end_char: textToString(Text.from_character(max))}
        class_ranges = List.cons(class_range, class_ranges)
        (class_ranges, map)
      }
    }

    recursive function charmap_to_set(intset map, list(class_range) class_ranges) {
      if (IntSet.is_empty(map)) {
        class_ranges;
      } else {
        (int min, _) = IntMap.min_binding(map)
        (class_ranges, map) = charmap_to_range(min, min, map, class_ranges)
        charmap_to_set(map, class_ranges)
      }
    }

    if (IntSet.mem(5, res.matched_rules) ||
        IntSet.mem(6, res.matched_rules) ||
        IntSet.mem(7, res.matched_rules)) {
      // if rules 5, 6 or 7 matched, we'll skip this one.
      res;
    } else {
      map = List.fold(set_to_charmap, set.class_ranges, IntMap.empty)
      new_set = {set with class_ranges: List.rev(charmap_to_set(map, []))}

      s1 = RegexpStringPrinter.print_character_class(new_set)
      s2 = RegexpStringPrinter.print_character_class(set)
      if (s1 != s2) {
        regexp new_regexp = RegexpFixNonOptimalCharacterRange.regexp(re, character_class_id, new_set)
        err = {
          lint_rule: 9,
          title: "non optimal character range",
          body: "shorter way to write {s2}: {s1}",
          patch: {some: RegexpStringPrinter.print_regexp(new_regexp)}
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
    List.fold(function(e, r){do_alternative(re, e, r)}, re, res)
  }

  function lint_result do_alternative(regexp re, alternative s, lint_result res) {
    List.fold(function(e,r){do_term(re, e, r)}, s, res)
  }

  function lint_result do_term(regexp re, term b, lint_result res) {
    match (b) {
      case {~id, ~atom, ~quantifier, ~greedy}:
        // process quantifier
        res = do_quantifier(quantifier, greedy, res)
        // process atom
        do_atom(re, atom, res)
      case _:
        res
    }
  }

  function lint_result do_quantifier(quantifier bpost, bool greedy, lint_result res) {
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
      case {exactly:_}:
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

  function lint_result do_atom(regexp re, atom atom, lint_result res) {
    match (atom) {
      case {id:_, ~group_id, ~group}:
        res = do_regexp(group, res)
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
      case {~id, ~char_class}:
        res = List.fold(do_item, char_class.class_ranges, res)
        RegexpLinterHelper.check_set(re, id, char_class, res)
      case _:
        res
    }
  }

  function lint_result do_item(class_range i, lint_result res) {
    match (i) {
      case {~start_char, ~end_char}:
        if (start_char > end_char) {
          err = {
            lint_rule: 5,
            title: "invalid range in character class",
            body: "[{start_char}-{end_char}] is invalid.",
            patch: {none}
          }
          add(res, err)
        } else if (start_char == end_char) {
          err = {
            lint_rule: 6,
            title: "useless range in character class",
            body: "[{start_char}-{end_char}] is useless.",
            patch: {none}
          }
          add(res, err)
        } else if (start_char == "A" && end_char == "z") {
          err = {
            lint_rule: 7,
            title: "programmer laziness",
            body: "When you write A-z instead of A-Za-z, you are matching on 6 extra characters!",
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
