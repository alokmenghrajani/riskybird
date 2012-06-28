/**
 * Code used to apply a lint rule automatically.
 */

module RegexpFixUnreferencedGroup {
  function regexp regexp(regexp re, int id_to_match) {
    List.map(function(e){alternative(e, id_to_match)}, re)
  }

  function alternative alternative(alternative s, int id_to_match) {
    List.map(function(e){term(e, id_to_match)}, s)
  }

  function term term(term b, int id_to_match) {
    match (b) {
      case {~id, ~belt, ~bpost, ~greedy}:
        {~id, belt: atom(belt, id_to_match), ~bpost, ~greedy}
      case _: b
    }
  }

  function atom atom(atom belt, int id_to_match) {
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

module RegexpFixNonOptimalCharacterRange {
  function regexp regexp(regexp re, int character_class_id, character_class new_range) {
    List.map(function(e){alternative(e, character_class_id, new_range)}, re)
  }

  function alternative alternative(alternative s, int character_class_id, character_class new_range) {
    List.map(function(e){term(e, character_class_id, new_range)}, s)
  }

  function term term(term b, int character_class_id, character_class new_range) {
    match (b) {
      case {~id, ~belt, ~bpost, ~greedy}:
        {~id, belt: atom(belt, character_class_id, new_range), ~bpost, ~greedy}
      case _: b
    }
  }

  function atom atom(atom belt, int character_class_id, character_class new_range) {
    match (belt) {
      case {~id, eset:_}:
        if (id == character_class_id) {
          {~id, eset:new_range}
        } else {
          belt;
        }
      case _: belt
    }
  }
}
