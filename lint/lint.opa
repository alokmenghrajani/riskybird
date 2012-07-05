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

import stdlib.web.client

/* The status of the linter */
type lint_result = {
  set(lint_rule_type) matched_rules,
  list(lint_error) errors,
  intset groups,
  intset groups_referenced,
}

/* A lint error */
and lint_error = {
  lint_rule_type lint_rule,
  string title,
  string body,
  string class,
  option(string) patch,
}

and lint_rule_type =
  { inconsistent_start_anchors } or
  { inconsistent_end_anchors } or
  { unused_group } or
  { incorrect_reference } or
  { incorrect_quantifier } or
  { non_ideal_quantifier } or
  { useless_non_greedy } or
  { invalid_range_in_character_class } or
  { non_optimal_class_range } or
  { lazy_character_class } or
  { empty_character_class } or
  { improve_escaped_char } or
  { empty_regexp }

module RegexpLinterRender {
  function option(xhtml) render(lint_result result) {
    match (result.errors) {
      case {nil}: {none}
      case _:
        t = List.fold(
          function(error, r) {
            <>{r}{render_lint(error)}</>
          },
          result.errors,
          <></>)
        {some: <>{t}</>}
    }
  }

  client function xhtml render_lint(lint_error error) {
    patch = match (error.patch) {
      case {none}: <></>
      case {~some}:
        <>
          <a href="/?r={Uri.encode_string(some)}" class="btn btn-mini btn-success pull-right">
            apply fix
          </a>
          <br/>
        </>
    }
    <div class="alert {error.class}">
      <strong>{error.title}</strong><br/>
      {error.body}<br/>
      {patch}
    </div>
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
          lint_rule: {inconsistent_start_anchors},
          title: "inconsistent anchors",
          body: "start anchor is only applied in some cases",
          class: "alert-info",
          patch: {none}
        }
      } else {
        {
          lint_rule: {inconsistent_end_anchors},
          title: "inconsistent anchors",
          body: "end anchor is only applied in some cases",
          class: "alert-info",
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
        case {~hd, tl:_}: get_anchor_term(hd, r)
        case []: {at_start:true, result:[false]}        // WTF!!
      }
    } else {
      match (s) {
        case [hd]: get_anchor_term(hd, r)
        case {hd:_, ~tl}: get_anchor_alternative(tl, r)
        case []: {at_start:false, result:[false]}  // WTF!
      }
    }
  }

  function check_anchors get_anchor_term(term term, check_anchors r) {
    if (r.at_start == true) {
      match (term) {
        case {assertion: {anchor_start}}:
        {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {anchor_end}}:
          {at_start:true, result:List.cons(false, r.result)}
        case {assertion: {match_ahead:_}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {dont_match_ahead:_}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {match_word_boundary}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {dont_match_word_boundary}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {~atom, ...}:
          get_anchor_atom(atom, r)
      }
    } else {
      match (term) {
        case {assertion: {anchor_start}}:
          {at_start:false, result:List.cons(false, r.result)}
        case {assertion: {anchor_end}}:
          {at_start:false, result:List.cons(true, r.result)}
        case {assertion: {match_ahead:_}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {dont_match_ahead:_}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {match_word_boundary}}:
          {at_start:true, result:List.cons(true, r.result)}
        case {assertion: {dont_match_word_boundary}}:
          {at_start:true, result:List.cons(true, r.result)}
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

    t = f(IntSet.size(res.groups), res.groups_referenced)
    match (t) {
      case {none}: res
      case {some: unused_group}:
        regexp new_regexp = RegexpFixUnreferencedGroup.regexp(re, unused_group)
        err = {
          lint_rule: {unused_group},
          title: "unused group",
          body: "some groups are not referenced, consider using non capturing groups: (?:...)",
          class: "",
          patch: {some: RegexpStringPrinter.print_regexp(new_regexp)}
        }
        RegexpLinter.add(res, err)
    }
  }

  function int escaped_char_to_int(escaped_char escaped_char) {
    match (escaped_char) {
      case {~control_escape}:
        match (control_escape) {
          case "f": 12
          case "n": 10
          case "r": 13
          case "t": 9
          case "v": 11
          case _: 0
        }
      case {~control_letter}:
        mod(int_of_first_char(control_letter), 32)
      case {~hex_escape_sequence}:
        match (Parser.try_parse(Rule.hexadecimal_number, hex_escape_sequence)) {
          case {~some}: some
          case {none}: 0
        }
      case {~unicode_escape_sequence}:
        match (Parser.try_parse(Rule.hexadecimal_number, unicode_escape_sequence)) {
          case {~some}: some
          case {none}: 0
        }
      case {~identity_escape}:
        int_of_first_char(identity_escape)
      case {~character_class_escape}:
        int_of_first_char(character_class_escape)
    }
  }

  function int class_atom_to_int(class_atom class_atom) {
    match (class_atom) {
      case {~char}:
        int_of_first_char(char)
      case {~escaped_char}:
        escaped_char_to_int(escaped_char)
    }
  }

  function string int_to_hex(int i) {
    s = Int.to_hex(i)
    s = String.lowercase(s)
    String.pad_left("0", 2, s)
  }

  function string int_to_unicode_hex(int i) {
    s = Int.to_hex(i)
    s = String.lowercase(s)
    String.pad_left("0", 4, s)
  }

  function class_atom int_to_class_atom(int i) {
    if (i<33) {
      {escaped_char: {hex_escape_sequence: int_to_hex(i)}}
    } else if (i < 127) {
      {char: textToString(Text.from_character(i))}
    } else if (i < 256) {
      {escaped_char: {hex_escape_sequence: int_to_hex(i)}}
    } else {
      {escaped_char: {unicode_escape_sequence: int_to_unicode_hex(i)}}
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
        case {~class_atom}:
          IntSet.add(class_atom_to_int(class_atom), map)
        case {~start_char, ~end_char}:
          range_to_charmap(class_atom_to_int(start_char), class_atom_to_int(end_char), map)
      }
    }

    recursive function (list(class_range), map) charmap_to_range(int min, int max, intset map, list(class_range) class_ranges) {
      map = IntSet.remove(max, map)
      if (IntSet.mem(max+1, map)) {
        charmap_to_range(min, max+1, map, class_ranges)
      } else if (min == max) {
        class_range = {class_atom: int_to_class_atom(min)}
        class_ranges = List.cons(class_range, class_ranges)
        (class_ranges, map)
      } else if (min+1 == max) {
        class_range = {class_atom: int_to_class_atom(min)}
        class_ranges = List.cons(class_range, class_ranges)
        class_range = {class_atom: int_to_class_atom(max)}
        class_ranges = List.cons(class_range, class_ranges)
        (class_ranges, map)
      } else {
        class_range = {start_char: int_to_class_atom(min), end_char: int_to_class_atom(max)}
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

    if (Set.mem({invalid_range_in_character_class}, res.matched_rules) ||
        Set.mem({non_optimal_class_range}, res.matched_rules) ||
        Set.mem({lazy_character_class}, res.matched_rules)) {
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
          lint_rule: {non_optimal_class_range},
          title: "non optimal character range",
          body: "A shorter/cleaner way to write {s2} is {s1}",
          class: "",
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
    if (Set.mem(error.lint_rule, current.matched_rules)) {
      current;
    } else {
      matched_rules = Set.add(error.lint_rule, current.matched_rules)
      errors = List.cons(error, current.errors)
      {current with ~matched_rules, ~errors}
    }
  }

  function lint_result regexp(regexp re) {
    lint_result res = {
      matched_rules: Set.empty,
      errors: [],
      groups: IntSet.empty,
      groups_referenced: IntSet.empty
    }
    res = do_regexp(re, res)

    res = RegexpLinterHelper.check_groups(re, res)

    RegexpLinterAnchor.check_anchors(re, res)
  }

  function lint_result do_regexp(regexp re, lint_result res) {
    if (re == [[]]) {
      err = {
        lint_rule: {empty_regexp},
        title: "empty regexp",
        body: "javascript does not let you write empty regular expressions since // starts a line comment.",
          class: "alert-error",
          patch: {some: "/(?:)/"}
      }
      RegexpLinter.add(res, err)
    } else {
      List.fold(function(e, r){do_alternative(re, e, r)}, re, res)
    }
  }

  function lint_result do_alternative(regexp re, alternative s, lint_result res) {
    List.fold(function(e,r){do_term(re, e, r)}, s, res)
  }

  function lint_result do_term(regexp re, term term, lint_result res) {
    match (term) {
      case {id:_, ~atom, ~quantifier, ~greedy}:
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
            lint_rule: {incorrect_quantifier},
            title: "incorrect quantifier",
            body: "min is greater than max",
            class: "alert-error",
            patch: {none}
          }
          add(res, err)
        } else if (min == max) {
          err = {
            lint_rule: {non_ideal_quantifier},
            title: "improve the quantifier",
            body: "\{{min},{max}\} can be written as \{{min}\}",
            class: "",
            patch: {none}
          }
          add(res, err)
        } else {
          res;
        }
      case {exactly:_}:
        if (greedy == false) {
          err = {
            lint_rule: {useless_non_greedy},
            title: "useless non greedy",
            body: "when matching an exact amount, using non greddy makes no sense",
            class: "",
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
      case {~ncgroup}:
        do_regexp(ncgroup, res)
      case {~group_ref}:
        res = if (IntSet.mem(group_ref, res.groups)) {
          res;
        } else {
          err = {
            lint_rule: {incorrect_reference},
            title: "incorrect reference",
            body: "\\{group_ref} refers to an invalid capture group",
            class: "alert-error",
            patch: {none}
          }
          add(res, err)
        }
        {res with groups_referenced: IntSet.add(group_ref, res.groups_referenced)}
      case {~escaped_char}:
        LintEscapedChar.escaped_char(escaped_char, res)
      case {~id, ~char_class}:
        res = List.fold(do_item, char_class.class_ranges, res)
        res = RegexpLinterHelper.check_set(re, id, char_class, res)

        // Check if the character class is empty.
        if (List.is_empty(char_class.class_ranges)) {
          err = if (char_class.neg) {
            {
              lint_rule: {empty_character_class},
              title: "empty negative character class",
              body: "[^] is equivalent to . and will match any character.",
              class: "",
              patch: {none}
            }
          } else {
            {
              lint_rule: {empty_character_class},
              title: "empty character class",
              body: "[] is an empty character class and will never match.",
              class: "",
              patch: {none}
            }
          }
          add(res, err)
        } else {
          res;
        }
      case _:
        res
    }
  }

  function lint_result do_item(class_range i, lint_result res) {
    match (i) {
      case {~start_char, ~end_char}:
        start = RegexpLinterHelper.class_atom_to_int(start_char)
        end = RegexpLinterHelper.class_atom_to_int(end_char)

        start2 = RegexpStringPrinter.print_class_atom(start_char)
        end2 = RegexpStringPrinter.print_class_atom(end_char)

        if (start > end) {
          err = {
            lint_rule: {invalid_range_in_character_class},
            title: "invalid range in character class",
            body: "[{start2}-{end2}] is invalid.",
            class: "alert-error",
            patch: {none}
          }
          add(res, err)
        } else if (start == end) {
          err = {
            lint_rule: {non_optimal_class_range},
            title: "useless range in character class",
            body: "[{start2}-{end2}] is useless.",
            class: "",
            patch: {none}
          }
          add(res, err)
        } else if (start_char == {char: "A"} && end_char == {char: "z"}) {
          err = {
            lint_rule: {lazy_character_class},
            title: "programmer laziness",
            body: "When you write A-z instead of A-Za-z, you are matching on 6 extra characters!",
            class: "",
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
