/**
 * This printer is used in the Lint engine to convert
 * a transformed regexp back into a string
 */
module RegexpStringPrinter {
  function string pretty_print(option(regexp) parsed_regexp) {
    match (parsed_regexp) {
      case {none}:
        ""
      case {some: x}: print_simple_list(x)
     }
  }

  function string print_simple_list(regexp regexp) {
    String.concat("|", List.map(print_basic_list, regexp))
  }

  function string print_basic_list(simple simple) {
    List.fold(
      function (basic, r) {
        "{r}{print_basic(basic)}"
      },
      simple,
      ""
    )
  }

  function string print_basic(basic basic) {
    match (basic) {
      case {id:_, ~belt, ~bpost, ~greedy}:
        g = if(greedy) {""} else {"?"}
        "{print_elementary(belt)}{print_postfix(bpost)}{g}"
      case { anchor_start }:
        "^"
      case { anchor_end }:
        "$"
    }
  }

  function string print_elementary(elementary elementary) {
    match (elementary) {
      case {edot}: "."
      case {~echar}: "{echar}"
      case {group_ref:x}: "\\{x}"
      case {escaped_char:x}: "\\{x}"
      case {group_id:_, ~egroup}: "({print_simple_list(egroup)})"
      case {~eset}: "{print_set(eset)}"
    }
  }

  function print_set(rset set) {
    t = List.fold(
      function(item, r) {
        i = match (item) {
          case {~iechar}: "\\{iechar}"
          case {~ichar}: "{ichar}"
          case {~irange}: "{irange.rstart}-{irange.rend}"
        }
        "{r}{i}"
      },
      set.items,
      ""
    )
    if (set.neg) {
      "[^{t}]"
    } else {
      "[{t}]"
    }
  }

  function string print_postfix(postfix) {
    match (postfix) {
      case {noop}: ""
      case {star}: "*"
      case {plus}: "+"
      case {qmark}: "?"
      case {exact: x}: "\{{x}\}"
      case {at_least: x}: "\{{x},\}"
      case {~min, ~max}: "\{{min},{max}\}"
    }
  }
}
