// ignore_for_file: unreachable_from_main

import "dart:io";

import "package:glushkov_construction/automata.dart";
import "package:glushkov_construction/regular_expression.dart";

const Letter a = Letter("a");
const Letter b = Letter("b");
const Letter c = Letter("c");
const Letter d = Letter("b");
const Letter e = Letter("e");
const Letter f = Letter("f");
const Letter g = Letter("g");
const Letter h = Letter("h");
const Letter i = Letter("i");
const Letter j = Letter("j");
const Letter k = Letter("k");
const Letter l = Letter("l");
const Letter m = Letter("m");
const Letter n = Letter("n");
const Letter o = Letter("o");
const Letter p = Letter("p");
const Letter q = Letter("q");
const Letter r = Letter("r");
const Letter s = Letter("s");
const Letter t = Letter("t");
const Letter u = Letter("u");
const Letter v = Letter("v");
const Letter w = Letter("w");
const Letter x = Letter("x");
const Letter y = Letter("y");
const Letter z = Letter("z");
const Letter zero = Letter("0");
const Letter one = Letter("1");

void main(List<String> arguments) {
  // A regular expression that accepts all strings that contain the substring '001'.
  var regex = (zero | one).star & (zero & zero & one) & (zero | one).star;
  var nfa = NFA.fromRegularExpression(regex, renameStates: true);
  var dfa = DFA.fromNFA(nfa, renameStates: true);
  var minimalDfa = dfa.minimized(renameStates: true);

  /// It works! That's awesome.
  File("nfa.dot").writeAsStringSync(nfa.dot());
  File("dfa.dot").writeAsStringSync(dfa.dot());
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot());

  print(dfa.accepts("0101010110010101"));
}

void test1() {
  var states = {
    const State(0, "A"),
    const State(1, "B"),
    const State(2, "C"),
    const State(3, "D"),
    const State(4, "E"),
  };
  var alphabet = {zero, one};
  var transitions = {
    (states[0], zero): states[1],
    (states[0], one): states[2],
    (states[1], zero): states[1],
    (states[1], one): states[3],
    (states[2], zero): states[1],
    (states[2], one): states[2],
    (states[3], zero): states[1],
    (states[3], one): states[4],
    (states[4], zero): states[1],
    (states[4], one): states[2],
  };
  var start = states[0];
  var accepting = {states[4]};
  var dfa = (states, alphabet, transitions, start, accepting).automata.minimized(renameStates: true);

  print(dfa.generateTransitionTable());
  File("automaton.dot").writeAsStringSync(dfa.dot());
}

void test2() {
  var states = {
    "A": const State(0, "A"),
    "B": const State(1, "B"),
    "C": const State(2, "C"),
    "D": const State(3, "D"),
    "E": const State(4, "E"),
    "F": const State(5, "F"),
  };
  var alphabet = {zero, one};
  var transitions = {
    (states["A"]!, zero): states["B"]!,
    (states["A"]!, one): states["C"]!,
    (states["B"]!, zero): states["A"]!,
    (states["B"]!, one): states["D"]!,
    (states["C"]!, zero): states["E"]!,
    (states["C"]!, one): states["F"]!,
    (states["D"]!, zero): states["E"]!,
    (states["D"]!, one): states["F"]!,
    (states["E"]!, zero): states["E"]!,
    (states["E"]!, one): states["F"]!,
    (states["F"]!, zero): states["F"]!,
    (states["F"]!, one): states["F"]!,
  };
  var start = states["A"]!;
  var accepting = {states["D"]!, states["C"]!, states["E"]!};
  var automata = (states.values.toSet(), alphabet, transitions, start, accepting).automata.minimized();

  print(automata.generateTransitionTable());
  File("automaton.dot").writeAsStringSync(automata.dot());
}

extension<T> on Set<T> {
  T operator [](int index) {
    return elementAt(index);
  }
}
