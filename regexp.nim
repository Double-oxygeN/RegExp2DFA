import sequtils, strformat, deques, tables
from strutils import indent, parseHexStr, HexDigits
import dfas

type
  Position = int16
  RegExpKind = enum
    regEpsilon,
    regChar,
    regConcat,
    regAlt,
    regStar,
    regPlus,
    regOption,
    regAnyChar,
    regCharSet

  RegExp[C] = ref object
    case kind: RegExpKind
    of regChar, regAnyChar, regCharSet:
      c: C
      cs: set[C]
      pos: Position
      followPos: set[Position]

    of regConcat, regAlt:
      r1, r2: RegExp[C]

    of regStar, regPlus, regOption:
      r: RegExp[C]

    else:
      nil

    nullable: bool
    firstPos, lastPos: set[Position]

    alphabets: set[C]

  RegExpTokenKind = enum
    rtokAlt = "|",
    rtokStar = "*",
    rtokPlus = "+",
    rtokOption = "?",
    rtokLeftParen = "(",
    rtokRightParen = ")",
    rtokLeftSquareBracket = "[",
    rtokRightSquareBracket = "]",
    rtokHyphen = "-",
    rtokHat = "^",
    rtokDot = ".",
    rtokChar = "char"

  RegExpToken = ref object
    case kind: RegExpTokenKind
    of rtokChar:
      c: char

    else:
      nil

  RegExpParseException* = object of Exception

proc regc*(c: char): RegExp[char] =
  RegExp[char](kind: regChar, c: c, alphabets: {c})

proc `&@`*[C](r1, r2: RegExp[C]): RegExp[C] =
  ## Concat two RegExp
  RegExp[char](kind: regConcat, r1: r1, r2: r2, alphabets: r1.alphabets + r2.alphabets)

proc `|@`*[C](r1, r2: RegExp[C]): RegExp[C] =
  ## Alternation of two RegExp
  RegExp[char](kind: regAlt, r1: r1, r2: r2, alphabets: r1.alphabets + r2.alphabets)

proc regs*(str: string): RegExp[char] =
  if str.len == 0: RegExp[char](kind: regEpsilon)
  elif str.len == 1: regc(str[0])
  else: str.map(regc).foldl(a &@ b)

proc star*[C](r: RegExp[C]): RegExp[C] =
  ## Kleene closure
  RegExp[C](kind: regStar, r: r, alphabets: r.alphabets)

proc plus*[C](r: RegExp[C]): RegExp[C] =
  RegExp[C](kind: regPlus, r: r, alphabets: r.alphabets)

proc option*[C](r: RegExp[C]): RegExp[C] =
  RegExp[C](kind: regOption, r: r, alphabets: r.alphabets)

proc anyChar*(C: typedesc): RegExp[C] =
  RegExp[C](kind: regAnyChar, alphabets: {succ(C.low)..C.high})

proc charSet*[C](cs: set[C]): RegExp[C] =
  RegExp[C](kind: regCharSet, cs: cs, alphabets: cs)

