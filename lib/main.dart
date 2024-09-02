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
  // var regex = (zero | one).star & (zero & zero & one) & (zero | one).star;
  // var nfa = NonDeterministicFiniteAutomata.fromRegularExpression(regex, renameStates: true);
  // var dfa = DeterministicFiniteAutomata.fromNonDeterministicAutomaton(nfa);

  // print(nfa.generateTransitionTable());
  // print("${"-" * 20}${"=" * 4}[]${"=" * 4}${"-" * 20}");
  // print(dfa.generateTransitionTable());
  // print(nfa.accepts("00010010110010101"));
  // print(dfa.accepts("00010010110010101"));

  var states = <State>{
    const State(0, "q0"),
    const State(1, "q1"),
    const State(2, "q2"),
    const State(3, "q3"),
  };
  var alphabet = <Letter>{zero, one};
  var transitions = {
    (states[0], zero): {states[0], states[1]},
    (states[0], one): {states[0]},
    (states[1], zero): {states[2]},
    (states[2], one): {states[3]},
    (states[3], zero): {states[3]},
    (states[3], one): {states[3]},
  };
  var start = states[0];
  var accepting = {states[3]};
  NonDeterministicFiniteAutomata automata = (states, alphabet, transitions, start, accepting).automata;
  DeterministicFiniteAutomata automata2 = DeterministicFiniteAutomata.fromNonDeterministicAutomaton(automata);

  print(automata.generateTransitionTable());
  print("${"-" * 20}${"=" * 4}[]${"=" * 4}${"-" * 20}");
  print(automata2.generateTransitionTable());
  File("automaton.dot").writeAsStringSync(automata2.dot());
}

extension<T> on Set<T> {
  T operator [](int index) {
    return elementAt(index);
  }
}
