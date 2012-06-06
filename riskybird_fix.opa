/**
 * Code used to apply a lint rule automatically.
 */

module RegexpFixUnreferencedGroup {
  function regexp regexp(regexp re, int id_to_match) {
    List.map(function(e){simple(e, id_to_match)}, re)
  }

  function simple simple(simple s, int id_to_match) {
    List.map(function(e){basic(e, id_to_match)}, s)
  }

  function basic basic(basic b, int id_to_match) {
    match (b) {
      case {~id, ~belt, ~bpost, ~greedy}:
        {~id, belt: elementary(belt, id_to_match), ~bpost, ~greedy}
      case _: b
    }
  }

  function elementary elementary(elementary belt, int id_to_match) {
    match (belt) {
      case {id:_, ~group_id, ~egroup}:
        if (group_id == id_to_match) {
          {ncgroup:egroup}
        } else {
          belt;
        }
      case _: belt
    }
  }
}