proc pretty*[C](r: RegExp[C]; indentCount: int = 0): string =
  ## Convert to string
  case r.kind
  of regEpsilon:
    result = fmt"ε ({r.nullable};{r.firstPos};{r.lastPos};-)".indent(indentCount)

  of regChar:
    result = fmt"Char[{r.pos}] = '{r.c}' ({r.nullable};{r.firstPos};{r.lastPos};{r.followPos})".indent(indentCount)

  of regConcat:
    result = fmt"Concat ({r.nullable};{r.firstPos};{r.lastPos};-)".indent(indentCount)
    result &= "\p" & r.r1.pretty(indentCount + 2)
    result &= "\p" & r.r2.pretty(indentCount + 2)

  of regAlt:
    result = fmt"Alt ({r.nullable};{r.firstPos};{r.lastPos};-)".indent(indentCount)
    result &= "\p" & r.r1.pretty(indentCount + 2)
    result &= "\p" & r.r2.pretty(indentCount + 2)

  of regStar:
    result = fmt"Star ({r.nullable};{r.firstPos};{r.lastPos};-)".indent(indentCount)
    result &= "\p" & r.r.pretty(indentCount + 2)

  of regPlus:
    result = fmt"Plus ({r.nullable};{r.firstPos};{r.lastPos};-)".indent(indentCount)
    result &= "\p" & r.r.pretty(indentCount + 2)

  of regOption:
    result = fmt"Option ({r.nullable};{r.firstPos};{r.lastPos};-)".indent(indentCount)
    result &= "\p" & r.r.pretty(indentCount + 2)

  of regAnyChar:
    result = fmt"AnyChar[{r.pos}] ({r.nullable};{r.firstPos};{r.lastPos};{r.followPos})".indent(indentCount)

  of regCharSet:
    result = fmt"CharSet[{r.pos}] = {r.cs} ({r.nullable};{r.firstPos};{r.lastPos};{r.followPos})".indent(indentCount)

proc `$`*[C](self: RegExp[C]): string = self.pretty(0)

proc accept[C](self: RegExp[C]; c: C): bool =
  case self.kind
  of regChar: self.c == c
  of regAnyChar: true
  of regCharSet: c in self.cs
  else: false

proc calcPositions*[C](self: RegExp[C]; pos: seq[RegExp[C]] = @[]): seq[RegExp[C]] =
  case self.kind
  of regEpsilon:
    result = pos
    self.nullable = true
    self.firstPos = {}
    self.lastPos = {}

  of regChar, regAnyChar, regCharSet:
    self.pos = Position(pos.len)
    self.nullable = false
    self.firstPos = {self.pos}
    self.lastPos = {self.pos}

    result = pos & self

  of regConcat:
    let pos1 = self.r1.calcPositions(pos)
    result = self.r2.calcPositions(pos1)
    self.nullable = self.r1.nullable and self.r2.nullable
    self.firstPos = if self.r1.nullable: self.r1.firstPos + self.r2.firstPos else: self.r1.firstPos
    self.lastPos = if self.r2.nullable: self.r1.lastPos + self.r2.lastPos else: self.r2.lastPos

    for i in self.r1.lastPos:
      result[i].followPos = result[i].followPos + self.r2.firstPos

  of regAlt:
    let pos1 = self.r1.calcPositions(pos)
    result = self.r2.calcPositions(pos1)
    self.nullable = self.r1.nullable or self.r2.nullable
    self.firstPos = self.r1.firstPos + self.r2.firstPos
    self.lastPos = self.r1.lastPos + self.r2.lastPos

  of regStar:
    result = self.r.calcPositions(pos)
    self.nullable = true
    self.firstPos = self.r.firstPos
    self.lastPos = self.r.lastPos

    for i in self.r.lastPos:
      result[i].followPos = result[i].followPos + self.r.firstPos

  of regPlus:
    result = self.r.calcPositions(pos)
    self.nullable = self.r.nullable
    self.firstPos = self.r.firstPos
    self.lastPos = self.r.lastPos

    for i in self.r.lastPos:
      result[i].followPos = result[i].followPos + self.r.firstPos

  of regOption:
    result = self.r.calcPositions(pos)
    self.nullable = true
    self.firstPos = self.r.firstPos
    self.lastPos = self.r.lastPos

