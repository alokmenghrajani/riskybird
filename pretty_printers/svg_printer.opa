/**
 * RiskyBird SVG printer.
 *
 * Converts a parsed regexp into svg (scalable vector graphics).
 *
 * We initially tried to pretty print the regexp using xhtml. SVG however
 * looks much nicer and gives us a ton of flexibility.
 *
 * Doing things in SVG land is however a little more complicated. We need to:
 * 1. convert the regexp into SVG nodes.
 * 2. compute the position of every SVG node by:
 *    2.1: computing each node's dimensions
 *    2.2: recomputing each node's dimensions to take all available space
 *    2.3: find the x/y position for each node
 * 3. generate the pair of arrows
 * 4. generate the xml
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

module RegexpSvgPrinter {
  function getDimensions(SvgElement node) {
    match (node) {
      case {node:e}: {width: e.width, height: e.height}
      case {choice:e}: {width: e.width, height: e.height}
      case {seq:e}: {width: e.width, height: e.height}
    }
  }

  function xhtml pretty_print(option(regexp) parsed_regexp) {
    match (parsed_regexp) {
      case {none}:
        <>
          <div class="alert-message error">
            <strong>oh snap!</strong> Parsing failed!
          </div>
        </>
      case {some: regexp}:
        //unanchored_starts = RegexpAnchor.findUnanchoredStarts(regexp)
        //unanchored_ends = RegexpAnchor.findUnanchoredEnds(regexp)

        nodes = RegexpToSvg.regexp(regexp)

        nodes = computeLayout(nodes)
        svg = toXml(nodes)
        arrows = drawArrows(nodes)

        d = getDimensions(nodes)
        <svg:svg xmlns:svg="http://www.w3.org/2000/svg" version="1.1" style="height: {d.height+2}px; width: {d.width+2}px">
          {svg}
          {arrows}
        </svg:svg>
     }
  }

  function SvgElement computeLayout(SvgElement node) {
    function SvgMaxSum computeMaxSum(list(SvgElement) nodes) {
      /**
       * Returns the sum_width, max_width, sum_height and max_height,
       * given a list of SvgElement
       */
       List.fold(
         function(e, r) {
           d = getDimensions(e)
           { max_width: Int.max(r.max_width, d.width),
             sum_width: r.sum_width + d.width,
             max_height: Int.max(r.max_height, d.height),
             sum_height: r.sum_height + d.height }
         },
         nodes,
         {max_width: 0, sum_width: 0, max_height: 0, sum_height: 0}
       )
    }
    recursive function SvgElement computeDimensions(SvgElement node) {
      match (node) {
        case {~node}:
          // to compute the dimensions of a node we look at its content
          width = 70 + String.length(node.label)*7
          {node: {node with ~width, height: 80}}
        case {~choice}:
          // to compute the dimensions of a sequence of nodes:
          // 1. compute the layout of every inner element
          // 2. set this element's width to max(all inner elements)
          // 3. set this element's height to sum(all inner heights)
          items = List.map(computeDimensions, choice.items)
          SvgMaxSum max_sum = computeMaxSum(items)
          {choice: {choice with width:max_sum.max_width, height: max_sum.sum_height, ~items}}
        case {~seq}:
          // to compute the dimensions of a sequence of nodes:
          // 1. compute the layout of every inner element
          // 2. set this element's width to sum(all inner elements)
          // 3. set this element's height to max(all inner heights)
          items = List.map(computeDimensions, seq.items)
          SvgMaxSum max_sum = computeMaxSum(items)
          {seq: {seq with width: max_sum.sum_width, height: max_sum.max_height + seq.border/2, ~items}}
      }
    }

    recursive function SvgElement computeResize(SvgElement node, int width, int height) {
      match (node) {
        case {~node}:
          // to resize a node, we simply set the new values
          {node: {node with ~width, ~height}}
        case {~choice}:
          // height increase will be distributed
          int delta_height = Float.to_int(Float.of_int((height - choice.height)) / Float.of_int(List.length(choice.items)))
          items = List.map(function(e){
            d = getDimensions(e)
            computeResize(e, width, d.height + delta_height)},
            choice.items
          )
          {choice: {~width, ~height, ~items}}
        case {~seq}:
          // width increase will be distributed
          int delta_width = Float.to_int(Float.of_int(width - seq.width - seq.border) / Float.of_int(List.length(seq.items)))
          items = List.map(function(e){
            d = getDimensions(e)
            computeResize(e, d.width + delta_width, height - seq.border)},
            seq.items
          )
          {seq: {seq with ~width, ~height, ~items}}
      }
    }

    recursive function computePositions(SvgElement node, int x, int y) {
      match (node) {
        case {~node}: {node: {node with ~x, ~y}}
        case {~choice}:
          t = List.fold(
            function(SvgElement e, r) {
              new_e = computePositions(e, r.x, r.y)
              d = getDimensions(new_e)
              {x: r.x, y:r.y+d.height, l:List.cons(new_e, r.l)}
            },
            choice.items,
            {~x, ~y, l:[]}
          )
          {choice: {choice with items:t.l}}
        case {~seq}:
          t = List.fold(
            function(SvgElement e, r) {
              new_e = computePositions(e, r.x, r.y)
              d = getDimensions(new_e)
              {x: r.x + d.width, y:r.y, l:List.cons(new_e, r.l)}
            },
            seq.items,
            {x: x+seq.border/2, y: y+seq.border/2, l:[]}
          )
          {seq: {seq with items:t.l, x: x, y: y}}
      }
    }

    node = computeDimensions(node)
    d = getDimensions(node)
    node = computeResize(node, d.width, d.height)
    computePositions(node, 1, 1)
  }

  function xhtml toXml(SvgElement nodes) {
    function xhtml toXmlNode(SvgNode node) {
      x = node.x + node.width / 2
      y = node.y + node.height / 2
      width = 10 + String.length(node.label)*7
      height = 30
      c = Color.color_to_string(node.color)
      s2 = "fill:{c};font-size: 15px;text-anchor:middle;"
      <>
        <svg:rect x={x-width/2} y={y-height/2} rx="20" ry="20" width={width} height={height}
          style="fill:none; stroke:{c};stroke-width:1"/>
        <svg:text x={x} y={y+5} style="{s2}">{node.label}</svg:text>
      </>
    }

    function xhtml toXmlNodes(list(SvgElement) nodes) {
      List.fold(
        function(e, r) {
          <>{r}{toXml(e)}</>
        },
        nodes,
        <></>
      )
    }

    match (nodes) {
      case {~node}: toXmlNode(node)
      case {~choice}: toXmlNodes(choice.items)
      case {~seq}:
        items = toXmlNodes(seq.items)
        rect = if (seq.border > 0) {
          <svg:rect x={seq.x} y={seq.y} width={seq.width} height={seq.height}
            style="fill: none; stroke: blue; stroke-width: 1;"/>
        } else {
          <></>
        }
        text = match (seq.group_id) {
          case {~some}:
            <svg:text x={seq.x+2} y={seq.y+10} height="8">{some}</svg:text>
          case {none}:
            <></>
        }
        <>
          {rect}
          {text}
          {items}
        </>
    }
  }

  function xhtml drawArrows(SvgElement node) {
    /**
     * Find all the pairs of arrows
     * and then render them
     */
    recursive function computeArrows(SvgElement node, list(SvgNode) prev, pairs) {
      match (node) {
        case {~node}:
          pairs = List.fold(
            function(e, r) {
              List.cons((e, node), r)
            },
            prev,
            pairs
          )
          {~pairs, prev: [node]}
        case {~choice}:
          List.fold(
            function(e, r) {
              t = computeArrows(e, prev, r.pairs)
              // combine t.prev with r.prev
              x = List.append(t.prev, r.prev)
              {pairs: t.pairs, prev: x}
            },
            choice.items,
            {~pairs, prev: []}
          )
        case {~seq}:
          List.fold(
            function(e, r) {
              computeArrows(e, r.prev, r.pairs)
            },
            seq.items,
            {~pairs, ~prev}
          )
      }
    }

    arrows = computeArrows(node, [], [])
    List.fold(
      function((a1, a2), r) {
        // starting point
        x1 = a2.x + a2.width - 20
        y1 = a2.y + a2.height / 2

        // arrow tip
        x4 = a1.x + 20
        y4 = a1.y + a1.height / 2

        // bezier curve
        x2 = x1 + (x4 - x1) / 4
        y2 = y1

        // bezier curve
        x3 = x4 - (x4 - x1) / 4
        y3 = y4

        d1 = "M{x4},{y4} L{x4-7},{y4-4} L{x4-5},{y4} L{x4-7},{y4+4} L{x4},{y4}"
        d2 = "M{x1},{y1} C{x2},{y2} {x3},{y3} {x4},{y4}"
        <>
          {r}
          <svg:path d={d1} style="fill:rgb(0,0,0); stroke:rgb(0,0,0);stroke-width:2"/>
          <svg:path d={d2} style="fill:none; stroke:rgb(0,0,0);stroke-width:2"/>
        </>
      },
      arrows.pairs,
      <></>
    )
  }
}

