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
        // in a character class, \b means \x08. We don't really need to track if we are in the character class case,
        // because \b in a regexp gets parsed as a {match_word_boundary}.
        if (identity_escape == "b") {
          8;
        } else {
          int_of_first_char(identity_escape)
        }
      case {~character_class_escape}:
        int_of_first_char(character_class_escape)
    }
  }

  /**
   * Takes an int and converts it to a two character hex string.
   *
   * E.g. 10 => 0a
   */
  function string int_to_hex(int i) {
    s = Int.to_hex(i)
    s = String.lowercase(s)
    String.pad_left("0", 2, s)
  }

  /**
   * Takes an int and converts it to a four character hex string.
   *
   * E.g. 10 => 000a
   */
  function string int_to_unicode_hex(int i) {
    s = Int.to_hex(i)
    s = String.lowercase(s)
    String.pad_left("0", 4, s)
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

  function lint_result do_quantifier(quantifier quantifier, bool greedy, lint_result res) {
    match (quantifier) {
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
        } else if ((min == 0) && (max == 1)) {
          err = {
            lint_rule: {non_ideal_quantifier},
            title: "improve the quantifier",
            body: "\{0,1\} can be written as ?",
            class: "",
            patch: {none}
          }
          add(res, err)
        } else {
          res;
        }
      case {at_least:0}:
        err = {
          lint_rule: {non_ideal_quantifier},
          title: "improve the quantifier",
          body: "\{0,\} can be written as *",
          class: "",
          patch: {none}
        }
        add(res, err)
      case {at_least:1}:
        err = {
          lint_rule: {non_ideal_quantifier},
          title: "improve the quantifier",
          body: "\{1,\} can be written as +",
          class: "",
          patch: {none}
        }
        add(res, err)
      case {~exactly}:
        if (greedy == false) {
          err = {
            lint_rule: {useless_non_greedy},
            title: "useless non greedy",
            body: "when matching an exact amount, using non greddy makes no sense",
            class: "",
            patch: {none}
          }
          add(res, err)
        } else if (exactly == 0) {
          err = {
            lint_rule: {non_ideal_quantifier},
            title: "remove the quantifier",
            body: "\{0\} makes no sense.",
            class: "alert-error",
            patch: {none}
          }
          add(res, err)
        } else if (exactly == 1) {
          err = {
            lint_rule: {non_ideal_quantifier},
            title: "remove the quantifier",
            body: "\{1\} makes no sense.",
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
        LintCharacterClass.character_class(re, id, char_class, res)
      case _:
        res
    }
  }
}
