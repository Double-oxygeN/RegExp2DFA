import tables, strformat, ropes

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

proc dotFormat*[Q, A](self: Dfa[Q, A]): string =
  ## Format the automaton in DOT language.
  var r = rope("digraph {\p")

  r.add "  graph [rankdir=LR];\p"

  var allStates: set[Q] = {self.initState}
  for before, afterQ in self.transitionTable.pairs:
    allStates.incl({before.q, afterQ})

  r.add &"  START [shape=plaintext];\p  START -> q_{self.initState};\p"

  for q in allStates:
    r.add &"  q_{q} "
    if q in self.endStates:
      r.add &"[shape=doublecircle, label=\"{q}\"];\p"
    else:
      r.add &"[shape=circle, label=\"{q}\"];\p"

  for before, after in self.transitionTable:
    r.add &"  q_{before.q} -> q_{after} [label=\"{before.a}\"];\p"

  r.add "}"

  result = $r

proc `$`*[Q, A](self: Dfa[Q, A]): string = self.dotFormat
