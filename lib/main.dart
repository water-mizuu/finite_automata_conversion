// cspell: disable
// ignore_for_file: unreachable_from_main

import "dart:io";

import "package:finite_automata_conversion/automata.dart";
import "package:finite_automata_conversion/regular_expression.dart";

const Letter a = Letter("a");
const Letter b = Letter("b");
const Letter c = Letter("c");
const Letter d = Letter("d");
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
const Letter two = Letter("2");
const Letter three = Letter("3");
const Letter four = Letter("4");
const Letter five = Letter("5");
const Letter six = Letter("6");
const Letter seven = Letter("7");
const Letter eight = Letter("8");
const Letter nine = Letter("9");

void main(List<String> arguments) {
  test12();
}

void test0() {
  // (ab)*((bc),(acb))+
  RegularExpression regex = (a & b).star & ((b & c) | (a & c & b)).plus;
  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = nfaE.removeEpsilonTransitions();
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  File("nfa_e.dot").writeAsStringSync(nfaE.dot());
  File("nfa.dot").writeAsStringSync(nfa.dot());
  File("dfa.dot").writeAsStringSync(dfa.dot());
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot());

  print(dfa.accepts("ababababababbc"));
}

void test1() {
  Set<State> states = <State>{
    const State(0, "A"),
    const State(1, "B"),
    const State(2, "C"),
    const State(3, "D"),
    const State(4, "E"),
  };
  Set<Letter> alphabet = <Letter>{zero, one};
  Map<(State, Letter), State> transitions = <(State, Letter), State>{
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
  State start = states[0];
  Set<State> accepting = <State>{states[4]};
  DFA dfa = (states, alphabet, transitions, start, accepting).automata.minimized();

  print(dfa.generateTransitionTable());
  File("automaton.dot").writeAsStringSync(dfa.dot());
}

void test2() {
  Map<String, State> states = <String, State>{
    "A": const State(0, "A"),
    "B": const State(1, "B"),
    "C": const State(2, "C"),
    "D": const State(3, "D"),
    "E": const State(4, "E"),
    "F": const State(5, "F"),
  };
  Set<Letter> alphabet = <Letter>{zero, one};
  Map<(State, Letter), State> transitions = <(State, Letter), State>{
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
  State start = states["A"]!;
  Set<State> accepting = <State>{states["D"]!, states["C"]!, states["E"]!};
  DFA automata = (states.values.toSet(), alphabet, transitions, start, accepting).automata.minimized();

  print(automata.generateTransitionTable());
  File("automaton.dot").writeAsStringSync(automata.dot());
}

void test3() {
  State state0 = const State(0, "q0");
  State state1 = const State(1, "q1");
  State state2 = const State(2, "q2");

  Set<State> states = <State>{state0, state1, state2};
  Set<Letter> alphabet = <Letter>{a, b};
  Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
    (state0, a): <State>{state1},
    (state1, epsilon): <State>{state2},
    (state2, b): <State>{state2},
  };
  State start = state0;
  Set<State> accepts = <State>{state2};

  NFA nfaE = NFA(states, alphabet, transitions, start, accepts);
  NFA nfa = nfaE.removeEpsilonTransitions();
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  print(minimalDfa.generateTransitionTable());
}

void test4() {
  const State stateA = State(0, "q0");
  const State stateB = State(1, "q1");
  const State stateC = State(2, "q2");
  const State stateD = State(3, "q3");
  const State stateE = State(4, "q4");
  const State stateF = State(5, "q5");

  Set<State> states = <State>{stateA, stateB, stateC, stateD, stateE, stateF};
  Set<Letter> alphabet = <Letter>{a, b, c};
  Map<(State, Letter), State> transitions = <(State, Letter), State>{
    (stateA, a): stateB,
    (stateA, b): stateD,
    (stateB, b): stateA,
    (stateB, c): stateC,
    (stateC, b): stateE,
    (stateD, c): stateE,
    (stateE, a): stateF,
    (stateE, b): stateD,
    (stateF, c): stateC,
  };
  State start = stateA;
  Set<State> accepting = <State>{stateE};

  DFA dfa = DFA(states, alphabet, transitions, start, accepting);
  DFA minimalDfa = dfa.minimized();

  print(dfa.accepts("acbbcacbbcbcbcbcbcacbacb"));
  File("dfa.dot").writeAsStringSync(dfa.dot());
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot());
}

