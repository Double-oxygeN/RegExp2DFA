import unittest
import regexp, dfas

suite "DFA":
  setup:
    let
      dfa0 = newDfa(
        {'a', 'b'},
        {
          (0'u8, 'a'): 1'u8,
          (0'u8, 'b'): 2'u8,
          (1'u8, 'a'): 0'u8,
          (1'u8, 'b'): 3'u8,
          (2'u8, 'a'): 4'u8,
          (2'u8, 'b'): 0'u8,
          (3'u8, 'b'): 5'u8,
          (4'u8, 'a'): 6'u8,
          (5'u8, 'b'): 3'u8,
          (6'u8, 'a'): 4'u8
        },
        0'u8,
        {3'u8, 4'u8})

  test "testInput":
    check:
      dfa0.testInput("ab")
      dfa0.testInput("ba")
      dfa0.testInput("aaab")
      dfa0.testInput("aaaaabbbbbbb")
      dfa0.testInput("baaa")
      dfa0.testInput("bbbbbaaaaa")

      not dfa0.testInput("")
      not dfa0.testInput("a")
      not dfa0.testInput("aa")
      not dfa0.testInput("b")
      not dfa0.testInput("bb")
      not dfa0.testInput("aaaba")
      not dfa0.testInput("bbbab")
      not dfa0.testInput("bbbaaaa")

  test "allStates":
    check:
      dfa0.allStates() == {0'u8..6'u8}

suite "RegExp":
  test "single character":
    let
      rSingle = reg"a"
      dfaSingle = rSingle.toDfa()
    
    check:
      dfaSingle.testInput("a")

      not dfaSingle.testInput("")
      not dfaSingle.testInput("A")
      not dfaSingle.testInput("aa")

  test "concatenation":
    let
      rConcat = reg"abcd1234"
      dfaConcat = rConcat.toDfa()

    check:
      dfaConcat.testInput("abcd1234")

      not dfaConcat.testInput("")
      not dfaConcat.testInput("abcd")
      not dfaConcat.testInput("abcd1234a")
      not dfaConcat.testInput("aabcd1234")

  test "alternation":
    let
      rAlt = reg"abcd|1234|qwerty"
      dfaAlt = rAlt.toDfa()

    check:
      dfaAlt.testInput("abcd")
      dfaAlt.testInput("1234")
      dfaAlt.testInput("qwerty")

      not dfaAlt.testInput("")
      not dfaAlt.testInput("abcd1234")
      not dfaAlt.testInput("abcd1234qwerty")
      not dfaAlt.testInput("abcd|1234|qwerty")
      not dfaAlt.testInput("qwer")

  test "complicated alternation":
    let
      rCompAlt = reg"ababab|a(ba)+|(abab)*"
      dfaCompAlt = rCompAlt.toDfa()

    check:
      dfaCompAlt.testInput("")
      dfaCompAlt.testInput("ababab")
      dfaCompAlt.testInput("aba")
      dfaCompAlt.testInput("abababa")
      dfaCompAlt.testInput("abab")
      dfaCompAlt.testInput("abababababababab")

      not dfaCompAlt.testInput("a")
      not dfaCompAlt.testInput("ab")
      not dfaCompAlt.testInput("ababababab")

  test "Kleene star":
    let
      rStar = reg"a*b*|c*"
      dfaStar = rStar.toDfa()

    check:
      dfaStar.testInput("")
      dfaStar.testInput("a")
      dfaStar.testInput("aaaaa")
      dfaStar.testInput("b")
      dfaStar.testInput("bbb")
      dfaStar.testInput("ab")
      dfaStar.testInput("aabbbb")
      dfaStar.testInput("c")
      dfaStar.testInput("cc")

      not dfaStar.testInput("ba")
      not dfaStar.testInput("aaacc")

  test "grouping":
    let
      rGroup = reg"((ab|c)*d(e|ef|f))*(gh|ij)"
      dfaGroup = rGroup.toDfa()

    check:
      dfaGroup.testInput("gh")
      dfaGroup.testInput("ij")
      dfaGroup.testInput("abdeij")
      dfaGroup.testInput("cabdefccdeabababcdfgh")
      dfaGroup.testInput("defdefgh")
      dfaGroup.testInput("abcdefgh")

      not dfaGroup.testInput("")
      not dfaGroup.testInput("ghij")

  test "plus":
    let
      rPlus = reg"(a+(bc)*)+"
      dfaPlus = rPlus.toDfa()

    check:
      dfaPlus.testInput("a")
      dfaPlus.testInput("aaa")
      dfaPlus.testInput("aabc")
      dfaPlus.testInput("aabcbcbc")
      dfaPlus.testInput("aabcabcaaabcbc")

      not dfaPlus.testInput("")
      not dfaPlus.testInput("bc")

  test "option":
    let
      rOption = reg"colou?r( A| B| C|s)?"
      dfaOption = rOption.toDfa()

    check:
      dfaOption.testInput("color")
      dfaOption.testInput("color A")
      dfaOption.testInput("color B")
      dfaOption.testInput("color C")
      dfaOption.testInput("colors")
      dfaOption.testInput("colour")
      dfaOption.testInput("colour A")
      dfaOption.testInput("colour B")
      dfaOption.testInput("colour C")
      dfaOption.testInput("colours")

      not dfaOption.testInput("")
      not dfaOption.testInput("r")
      not dfaOption.testInput("color ")
      not dfaOption.testInput("colours A")

  test "simple charset":
    let
      rSimpleCS = reg"[\+-]?([012]|[12][012]+)"
      dfaSimpleCS = rSimpleCS.toDfa()

    check:
      dfaSimpleCS.testInput("0")
      dfaSimpleCS.testInput("1")
      dfaSimpleCS.testInput("2")
      dfaSimpleCS.testInput("10")
      dfaSimpleCS.testInput("11")
      dfaSimpleCS.testInput("12")
      dfaSimpleCS.testInput("20")
      dfaSimpleCS.testInput("21")
      dfaSimpleCS.testInput("22")
      dfaSimpleCS.testInput("100")
      dfaSimpleCS.testInput("201")
      dfaSimpleCS.testInput("12021100112")
      dfaSimpleCS.testInput("-1")
      dfaSimpleCS.testInput("-1020")
      dfaSimpleCS.testInput("+0")
      dfaSimpleCS.testInput("+2101")

      not dfaSimpleCS.testInput("")
      not dfaSimpleCS.testInput("01")
      not dfaSimpleCS.testInput("00")
      not dfaSimpleCS.testInput("+-0")

  test "any character":
    let
      rAnyChar = reg"a...e"
      dfaAnyChar = rAnyChar.toDfa()

    check:
      dfaAnyChar.testInput("azure")
      dfaAnyChar.testInput("angle")
      dfaAnyChar.testInput("above")
      dfaAnyChar.testInput("apple")
      dfaAnyChar.testInput("a pie")
      dfaAnyChar.testInput("a012e")
      dfaAnyChar.testInput("a+$\"e")
      dfaAnyChar.testInput("a\t\a\ne")
      dfaAnyChar.testInput("a\\\r\x01e")

  test "escape characters":
    let
      rEscape = reg"[\|\*\+\?\(\)\[\]\.\\\a\b\t\n\v\f\e]+"
      dfaEscape = rEscape.toDfa()

    check:
      dfaEscape.testInput("(+|*)")
      dfaEscape.testInput("[?]")
      dfaEscape.testInput("\\.")
      dfaEscape.testInput("\a\b\e\f\n\t\v")

  test "range charset":
    let
      rRangeCS = reg"[A-Z][A-Za-z_]*-[1-9][0-9-]*"
      dfaRangeCS = rRangeCS.toDfa()

    check:
      dfaRangeCS.testInput("A-1")
      dfaRangeCS.testInput("Z_-9")
      dfaRangeCS.testInput("STU-3724")
      dfaRangeCS.testInput("World-907")
      dfaRangeCS.testInput("Freiheit-6-321")
      dfaRangeCS.testInput("Double_oxygeN-2019-")

      not dfaRangeCS.testInput("a-1")
      not dfaRangeCS.testInput("4-4")
      not dfaRangeCS.testInput("Opqr-0")
      not dfaRangeCS.testInput("XYZ-1?")

  test "negative charset":
    let
      rNegCS = reg"[^0-9A-Za-z_-]+"
      dfaNegCS = rNegCS.toDfa()

    check:
      dfaNegCS.testInput("~!\"+?\\/]@#%")
      dfaNegCS.testInput("\t= (*:;.,')\r\n")

      not dfaNegCS.testInput("")
      not dfaNegCS.testInput("0")
      not dfaNegCS.testInput("$_$")
      not dfaNegCS.testInput("+-")
      not dfaNegCS.testInput("@R")
      not dfaNegCS.testInput("{go}")