type SvgElement =
  { SvgNode node} or
  { SvgChoice choice} or
  { SvgSeq seq }

and SvgNode =
  { string label,
    int width,
    int height,
    int x,
    int y,
    Color.color color }

and SvgChoice =
  { int width,
    int height,
    list(SvgElement) items }

and SvgSeq =
  { option(string) group_id,
    int width,
    int height,
    int x,
    int y,
    int border,
    list(SvgElement) items }

and SvgMaxSum =
  { int max_width,
    int sum_width,
    int max_height,
    int sum_height }

module RegexpToSvg {
  recursive function SvgElement regexp(regexp r) {
    items = List.map(alternative, r)
    {choice: {width: 0, height: 0, ~items}}
  }

  function SvgElement alternative(alternative s) {
    items = List.map(term, s)
    {seq: {group_id: {none}, width: 0, height: 0, x: 0, y: 0, border: 0, ~items}}
  }

  function SvgElement term(term b) {
    match (b) {
      // todo: we are currently dropping the quantifier
      case {~atom, ...}: do_atom(atom)
      case {assertion: {anchor_start}}: {node: {label: "^", width: 0, height: 0, x: 0, y: 0, color: Color.cadetblue}}
      case {assertion: {anchor_end}}: {node: {label: "$", width: 0, height: 0, x: 0, y: 0, color: Color.cadetblue}}
      case {assertion: {match_word_boundary}}: {node: {label: "\\b", width: 0, height: 0, x: 0, y: 0, color: Color.cadetblue}}
      case {assertion: {dont_match_word_boundary}}: {node: {label: "\\B", width: 0, height: 0, x: 0, y: 0, color: Color.cadetblue}}
      case {assertion: {~match_ahead}}:
        {seq: {group_id: {some: "?="}, width: 0, height: 0, x: 0, y: 0, border: 20, items: [regexp(match_ahead)]}}
      case {assertion: {~dont_match_ahead}}:
        {seq: {group_id: {some: "?!"}, width: 0, height: 0, x: 0, y: 0, border: 20, items: [regexp(dont_match_ahead)]}}
    }
  }