void test5() {
  RegularExpression regex = (a & (b & c | b & c)).star & ((b & c) | (a & c & b)).plus;

  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = NFA.fromGlushkovConstruction(regex);
  DFA dfa = DFA.fromNFA(nfa);
  DFA dfaM = dfa.minimized();

  print(nfa.accepts("abababcbdcbdbdcb"));
  print(nfa.accepts("abababcbdcbdbdcb"));

  File("nfa_e.dot").writeAsStringSync(nfaE.dot(stateName: StateName.renamed));
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(dfaM.dot(stateName: StateName.renamed));
}

void test6() {
  // Let regular expression be (0|(1(01*(00)*0)*1)*)*.
  RegularExpression regex = (zero | (one & (zero & one.star & (zero & zero).star & zero).star & one).star).star;

  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = NFA.fromGlushkovConstruction(regex);
  DFA dfa = DFA.fromNFA(nfa);
  DFA dfaM = dfa.minimized();

  print(nfa.accepts("010000"));

  File("nfa_e.dot").writeAsStringSync(nfaE.dot(stateName: StateName.renamed));
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(dfaM.dot(stateName: StateName.renamed));
}

void test7() {
  /// Let the regular expression be (ε|a*b)
  RegularExpression regex = epsilon | a.star & b;

  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = nfaE.removeEpsilonTransitions();
  DFA dfa = DFA.fromNFA(nfa);
  DFA dfaM = dfa.minimized();

  print(nfa.accepts("ab"));

  File("nfa_e.dot").writeAsStringSync(nfaE.dot(stateName: StateName.renamed));
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(dfaM.dot(stateName: StateName.renamed));
}

void test8() {
  // A regular expression that accepts all strings that contain the substring '001'.
  // (0|1)*001(0|1)*
  RegularExpression regex = (zero | one).star & (zero & zero & one) & (zero | one).star;
  NFA nfaE = NFA.fromRegularExpression(regex);
  NFA nfa = nfaE.removeEpsilonTransitions();
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  File("nfa_e.dot").writeAsStringSync(nfaE.dot());
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot(stateName: StateName.renamed));

  print(dfa.accepts("01010010101001010101010"));
}

void test9() {
  // A regular expression that accepts all strings that contain the substring '001'.
  // (0|1)*001(0|1)*
  RegularExpression regex = (zero | one).star & (zero & zero & one) & (zero | one).star;
  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = NFA.fromGlushkovConstruction(regex);
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  File("nfa_e.dot").writeAsStringSync(nfaE.dot());
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot(stateName: StateName.renamed));

  print(dfa.accepts("01010010101001010101010"));
}

void test10() {
  // A regular expression that accepts all strings that contain the substring '001'.
  // (0|1)*001(0|1)*
  RegularExpression regex = (zero | one | two).star & (a & b & c).plus;
  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = NFA.fromGlushkovConstruction(regex);
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  File("nfa_e.dot").writeAsStringSync(nfaE.dot());
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot(stateName: StateName.renamed));

  print(dfa.accepts("01010010101001010101010"));
}

void test11() {
  // (a+b)c
  RegularExpression regex = (a | b) & c;
  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = NFA.fromGlushkovConstruction(regex);
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  File("nfa_e.dot").writeAsStringSync(nfaE.dot());
  File("nfa.dot").writeAsStringSync(nfa.dot(stateName: StateName.renamed));
  File("dfa.dot").writeAsStringSync(dfa.dot(stateName: StateName.renamed));
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot(stateName: StateName.renamed));

  print(dfa.accepts("01010010101001010101010"));
}

void test12() {
  // (a+b)c
  RegularExpression regex = a & (b | c).star;
  NFA nfaE = NFA.fromThompsonConstruction(regex);
  NFA nfa = nfaE.removeEpsilonTransitions();
  DFA dfa = DFA.fromNFA(nfa);
  DFA minimalDfa = dfa.minimized();

  File("nfa_e.dot").writeAsStringSync(nfaE.dot());
  File("nfa.dot").writeAsStringSync(nfa.dot());
  File("dfa.dot").writeAsStringSync(dfa.dot());
  File("dfa_m.dot").writeAsStringSync(minimalDfa.dot());

  print(minimalDfa.generateTransitionTable());

  print(dfa.accepts("01010010101001010101010"));
}

extension<T> on Set<T> {
  T operator [](int index) {
    return elementAt(index);
  }
}