proc lexRegExp(input: string): Deque[RegExpToken] =
  type
    StateLexRegExp = distinct range[0..1]

  var
    state = StateLexRegExp(0)
    reading = input.low

  result = initDeque[RegExpToken]()

  while true:

    case state
    of StateLexRegExp(0):
      if input.high < reading: break
      case input[reading]
      of '|': result.addLast(RegExpToken(kind: rtokAlt))
      of '*': result.addLast(RegExpToken(kind: rtokStar))
      of '+': result.addLast(RegExpToken(kind: rtokPlus))
      of '?': result.addLast(RegExpToken(kind: rtokOption))
      of '(': result.addLast(RegExpToken(kind: rtokLeftParen))
      of ')': result.addLast(RegExpToken(kind: rtokRightParen))
      of '[': result.addLast(RegExpToken(kind: rtokLeftSquareBracket))
      of ']': result.addLast(RegExpToken(kind: rtokRightSquareBracket))
      of '-': result.addLast(RegExpToken(kind: rtokHyphen))
      of '^': result.addLast(RegExpToken(kind: rtokHat))
      of '.': result.addLast(RegExpToken(kind: rtokDot))
      of '\\': state = StateLexRegExp(1)
      else: result.addLast(RegExpToken(kind: rtokChar, c: input[reading]))

      inc reading

    of StateLexRegExp(1):
      if input.high < reading:
        result.addLast(RegExpToken(kind: rtokChar, c: '\\'))
        break
      case input[reading]
      of '|', '*', '+', '?', '(', ')', '[', ']', '.', '\\':
        result.addLast(RegExpToken(kind: rtokChar, c: input[reading]))
      of '0': result.addLast(RegExpToken(kind: rtokChar, c: '\0'))
      of 'a': result.addLast(RegExpToken(kind: rtokChar, c: '\a'))
      of 'b': result.addLast(RegExpToken(kind: rtokChar, c: '\b'))
      of 't': result.addLast(RegExpToken(kind: rtokChar, c: '\t'))
      of 'n': result.addLast(RegExpToken(kind: rtokChar, c: '\n'))
      of 'v': result.addLast(RegExpToken(kind: rtokChar, c: '\v'))
      of 'f': result.addLast(RegExpToken(kind: rtokChar, c: '\f'))
      of 'e': result.addLast(RegExpToken(kind: rtokChar, c: '\e'))
      of 'x':
        if reading + 2 > input.high or input[reading+1] notin HexDigits or input[reading+2] notin HexDigits:
          result.addLast(RegExpToken(kind: rtokChar, c: '\\'))
          result.addLast(RegExpToken(kind: rtokChar, c: 'x'))
        else:
          let hexChar = input[reading+1..reading+2].parseHexStr()[0]
          result.addLast(RegExpToken(kind: rtokChar, c: hexChar))
          inc reading, 2
      else:
        result.addLast(RegExpToken(kind: rtokChar, c: '\\'))
        result.addLast(RegExpToken(kind: rtokChar, c: input[reading]))

      inc reading
      state = StateLexRegExp(0)

proc parseCharSetContent(tokens: var Deque[RegExpToken]; cs: set[char] = {}): set[char] =
  if tokens.len == 0:
    raise RegExpParseException.newException("Invalid CharSetContent: unexpected end-of-text")

  case tokens.peekFirst().kind
  of rtokChar:
    let c1 = tokens.popFirst().c

    if tokens.len == 0:
      raise RegExpParseException.newException("Invalid CharSetContent: unexpected end-of-text")

    case tokens.peekFirst().kind
    of rtokHyphen:
      discard tokens.popFirst()

      if tokens.len == 0:
        raise RegExpParseException.newException("Invalid CharSetContent: unexpected end-of-text")

      case tokens.peekFirst().kind
      of rtokChar:
        let c2 = tokens.popFirst().c
        
        result = parseCharSetContent(tokens, cs + {c1..c2})

      of rtokHyphen:
        discard tokens.popFirst()

        result = parseCharSetContent(tokens, cs + {c1..'-'})

      of rtokRightSquareBracket:
        result = cs + {c1, '-'}

      else:
        raise RegExpParseException.newException("Invalid CharSetContent: found unexpected token.")

    of rtokChar, rtokRightSquareBracket:
      result = parseCharSetContent(tokens, cs + {c1})

    else:
      raise RegExpParseException.newException("Invalid CharSetContent: found unexpected token.")

  of rtokHyphen:
    discard tokens.popFirst()

    result = parseCharSetContent(tokens, cs + {'-'})

  of rtokRightSquareBracket:
    result = cs

  else:
    raise RegExpParseException.newException("Invalid CharSetContent: found unexpected token.")

