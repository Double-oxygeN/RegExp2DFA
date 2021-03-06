import tables, strformat, ropes
from strutils import toHex

type
  Dfa*[Q; A] = ref object
    alphabets: set[A]
    transitionTable: Table[tuple[q: Q, a: A], Q]
    initState: Q
    endStates: set[Q]

proc newDfa*[Q, A](alphabets: set[A]; transitions: openarray[tuple[before: tuple[q: Q, a: A], after: Q]]; initState: Q; endStates: set[Q]): Dfa[Q, A] =
  ## Create new DFA.
  result = Dfa[Q, A](alphabets: alphabets, transitionTable: transitions.toTable(), initState: initState, endStates: endStates)

proc testInput*[Q, A](self: Dfa[Q, A]; input: openarray[A]): bool =
  ## Check if the automaton passes the input.
  var state = self.initState

  for action in input:
    if not self.transitionTable.hasKey((state, action)):
      return false

    state = self.transitionTable[(state, action)]

  result = state in self.endStates

proc allStates*[Q, A](self: Dfa[Q, A]): set[Q] =
  ## Gather all states used in the automaton.
  result = {self.initState}
  for before, afterQ in self.transitionTable.pairs:
    result.incl({before.q, afterQ})

proc escapeUnprintables(str: string): string =
  const
    printables = {' '..'~'}
    mustEscape = {'"', '\\'}
  var r = rope("")

  for c in str:
    r.add(if c in mustEscape: "\\" & $c elif c in printables: $c else: "\\\\x" & toHex(c.int, 2))

  result = $r

proc dotFormat*[Q, A](self: Dfa[Q, A]): string =
  ## Format the automaton in DOT language.
  var r = rope("digraph {\p")

  r.add "  graph [rankdir=LR];\p\p"

  for q in self.allStates:
    r.add &"  q_{q} "
    if q in self.endStates:
      r.add &"[shape=doublecircle, label=\"{q}\"];\p"
    else:
      r.add &"[shape=circle, label=\"{q}\"];\p"

  r.add &"  START [shape=plaintext];\p\p  START -> q_{self.initState};\p"

  for before, after in self.transitionTable:
    let label = escapeUnprintables($before.a)
    r.add &"  q_{before.q} -> q_{after} [label=\"{label}\"];\p"

  r.add "}"

  result = $r

proc `$`*[Q, A](self: Dfa[Q, A]): string = self.dotFormat
