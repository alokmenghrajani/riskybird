server exposed function my_log(obj) {
  Debug.warning(Debug.dump(obj))
}

/**
 * Given a list, check if all elements are the same.
 */
function bool list_check_all_same(list('a) l) {
  t = List.fold(
    function('a e, r) {
      if (r.result == false) {
        r;
      } else {
        match (r.elements) {
          case {none}: {elements: {some: e}, result: true}
          case {~some}: if (some == e) { r; } else { {elements: {some: e}, result: false} }
        }
      }
    },
    l,
    {elements: {none}, result: true}
  )
  t.result
}