proc parseCharSetExp(tokens: var Deque[RegExpToken]): RegExp[char] =
  if tokens.len < 2:
    raise RegExpParseException.newException("CharSetExp should have at least two tokens.")
  
  if tokens.popFirst().kind != rtokLeftSquareBracket:
    raise RegExpParseException.newException("Invalid CharSetExp: expect '['.")

  case tokens.peekFirst().kind
  of rtokChar, rtokHyphen, rtokRightSquareBracket:
    let cs = parseCharSetContent(tokens)

    result = charSet(cs)

    if tokens.len == 0:
      raise RegExpParseException.newException("Invalid CharSetExp: unexpected end-of-text.")
    if tokens.popFirst().kind != rtokRightSquareBracket:
      raise RegExpParseException.newException("Invalid CharSetExp: expected ']'.")

  of rtokHat:
    discard tokens.popFirst()
    const charUniverse = {succ(char.low)..char.high}
    let cs = parseCharSetContent(tokens)

    result = charSet(charUniverse - cs)

    if tokens.len == 0:
      raise RegExpParseException.newException("Invalid CharSetExp: unexpected end-of-text.")
    if tokens.popFirst().kind != rtokRightSquareBracket:
      raise RegExpParseException.newException("Invalid CharSetExp: expected ']'.")

  else:
    raise RegExpParseException.newException("Invalid CharSetExp: expect character.")

proc parseAltExp(tokens: var Deque[RegExpToken]): RegExp[char]

proc parseAtomExp(tokens: var Deque[RegExpToken]): RegExp[char] =
  if tokens.len == 0:
    raise RegExpParseException.newException("AtomExp should have at least one token.")

  case tokens.peekFirst().kind
  of rtokChar:
    let firstToken = tokens.popFirst()
    result = regc(firstToken.c)

  of rtokHyphen:
    discard tokens.popFirst()
    result = regc('-')

  of rtokHat:
    discard tokens.popFirst()
    result = regc('^')

  of rtokDot:
    discard tokens.popFirst()
    result = anyChar(char)

  of rtokLeftParen:
    discard tokens.popFirst()
    result = parseAltExp(tokens)
    
    if tokens.len == 0:
      raise RegExpParseException.newException("Invalid AtomExp: unexpected end-of-text.")
    if tokens.popFirst().kind != rtokRightParen:
      raise RegExpParseException.newException("Invalid AtomExp: expect ')'.")

  of rtokLeftSquareBracket:
    result = parseCharSetExp(tokens)

  else:
    raise RegExpParseException.newException("Invalid AtomExp: expect non-meta character, escaped character or '('.")

proc parseUnaryExp(tokens: var Deque[RegExpToken]): RegExp[char] =
  if tokens.len == 0:
    raise RegExpParseException.newException("UnaryExp should have at lease one token.")

  let atomExp = parseAtomExp(tokens)

  if tokens.len == 0:
    return atomExp

  case tokens.peekFirst().kind
  of rtokStar:
    tokens.popFirst()
    result = star(atomExp)

  of rtokPlus:
    tokens.popFirst()
    result = plus(atomExp)

  of rtokOption:
    tokens.popFirst()
    result = option(atomExp)

  else:
    result = atomExp

proc parseConcatExp0(tokens: var Deque[RegExpToken]; prevExp: RegExp[char]): RegExp[char] =
  if tokens.len == 0:
    return prevExp

  case tokens.peekFirst().kind
  of rtokChar, rtokHyphen, rtokHat, rtokDot, rtokLeftParen, rtokLeftSquareBracket:
    let unaryExp = parseUnaryExp(tokens)
    result = prevExp &@ parseConcatExp0(tokens, unaryExp)

  else:
    result = prevExp

