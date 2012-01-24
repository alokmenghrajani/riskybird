/**
 * This printer is used in the Lint engine to convert
 * a transformed regexp back into a string
 */
module RegexpStringPrinter {
  function string pretty_print(option(regexp) parsed_regexp) {
    match (parsed_regexp) {
      case {none}:
        ""
      case {some: x}:
        start_anchor = if (x.start_anchor) { "^" } else { "" }
        end_anchor = if (x.end_anchor) { "$" } else { "" }
        "{start_anchor}{print_simple_list(x.core)}{end_anchor}"
     }
  }

  function string print_simple_list(core_regexp regexp) {
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
    "{print_elementary(basic.belt)}{print_postfix(basic.bpost)}"
  }

  function string print_elementary(elementary elementary) {
    match (elementary) {
      case {edot}: "."
      case {~echar}: "{echar}"
      case {~egroup}: "({print_simple_list(egroup)})"
      case {~eset}: "{print_set(eset)}"
    }
  }

  function print_set(rset set) {
    t = List.fold(
      function(item, r) {
        i = match (item) {
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
    }
  }
}