  function SvgElement do_atom(atom atom) {
    match (atom) {
      case {~char}:
        {node: {label: char, width: 0, height: 0, x:0, y: 0, color: Color.black}}
      case {dot}:
        {node: {label: ".", width: 0, height: 0, x:0, y: 0, color: Color.cadetblue}}
      case {~character_class_escape}:
        {node: {label: "\\{character_class_escape}", width:0, height:0, x:0, y:0, color: Color.cadetblue}}
      case {~escaped_char}:
        do_escaped_char(escaped_char)
      case {~group_ref}: {node: {label: "\\{group_ref}", width: 0, height: 0, x:0, y: 0, color: Color.cadetblue}}
      case {~group, ~group_id, ...}:
        {seq: {group_id: {some: "{group_id}"}, width: 0, height: 0, x: 0, y: 0, border: 20, items: [regexp(group)]}}
      case {~ncgroup, ...}:
        {seq: {group_id: {none}, width: 0, height: 0, x: 0, y: 0, border: 20, items: [regexp(ncgroup)]}}
      case {~char_class, ...}:
        do_character_class(char_class)
    }
  }

  function do_character_class(character_class char_class) {
    t1 = List.map(
      function(item) {
        match (item) {
          case {~char}: if (char == " ") "⎵" else char
          case {~escaped_char}: print_escaped_char(escaped_char)
          case {~start_char, ~end_char}: "{start_char}-{end_char}"
        }
      },
      char_class.class_ranges)
    t2 = join(t1, ",")

    s = if (char_class.neg) {
      "[^{t2}]"
    } else {
      "[{t2}]"
    }
    {node: {label: s, width: 0, height: 0, x:0, y: 0, color: Color.black}}
  }

  function string join(list(string) l, string glue) {
    match (l) {
      case []: ""
      case [x]: x
      case {~hd, ~tl}: "{hd}{glue}{join(tl, glue)}"
    }
  }

  function string print_escaped_char(escaped_char escaped_char) {
    match (escaped_char) {
      case {~control_escape}: "\\{control_escape}"
      case {~control_letter}: "\\c{control_letter}"
      case {~hex_escape_sequence}: "\\x{hex_escape_sequence}"
      case {~unicode_escape_sequence}: "\\u{unicode_escape_sequence}"
      case {~identity_escape}: "\\{identity_escape}"
      case {~character_class_escape}: "\\{character_class_escape}"
    }
  }

  function SvgElement do_escaped_char(escaped_char escaped_char) {
    c = print_escaped_char(escaped_char)
    {node: {label: c, width:0, height:0, x:0, y:0, color: Color.cadetblue}}
  }
}


