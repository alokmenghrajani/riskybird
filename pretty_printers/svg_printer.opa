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
        <svg:svg xmlns:svg="http://www.w3.org/2000/svg" version="1.1" style="position: absolute; border: 1px solid red; height: {d.height}px; width: {d.width}px">
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
          // to compute the layout of a node, we simply
          // set the width and height to 100.
          {node: {node with width: 100, height: 100}}
        case {~choice}:
          // to compute the layout of a sequence of nodes:
          // 1. compute the layout of every inner element
          // 2. set this element's width to max(all inner elements)
          // 3. set this element's height to sum(all inner heights)
          items = List.map(computeDimensions, choice.items)
          SvgMaxSum max_sum = computeMaxSum(items)
          {choice: {choice with width:max_sum.max_width, height: max_sum.sum_height, ~items}}
        case {~seq}:
          // to compute the layout of a sequence of nodes:
          // 1. compute the layout of every inner element
          // 2. set this element's width to sum(all inner elements)
          // 3. set this element's height to max(all inner heights)
          items = List.map(computeDimensions, seq.items)
          SvgMaxSum max_sum = computeMaxSum(items)
          {seq: {seq with width: max_sum.sum_width, height: max_sum.max_height, ~items}}
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
          int delta_width = Float.to_int(Float.of_int(width - seq.width) / Float.of_int(List.length(seq.items)))
          items = List.map(function(e){
            d = getDimensions(e)
            computeResize(e, d.width + delta_width, height)},
            seq.items
          )
          {seq: {~width, ~height, ~items}}
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
            {~x, ~y, l:[]}
          )
          {seq: {seq with items:t.l}}
      }
    }

    node = computeDimensions(node)
    d = getDimensions(node)
    node = computeResize(node, d.width, d.height)
    computePositions(node, 0, 0)
  }

  function xhtml toXml(SvgElement nodes) {
    function xhtml toXmlNode(SvgNode node) {
      x = node.x + node.width / 2;
      y = node.y + node.height / 2;
      <>
        <svg:circle xmlns:svg="http://www.w3.org/2000/svg" cx={x} cy={y} r="10" style="fill:none; stroke:rgb(255,0,0);stroke-width:2"/>
        <svg:text x={x-5} y={y+5}>{node.label}</svg:text>
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
      case {~seq}: toXmlNodes(seq.items)
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
        x1 = a1.x + a1.width / 2
        y1 = a1.y + a1.height / 2

        x2 = a2.x + a2.width / 2
        y2 = a2.y + a2.height / 2

        d1 = "M{x1-15},{y1} L{x1-22},{y1-4} L{x1-20},{y1} L{x1-22},{y1+4} L{x1-15},{y1}"
        d2 = "M{x1-14},{y1} C{x1-100},{y1} {x2+100},{y2} {x2+14},{y2}"
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
    int y }

and SvgChoice =
  { int width,
    int height,
    list(SvgElement) items }

and SvgSeq =
  { int width,
    int height,
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
    {seq: {width: 0, height: 0, ~items}}
  }

  function SvgElement term(term b) {
    match (b) {
      case {assertion: {anchor_start}}: {node: {label: "^", width: 0, height: 0, x: 0, y: 0}}
      case {assertion: {anchor_end}}: {node: {label: "$", width: 0, height: 0, x: 0, y: 0}}
      case {~atom, ...}: do_atom(atom)
      case _: {node: {label: "?1", width: 0, height: 0, x: 0, y: 0}}
    }
  }

  function SvgElement do_atom(atom atom) {
    match (atom) {
      case {dot}: {node: {label: ".", width: 0, height: 0, x:0, y: 0}}
      case {~char}: {node: {label: char, width: 0, height: 0, x:0, y: 0}}
      case {~group_ref}: {node: {label: "\\{group_ref}", width: 0, height: 0, x:0, y: 0}}
      case {~group, ...}: regexp(group)
      case {~ncgroup, ...}: regexp(ncgroup)
      case {char_class:_, ...}: {node: {label: "[...]", width: 0, height: 0, x:0, y: 0}}
      case _: {node: {label: "?2", width: 0, height: 0, x: 0, y: 0}}
    }

  }
}


/*
    {seq: {width: 0, height: 0, items: [
      {node: {label: "A", width: 0, height: 0, x: 0, y: 0}},
      {choice: {width: 0, height: 0, items: [
        {seq: {width: 0, height: 0, items: [
          {node: {label: "B", width: 0, height: 0, x: 0, y: 0}},
          {node: {label: "C", width: 0, height: 0, x: 0, y: 0}},
          {node: {label: "D", width: 0, height: 0, x: 0, y: 0}},
        ]}},
        {node: {label: "E", width: 0, height: 0, x: 0, y: 0}},
        {seq: {width: 0, height: 0, items: [
          {node: {label: "F", width: 0, height: 0, x: 0, y: 0}},
          {choice: {width: 0, height: 0, items: [
            {node: {label: "G", width: 0, height: 0, x: 0, y: 0}},
            {node: {label: "H", width: 0, height: 0, x: 0, y: 0}},
          ]}}
        ]}}
      ]}},
      {node: {label: "Z", width: 0, height: 0, x: 0, y: 0}},
    ]}}
*/

