
type candidate = {
  int                grp,
  list(list(string)) matched,
  list(string)       rest,
  intmap(list(string))     groups,
}

type candidates = list(candidate)

function candidates apply_candidate(f, candidate cand, candidates acc) {
  match(f(cand)) {
    case {none}: acc
    case {some: cand}: List.cons(cand, acc)
  }
}

function candidates map_candidates(f, candidates cands) {
  List.fold(apply_candidate(f, _, _), cands, [])
}

function list(list(string)) add_match(string c, list(list(string)) matched) {
  match(matched) {
    case {nil}:
      {nil} // should never happen
    case {~hd, ~tl}:
      {hd: List.cons(c, hd), ~tl}
  }
}

function option(candidate) consume(string char, candidate cand) {
  match(cand.rest) {
    case {nil}: {none}
    case {~hd, ~tl}:
      if(hd == char) {
       {some:{cand with matched: add_match(hd, cand.matched), rest:tl}}
      } else {none}
  }
}

function option(candidate) consume_any(candidate cand) {
  match(cand.rest) {
    case {nil}: {none}
    case {~hd, ~tl}: {some:{cand with matched: add_match(hd, cand.matched), rest:tl}}
  }
}

function option(candidate) consume_list(list(string) l, candidate cand) {
   match(l) {
     case {nil}: {some: cand}
     case {~hd, ~tl}:
       match(consume(hd, cand)) {
         case {none}: {none}
         case {some: cand}: consume_list(tl, cand)
       }
   }
}

function option(candidate) consume_group(int n, candidate cand) {
  match(IntMap.get(n, cand.groups)) {
    case {none}: {none}
    case {~some}: consume_list(some, cand)
  }
}


function candidates core_regexp(core_regexp re, candidates cands) {
  match(re) {
    case {nil}:
      []
    case {~hd, ~tl}:
      List.append(simple(hd, cands), core_regexp(tl, cands))
  }
}

function candidates simple(simple re, candidates cands) {
  match(re) {
    case {nil}:
      cands
    case {~hd, ~tl}:
      simple(tl, basic(hd, cands))
  }
}

function candidates basic(basic re, candidates cands) {
  elt = re.belt
  match(re.bpost) {
    case { noop }:
      elementary(elt, cands)
    case { star }:
      match(elt) {
        case {edot}:
          // Otherwise it loops, . always returns something
          List.append(repeat_elt({qmark}, cands), cands)
        case _:
          repeat_elt(elt, cands)
      }
    case { plus }:
      simple([{belt:elt, bpost:{noop}}, {belt:elt, bpost:{star}}], cands)
    case { exact: n}:
      if(n <= 0)
        cands
      else {
        cands = basic({belt:elt, bpost:{noop}}, cands)
        basic({belt:elt, bpost: {exact: (n-1)}}, cands)
      }
    case { at_least: n}:
      if(n <= 0)
        basic({belt:elt, bpost:{star}}, cands)
      else {
        cands = basic({belt:elt, bpost:{noop}}, cands)
        basic({belt:elt, bpost: {exact: (n-1)}}, cands)
      }
    case _: [] /* TODO */
/*
  { int min, int max }
*/
  }
}

function candidates repeat_elt(elementary elt, candidates cands) {
  match(elementary(elt, cands)) {
    case {nil}:
      cands
    case l:
      List.append(repeat_elt(elt, l), cands)
  }
}

function candidate push_matched(candidate cand) {
 { cand with matched: List.cons([], cand.matched)}
}

function candidate pop_matched(candidate cand) {
  match(cand.matched) {
     case {nil}: // should never happen
       cand
     case {~hd, ~tl}:
       { cand with
           grp: cand.grp + 1,
           matched: tl,
           groups: IntMap.add(cand.grp, List.rev(hd), cand.groups)
       }
   } 
}

function candidates elementary(elementary elt, candidates cands) {
  match(elt) {
    case { qmark }:
      map_candidates(consume_any, cands)
    case { edot }:
      List.append(map_candidates(consume_any, cands), cands)
    case {escaped_char:"1"}:
      map_candidates(consume_group(1, _), cands)
    case { ~echar }:
      map_candidates(consume(echar, _), cands)
    case { ~escaped_char }:
      map_candidates(consume(escaped_char, _), cands)
    case { egroup: re }:
      cands = List.map(push_matched, cands)
      cands = core_regexp(re, cands)
      cands = List.map(pop_matched, cands)
      cands
    case _ /* TODO */: []
/*
    { rset eset }
*/
  }

}

function test(f2, f1) {
  s = f1
  re = RegexpParser.parse(f2)
  match(re) {
    case {none}: false
    case {some: x}:
      re = x.core
      sl = String.fold(List.cons, s, [])
      sl = List.rev(sl)
      st = [{grp: 1, matched:[[]], rest:sl, groups:IntMap_empty}]
      res = core_regexp(re, st)
      List.exists(function(x){ x.rest == {nil}}, res)
  }

}