proc parseConcatExp(tokens: var Deque[RegExpToken]): RegExp[char] =
  if tokens.len == 0:
    raise RegExpParseException.newException("ConcatExp should have at lease one token.")

  case tokens.peekFirst().kind
  of rtokChar, rtokHyphen, rtokHat, rtokDot, rtokLeftParen, rtokLeftSquareBracket:
    let unaryExp = parseUnaryExp(tokens)
    result = parseConcatExp0(tokens, unaryExp)

  else:
    raise RegExpParseException.newException("Invalid ConcatExp: expect non-meta character, escaped character or '('.")

proc parseAltExp0(tokens: var Deque[RegExpToken]; prevExp: RegExp[char]): RegExp[char] =
  if tokens.len == 0:
    return prevExp

  case tokens.peekFirst().kind
  of rtokAlt:
    tokens.popFirst()
    let concatExp = parseConcatExp(tokens)
    result = prevExp |@ parseAltExp0(tokens, concatExp)

  else:
    result = prevExp

proc parseAltExp(tokens: var Deque[RegExpToken]): RegExp[char] =
  if tokens.len == 0:
    raise RegExpParseException.newException("AltExp should have at least one token.")

  case tokens.peekFirst().kind
  of rtokChar, rtokHyphen, rtokHat, rtokDot, rtokLeftParen, rtokLeftSquareBracket:
    let concatExp = parseConcatExp(tokens)
    result = parseAltExp0(tokens, concatExp)

  else:
    raise RegExpParseException.newException("Invalid AltExp: expect non-meta character, escaped character or '('.")

proc parseRegExp(tokens: var Deque[RegExpToken]): RegExp[char] =
  if tokens.len == 0:
    return RegExp[char](kind: regEpsilon)

  result = parseAltExp(tokens)
  if tokens.len > 0:
    raise RegExpParseException.newException("Invalid RegExp: expect end-of-text")

proc reg*(input: string): RegExp[char] =
  var tokens = input.lexRegExp()
  tokens.parseRegExp()

proc toDfa*[C](self: RegExp[C]): Dfa[uint16, C] =
  var extendedExp = self &@ regc('\0')
  let pos = extendedExp.calcPositions()
  var
    stateTranslater = initTable[set[Position], uint16]()
    unmarkedStates = initDeque[set[Position]]()
    transitions: seq[tuple[before: tuple[q: uint16, a: C], after: uint16]] = @[]
    endStateIds: set[uint16] = {}

  stateTranslater[extendedExp.firstPos] = 0'u16
  unmarkedStates.addLast(extendedExp.firstPos)

  while unmarkedStates.len > 0:
    let
      state = unmarkedStates.popFirst()
      stateId = stateTranslater[state]

    for a in self.alphabets:
      let
        nextStateSeq = toSeq(state.items)
          .map(proc (p: Position): RegExp[C] = pos[p])
          .filter(proc (p: RegExp[C]): bool = p.accept(a))
          .map(proc (p: RegExp[C]): set[Position] = p.followPos)

      if nextStateSeq.len > 0:
        let
          nextState = nextStateSeq.foldl(a + b)

        if not stateTranslater.hasKey(nextState):
          unmarkedStates.addLast(nextState)

        let
          nextStateId = stateTranslater.mgetOrPut(nextState, stateTranslater.len.uint16)
        transitions.add ((stateId, a), nextStateId)

  for state, stateId in stateTranslater.pairs:
    if Position(pos.high) in state: endStateIds.incl(stateId)

  result = newDfa(self.alphabets, transitions, 0'u16, endStateIds)

when isMainModule:
  import os

  if paramCount() == 1:
    echo reg(paramStr(1)).toDfa()

  else:
    for r in [reg"", reg"a", reg"abc123", reg"abc|123", reg"(a*b+c?(d|ef)*)*", reg"(a*|b*|c*)+", reg"(a|b)*abb"]:
      echo r.toDfa()
