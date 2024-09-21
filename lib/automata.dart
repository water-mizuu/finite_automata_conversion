import "dart:collection";

import "package:finite_automata_conversion/regular_expression.dart";

enum StateName { original, renamed, blank }

typedef Indexed<T> = (int, T);

final class State {
  const State(this.id, this.label);

  final int id;
  final String label;

  @override
  int get hashCode => Object.hash(id, label);

  @override
  bool operator ==(Object other) {
    if (other is State) {
      return id == other.id && label == other.label;
    }
    return false;
  }

  @override
  String toString() => "State($label)";
}

sealed class FiniteAutomata {
  const FiniteAutomata();

  bool accepts(String string);

  Set<State> get states;
  Set<Letter> get alphabet;
  Iterable<(State, Letter, State)> get transitions;
  State get start;
  Set<State> get accepting;

  String generateTransitionTable({StateName name = StateName.renamed});
  String dot({StateName stateName});
}

final class DFA extends FiniteAutomata {
  const DFA(this.states, this.alphabet, this._transitions, this.start, this.accepting);

  factory DFA.fromNFA(NFA nfa) => nfa.powerSetConstruction();

  /// Σ
  @override
  final Set<State> states;

  /// Q
  @override
  final Set<Letter> alphabet;

  /// δ
  final Map<(State, Letter), State> _transitions;

  @override
  Iterable<(State, Letter, State)> get transitions => _transitions.pairs //
      .map((((State, Letter) key, State value) triple) => (triple.$1.$1, triple.$1.$2, triple.$2));

  /// q₀
  @override
  final State start;

  /// F
  @override
  final Set<State> accepting;

  /// Minimizes the DFA according to the Hopcroft 's algorithm.
  DFA minimized() {
    Set<State> nf = this.states.difference(this.accepting);

    /// P = {F, Q \ F}
    Set<Set<State>> p = <Set<State>>{this.accepting, nf};

    /// W = {F, Q \ F}
    Set<Set<State>> w = <Set<State>>{this.accepting, nf};

    /// while (W is not empty) do
    while (w.isNotEmpty) {
      /// choose and remove a set A from W
      Set<State> a = w.first;
      w.remove(a);

      /// for each c in Σ do
      for (Letter c in this.alphabet) {
        /// let X be the set of states for which a transition on c leads to a state in A
        Set<State> x = <State>{
          for (State state in this.states)
            if (a.any((State v) => _transitions[(state, c)] == v)) state,
        };

        /// for each set Y in P for which X ∩ Y is nonempty and Y \ X is nonempty do
        for (Set<State> y in p.toSet()) {
          Set<State> xIy = x.intersection(y);
          Set<State> yDx = y.difference(x);

          if (xIy.isEmpty || yDx.isEmpty) {
            continue;
          }

          /// replace Y in P by the two sets X ∩ Y and Y \ X
          p.remove(y);
          p.add(xIy);
          p.add(yDx);

          /// if Y is in W
          if (w.contains(y)) {
            /// replace Y in W by the same two sets
            w.remove(y);
            w.add(xIy);
            w.add(yDx);
          } else {
            /// if |X ∩ Y| <= |Y \ X|
            if (xIy.length <= yDx.length) {
              /// add X ∩ Y to W
              w.add(xIy);
            } else {
              /// add Y \ X to W
              w.add(yDx);
            }
          }
        }
      }
    }

    /// The equivalence classes are now in [p].

    print(p.length);
    Set<State> states = <State>{};
    for (Set<State> v in p) {
      states.add(State(states.length, v.label));
    }

    Set<Letter> alphabet = this.alphabet;

    Map<(State, Letter), State> transitions = <(State, Letter), State>{
      for (var ((State source, Letter letter), State target) in _transitions.pairs)
        (
          states.firstWhere((State state) => state.label == p.firstWhere((Set<State> v) => v.contains(source)).label),
          letter
        ): states.firstWhere((State state) => state.label == p.firstWhere((Set<State> v) => v.contains(target)).label),
    };

    State start = states //
        .firstWhere((State state) => state.label == p.firstWhere((Set<State> v) => v.contains(this.start)).label);

    Set<State> accepting = <State>{
      for (Set<State> v in p)
        if (v.intersection(this.accepting).isNotEmpty) //
          states.firstWhere((State state) => state.label == v.label),
    };

    return DFA(states, alphabet, transitions, start, accepting);
  }

  /// Returns an NFA that accepts the reverse of the language of the original DFA.
  NFA reversed() {
    Set<State> states = <State>{...this.states};
    Set<Letter> alphabet = <Letter>{...this.alphabet};
    Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{};

    for (var ((State source, Letter letter), State target) in _transitions.pairs) {
      transitions //
          .putIfAbsent((target, letter), () => <State>{}) //
          .add(source);
    }

    State start;

    /// We need to convert the NFA to a GNFA whenever there are multiple accepting states.
    if (accepting.length > 1) {
      start = State(states.length, "^");
      states.add(start);
      transitions //
          .putIfAbsent((start, epsilon), () => <State>{}) //
          .addAll(accepting);
    } else {
      start = accepting.single;
    }

    State accept = this.start;
    NFA result = NFA(states, alphabet, transitions, start, <State>{accept});

    return result;
  }

  @override
  bool accepts(String string) {
    State state = start;

    for (String char in string.split("")) {
      if (_transitions[(state, Letter(char))] case State newState) {
        state = newState;
      } else {
        return false;
      }
    }

    return accepting.contains(state);
  }

  @override
  String generateTransitionTable({StateName name = StateName.renamed}) {
    assert(name != StateName.blank, "In generating the transition table, it cannot be blank.");

    /// 0. Prerequisites
    Map<State, String> renames = _topologicalSortRenames();
    List<State> sortedStates = <State>[
      for (State state in states) State(state.id, renames[state]!),
    ]..sort((State a, State b) => a.label.compareTo(b.label));

    /// 1. Generate the labels.
    List<String> yLabels = <String>["", for (Letter letter in alphabet) letter.toString()];
    List<String> xLabels = <String>[for (State state in sortedStates) state.label];

    /// 2. Generate the matrix to be extended.
    List<List<String>> stringMatrix = <List<String>>[
      yLabels,
      <String>[for (int x = 0; x < yLabels.length; ++x) ""],
      for (int y = 0; y < xLabels.length; ++y)
        <String>[
          xLabels[y],
          for (int x = 0; x < yLabels.length - 1; ++x) "",
        ],
    ];

    /// 3. Fill the matrix with the transitions.
    for (var ((State source, Letter letter), State value) in _transitions.pairs) {
      int x = yLabels.indexOf(letter.rawLetter);
      int y = xLabels.indexOf(renames[source]!) + 2;
      assert(y != 0);
      assert(x != -1);

      stringMatrix[y][x] = renames[value]!;
    }

    /// 4. Highlight the start and accepting states.
    for (int y = 2; y < stringMatrix.length; ++y) {
      State state = states.firstWhere((State state) => renames[state]! == stringMatrix[y][0]);

      if (accepting.contains(state)) {
        stringMatrix[y][0] = "*  ${stringMatrix[y][0]}";
      } else if (state == start) {
        stringMatrix[y][0] = "-> ${stringMatrix[y][0]}";
      } else {
        stringMatrix[y][0] = "   ${stringMatrix[y][0]}";
      }
    }

    /// 5. Pad the matrix for alignment.
    List<int> profiles = <int>[
      for (int x = 0; x < stringMatrix[0].length; ++x) //
        stringMatrix.map((List<String> row) => row[x].length).reduce((int a, int b) => a > b ? a : b),
    ];
    for (int x = 0; x < stringMatrix[0].length; ++x) {
      for (int y = 0; y < stringMatrix.length; ++y) {
        stringMatrix[y][x] = stringMatrix[y][x].padRight(
          profiles[x],
          switch (y) { 1 => "-", _ => " " },
        );
      }
    }

    /// 6. Insert the horizontal separator.
    return stringMatrix.indexed
        .map(
          (Indexed<List<String>> row) => switch (row) {
            (1, List<String> row) => row.join("-+-"),
            (_, List<String> row) => row.join(" | "),
          },
        )
        .join("\n");
  }

  @override
  String dot({StateName stateName = StateName.blank}) {
    StringBuffer buffer = StringBuffer("digraph G {\n");

    /// By utilizing the topological sorting, we can:
    ///   1. Rename the states.
    ///   2. Remove the states that are not reachable from the start state.
    Map<State, String> topologicalSorting = _topologicalSortRenames();

    Set<(bool, State)> states = <(bool, State)>{
      for (State state in this.states) (accepting.contains(state), state),
    };
    Map<(State, State), Set<Letter>> transformedTransitions = <(State, State), Set<Letter>>{};
    for (var ((State state, Letter letter), State target) in _transitions.pairs) {
      transformedTransitions.putIfAbsent((state, target), () => <Letter>{}).add(letter);
    }

    buffer.writeln("  rankdir=LR;");
    buffer.writeln('  n__ [label="" shape=none width=.0];');
    for (var (bool accepting, State state) in states) {
      buffer
        ..write("  ${state.id} [shape=")
        ..write(accepting ? "double" "circle" : "circle")
        ..write(' label="')
        ..write(
          switch (stateName) {
            StateName.original => state.label,
            StateName.renamed => topologicalSorting[state]!,
            StateName.blank => "",
          },
        )
        ..writeln('"]');
    }

    buffer.writeln("  n__ -> ${start.id};");
    for (var ((State source, State target), Set<Letter> letters) in transformedTransitions.pairs) {
      String transitionLabel = letters.map((Letter v) => v.delinearized).join(", ");
      buffer.writeln('  ${source.id} -> ${target.id} [label="$transitionLabel"]');
    }

    buffer.writeln("}");

    return buffer.toString();
  }

  Map<State, String> _topologicalSortRenames() {
    Map<State, String> renames = Map<State, String>.identity();
    Queue<State> queue = Queue<State>()..add(start);

    while (queue.isNotEmpty) {
      State state = queue.removeFirst();

      if (renames.containsKey(state)) {
        continue;
      }

      renames[state] = "q${renames.length}";

      for (Letter letter in alphabet.union(<Letter>{epsilon})) {
        if (_transitions[(state, letter)] case State next) {
          queue.addLast(next);
        }
      }
    }

    return renames;
  }
}

enum NFAConversionMode {
  glushkov,
  thompson,
}

final class NFA extends FiniteAutomata {
  const NFA(this.states, this.alphabet, this._transitions, this.start, this.accepting);

  factory NFA.fromRegularExpression(
    RegularExpression regularExpression, {
    NFAConversionMode mode = NFAConversionMode.glushkov,
  }) =>
      switch (mode) {
        NFAConversionMode.glushkov => NFA.fromGlushkovConstruction(regularExpression),
        NFAConversionMode.thompson => NFA.fromThompsonConstruction(regularExpression),
      };

  factory NFA.fromGlushkovConstruction(RegularExpression regularExpression) {
    RegularExpression linearized = regularExpression.linearized;

    Set<Letter> prefixes = Set<Letter>.identity()..addAll(linearized.prefixes);
    Set<Letter> suffixes = Set<Letter>.identity()..addAll(linearized.suffixes);
    Set<(Letter, Letter)> pairs = Set<(Letter, Letter)>.identity()..addAll(linearized.pairs);

    State start = const State(0, "1");
    Set<Letter> alphabet = Set<Letter>.identity()..addAll(regularExpression.letters);
    Set<State> states = Set<State>.identity()..add(start);
    Set<State> accepting = Set<State>.identity();

    /// If the regular expression is nullable, the start state is accepting.
    /// (This is a bug in the original implementation.)
    if (regularExpression.isNullable) {
      accepting.add(start);
    }

    for (Letter letter in linearized.letters) {
      String stateName = letter.toString();
      State state = State(letter.id!, stateName);

      states.add(state);
      if (suffixes.contains(letter)) {
        accepting.add(state);
      }
    }

    Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
      for (Letter letter in alphabet) (start, letter): <State>{},
      for (State state in states)
        for (Letter letter in alphabet) (state, letter): <State>{},
    };

    for (Letter letter in prefixes) {
      states //
          .where((State state) => state.id == letter.id)
          .forEach(transitions[(start, letter.delinearized)]!.add);
    }

    for (var (Letter left, Letter right) in pairs) {
      State originState = states.firstWhere((State state) => state.id == left.id);

      states //
          .where((State state) => state.id == right.id)
          .forEach(transitions[(originState, right.delinearized)]!.add);
    }

    return NFA(states, alphabet, transitions, start, accepting);
  }

  factory NFA.fromThompsonConstruction(RegularExpression regularExpression) => regularExpression.thompsonConstruction();

  /// Σ
  @override
  final Set<State> states;

  /// Q
  @override
  final Set<Letter> alphabet;

  /// δ : Q × Σ --> Q
  final Map<(State, Letter), Set<State>> _transitions;

  @override
  Iterable<(State, Letter, State)> get transitions => _transitions.pairs.expand(
        (((State, Letter) key, Set<State> value) triple) =>
            triple.$2.map((State right) => (triple.$1.$1, triple.$1.$2, right)),
      );

  /// q₀
  @override
  final State start;

  /// F
  @override
  final Set<State> accepting;

  NFA removeEpsilonTransitions() {
    /// 1. Compute the ε-closure of each state.
    ///   Definition: the ε-closure of a state q is the set of all states
    ///          that can be reached from q by following only ε-transitions.
    ///   It is described as E(q) = {q} ∪ {p | p ∈ E(δ(q, ε))}.
    Map<State, Set<State>> epsilonClosure = <State, Set<State>>{
      for (State state in states) state: Set<State>.identity()..add(state),
    };

    for (State state in states) {
      Queue<State> queue = Queue<State>()..add(state);

      while (queue.isNotEmpty) {
        State currentState = queue.removeFirst();

        if (epsilonClosure[state] case Set<State> closure) {
          if (_transitions[(currentState, epsilon)] case Set<State> nextStates) {
            queue.addAll(nextStates.difference(closure));
            closure.addAll(nextStates);
          }
        }
      }
    }

    /// 2. The new alphabet, Σ' = Σ \ {ε}.
    Set<Letter> newAlphabet = alphabet.difference(<Object?>{epsilon});

    /// 3. Compute the new transitions, δ'.
    Map<(State, Letter), Set<State>> newTransitions = <(State, Letter), Set<State>>{
      for (Letter letter in alphabet.where((Letter letter) => letter is! Epsilon))
        for (State state in states)

          /// ∀α ∈ Σ δ'(q, α) = ε(δ(ε(q), α))
          (state, letter): epsilonClosure[state]! //
              .expand((State state) => _transitions[(state, letter)] ?? <State>{})
              .expand((State state) => epsilonClosure[state]!)
              .toSet(),
    }..removeWhere(((State, Letter) key, Set<State> value) => value.isEmpty);

    /// 4. Compute the new accepting states.
    ///   A state q is accepting if ε(q) ∩ F ≠ ∅.
    Set<State> newAccepting = <State>{
      for (State state in states)
        if (epsilonClosure[state]!.intersection(accepting).isNotEmpty) //
          state,
    };

    return NFA(states, newAlphabet, newTransitions, start, newAccepting);
  }

  /// Returns a DFA according to the powerset construction algorithm.
  DFA powerSetConstruction() {
    NFA nfa = removeEpsilonTransitions();

    Set<State> states = <State>{};
    Set<Letter> alphabet = nfa.alphabet.toSet();
    Map<(State, Letter), State> transitions = <(State, Letter), State>{};
    Set<State> accepting = <State>{};

    Map<String, int> stateCounter = <String, int>{};

    /// This function creates a new state from a set of states
    ///   if it does not exist.
    (bool, State) createOrGetState(Set<State> stateSet) {
      String label = stateSet.label;
      State found = switch (states.where((State v) => v.label == label).firstOrNull) {
        State state => state,
        null => State(stateCounter[label] ??= stateCounter.length, label),
      };
      if (stateSet.intersection(nfa.accepting).isNotEmpty) {
        accepting.add(found);
      }

      return (states.add(found), found);
    }

    Queue<Set<State>> queue = Queue<Set<State>>()..add(<State>{nfa.start});
    var (_, State start) = createOrGetState(<State>{nfa.start});

    while (queue.isNotEmpty) {
      Set<State> current = queue.removeFirst();

      /// This is very hacky.
      ///   This way, we can assure that the creation of states are unique.
      var (_, State fromState) = createOrGetState(current);

      for (Letter letter in alphabet) {
        Set<State> nextStates = <State>{
          for (State from in current) //
            ...?nfa._transitions[(from, letter)],
        };

        if (nextStates.isNotEmpty) {
          var (bool isNew, State toState) = createOrGetState(nextStates);

          transitions[(fromState, letter)] = toState;
          if (nextStates.intersection(nfa.accepting).isNotEmpty) {
            accepting.add(toState);
          }
          if (isNew) {
            queue.add(nextStates);
          }
        }
      }
    }

    return (states, alphabet, transitions, start, accepting).automata;
  }

  DFA toDFA() => powerSetConstruction();

  @override
  bool accepts(String string) {
    if (alphabet.contains(epsilon)) {
      return removeEpsilonTransitions().accepts(string);
    }

    Set<State> states = <State>{start};

    for (String char in string.split("")) {
      if (states.isEmpty) {
        return false;
      }

      states = states.expand((State state) => _transitions[(state, Letter(char))] ?? <State>{}).toSet();
    }

    return states.intersection(accepting).isNotEmpty;
  }

  @override
  String generateTransitionTable({StateName name = StateName.renamed}) {
    assert(name != StateName.blank, "In generating the transition table, it cannot be blank.");

    /// 0. Prerequisites
    Map<State, String> renames = _topologicalSortRenames();
    List<State> sortedStates = <State>[
      for (State state in states) State(state.id, renames[state]!),
    ]..sort((State a, State b) => a.label.compareTo(b.label));

    /// 1. Generate the labels.
    List<String> yLabels = <String>["", for (Letter letter in alphabet) letter.toString()];
    List<String> xLabels = <String>[for (State state in sortedStates) state.label];

    /// 2. Generate the matrix to be extended.
    List<List<String>> stringMatrix = <List<String>>[
      yLabels,
      <String>[for (int x = 0; x < yLabels.length; ++x) ""],
      for (int y = 0; y < xLabels.length; ++y)
        <String>[
          xLabels[y],
          for (int x = 0; x < yLabels.length - 1; ++x) "",
        ],
    ];

    /// 3. Fill the matrix with the transitions.
    for (var ((State source, Letter letter), Set<State> value) in _transitions.pairs) {
      int x = yLabels.indexOf(letter.rawLetter);
      int y = xLabels.indexOf(renames[source]!) + 2;
      assert(y != 0);
      assert(x != -1);

      stringMatrix[y][x] = value.label;
    }

    /// 4. Highlight the start and accepting states.
    for (int y = 2; y < stringMatrix.length; ++y) {
      State state = states.firstWhere((State state) => state.label == stringMatrix[y][0]);

      if (accepting.contains(state)) {
        stringMatrix[y][0] = "*  ${stringMatrix[y][0]}";
      } else if (state == start) {
        stringMatrix[y][0] = "-> ${stringMatrix[y][0]}";
      } else {
        stringMatrix[y][0] = "   ${stringMatrix[y][0]}";
      }
    }

    /// 5. Pad the matrix for alignment.
    List<int> profiles = <int>[
      for (int x = 0; x < stringMatrix[0].length; ++x) //
        stringMatrix.map((List<String> row) => row[x].length).reduce((int a, int b) => a > b ? a : b),
    ];
    for (int x = 0; x < stringMatrix[0].length; ++x) {
      for (int y = 0; y < stringMatrix.length; ++y) {
        stringMatrix[y][x] = stringMatrix[y][x].padRight(
          profiles[x],
          switch (y) { 1 => "-", _ => " " },
        );
      }
    }

    /// 6. Insert the horizontal separator.
    return stringMatrix.indexed
        .map(
          (Indexed<List<String>> row) => switch (row) {
            (1, List<String> row) => row.join("-+-"),
            (_, List<String> row) => row.join(" | "),
          },
        )
        .join("\n");
  }

  @override
  String dot({StateName stateName = StateName.blank}) {
    StringBuffer buffer = StringBuffer("digraph G {\n");

    /// By utilizing the topological sorting, we can:
    ///   1. Rename the states.
    ///   2. Remove the states that are not reachable from the start state.
    Map<State, String> topologicalSorting = _topologicalSortRenames();
    Set<(bool, State)> states = <(bool, State)>{
      for (State state in this.states)
        if (topologicalSorting.containsKey(state)) //
          (accepting.contains(state), state),
    };
    Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
      for (var ((State source, Letter letter), Set<State> targets) in _transitions.pairs)
        if (topologicalSorting.containsKey(source))
          (source, letter): <State>{
            for (State target in targets)
              if (topologicalSorting.containsKey(target)) target,
          },
    };
    Map<(State, State), Set<Letter>> transformedTransitions = <(State, State), Set<Letter>>{};
    for (var ((State state, Letter letter), Set<State> targets) in transitions.pairs) {
      for (State target in targets) {
        transformedTransitions.putIfAbsent((state, target), () => <Letter>{}).add(letter);
      }
    }

    buffer.writeln("  rankdir=LR;");
    buffer.writeln('  n__ [label="" shape=none width=.0];');
    for (var (bool accepting, State state) in states) {
      buffer
        ..write("  ${state.id} [shape=")
        ..write(accepting ? "double" "circle" : "circle")
        ..write(' label="')
        ..write(
          switch (stateName) {
            StateName.original => state.label,
            StateName.renamed => topologicalSorting[state]!,
            StateName.blank => "",
          },
        )
        ..writeln('"]');
    }

    buffer.writeln("  n__ -> ${start.id};");
    for (var ((State source, State target), Set<Letter> letters) in transformedTransitions.pairs) {
      buffer
          .writeln('  ${source.id} -> ${target.id} [label="${letters.map((Letter v) => v.delinearized).join(", ")}"]');
    }

    buffer.writeln("}");

    return buffer.toString();
  }

  Map<State, String> _topologicalSortRenames() {
    Map<State, String> renames = Map<State, String>.identity();
    Queue<State> queue = Queue<State>()..add(start);

    while (queue.isNotEmpty) {
      State state = queue.removeFirst();

      if (renames.containsKey(state)) {
        continue;
      }

      renames[state] = "q${renames.length}";

      for (Letter letter in alphabet.union(<Letter>{epsilon})) {
        _transitions[(state, letter)]?.forEach(queue.addLast);
      }
    }

    return renames;
  }
}

extension on Set<State> {
  String get label => map((State state) => state.label).join(", ");
}

extension<K, V> on Map<K, V> {
  Iterable<(K, V)> get pairs => entries.map((MapEntry<K, V> entry) => (entry.key, entry.value));
}

extension DeterministicFiniteAutomataCreator on (
  Set<State> states,
  Set<Letter> alphabet,
  Map<(State, Letter), State> transitions,
  State start,
  Set<State> accepting,
) {
  DFA get automata => DFA($1, $2, $3, $4, $5);
}

extension NonDeterministicFiniteAutomataCreator on (
  Set<State> states,
  Set<Letter> alphabet,
  Map<(State, Letter), Set<State>> transitions,
  State start,
  Set<State> accepting,
) {
  NFA get automata => NFA($1, $2, $3, $4, $5);
}

extension ThompsonConstructionExtension on RegularExpression {
  /// Returns an NFA according to the Glushkov's construction algorithm.
  NFA glushkovConstruction() {
    RegularExpression linearized = this.linearized;

    /// The set P(e) of a linearized regular expression refers to
    ///   all of the states where the regular expression can start in.
    ///
    /// This is used to determine the states that are reachable from the start state.
    Set<Letter> prefixes = Set<Letter>.identity()..addAll(linearized.prefixes);

    /// The set D(e) of a linearized regular expression refers to
    ///   all of the states where the regular expression can end in.
    ///
    /// This is used to determine the accepting states.
    Set<Letter> suffixes = Set<Letter>.identity()..addAll(linearized.suffixes);

    /// The set F(e) of a linearized regular expression refers to
    ///   all of the pairs of successions of states in the regular expression.
    ///
    /// This is used to determine the transitions between states.
    Set<(Letter, Letter)> pairs = Set<(Letter, Letter)>.identity()..addAll(linearized.pairs);

    State start = const State(0, "1");
    Set<Letter> alphabet = letters.toSet();
    Set<State> states = Set<State>.identity()..add(start);
    Set<State> accepting = Set<State>.identity();

    /// If the regular expression is nullable, the start state is accepting.
    if (isNullable) {
      accepting.add(start);
    }

    /// For each linearized letter, we create a state.
    ///   If the linearized letter is in D, then the state is accepting.
    for (Letter letter in linearized.letters) {
      String stateName = letter.toString();
      State state = State(letter.id!, stateName);

      states.add(state);
      if (suffixes.contains(letter)) {
        accepting.add(state);
      }
    }

    Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
      for (Letter letter in alphabet) (start, letter): <State>{},
      for (State state in states)
        for (Letter letter in alphabet) (state, letter): <State>{},
    };

    /// For each linearized letter in P, we create a
    ///   transition from the start state to the state.
    for (Letter letter in prefixes) {
      states //
          .where((State state) => state.id == letter.id)
          .forEach(transitions[(start, letter.delinearized)]!.add);
    }

    /// For the rest of the pairs, we create transitions between the states.
    ///   The symbol of the transition is the second letter of the pair.
    for (var (Letter left, Letter right) in pairs) {
      State originState = states.firstWhere((State state) => state.id == left.id);
      State targetState = states.firstWhere((State state) => state.id == right.id);

      transitions[(originState, right.delinearized)]!.add(targetState);
    }

    return NFA(states, alphabet, transitions, start, accepting);
  }

  /// Returns an NFA according to the Thompson's construction algorithm.
  NFA thompsonConstruction() {
    var (int id, NFA nfa) = _thompsonConstruction(this, 0);

    return nfa;
  }

  /// Thompson's construction algorithm, according to the wikipedia page:
  ///
  /// https://en.wikipedia.org/wiki/Thompson%27s_construction
  static (int, NFA) _thompsonConstruction(RegularExpression regularExpression, int idStart) {
    switch (regularExpression) {
      /// Since Epsilon <: Letter, this case handles epsilon characters.
      case Letter regularExpression:
        int id = idStart;
        State start = State(id++, "${id - 1}");
        State end = State(id++, "${id - 1}");
        Set<State> states = <State>{start, end};
        Set<Letter> alphabet = <Letter>{regularExpression};
        Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
          (start, regularExpression): <State>{end},
        };
        Set<State> accepting = <State>{end};

        return (id, NFA(states, alphabet, transitions, start, accepting));

      case Choice regularExpression:
        int id = idStart;
        State start = State(id++, "${id - 1}");
        State end = State(id++, "${id - 1}");
        NFA leftNfa;
        NFA rightNfa;

        (id, leftNfa) = _thompsonConstruction(regularExpression.left, id);
        State leftStart = leftNfa.start;
        State leftEnd = leftNfa.accepting.single;

        (id, rightNfa) = _thompsonConstruction(regularExpression.right, id);
        State rightStart = rightNfa.start;
        State rightEnd = rightNfa.accepting.single;

        Set<State> states = <State>{start, end, ...leftNfa.states, ...rightNfa.states};
        Set<Letter> alphabet = leftNfa.alphabet.union(rightNfa.alphabet);
        Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
          ...leftNfa._transitions,
          ...rightNfa._transitions,
          (start, epsilon): <State>{leftStart, rightStart},
          (leftEnd, epsilon): <State>{end},
          (rightEnd, epsilon): <State>{end},
        };

        return (id, NFA(states, alphabet, transitions, start, <State>{end}));

      case Concatenation regularExpression:
        int id = idStart;
        NFA leftNfa;
        NFA rightNfa;

        (id, leftNfa) = _thompsonConstruction(regularExpression.left, id);
        State leftStart = leftNfa.start;
        State leftEnd = leftNfa.accepting.single;

        (id, rightNfa) = _thompsonConstruction(regularExpression.right, id);
        State rightStart = rightNfa.start;
        State rightEnd = rightNfa.accepting.single;

        /// We need to replace left's end state with right's start state.
        Set<State> states = <State>{...leftNfa.states, ...rightNfa.states}.difference(<State>{leftEnd});
        Set<Letter> alphabet = leftNfa.alphabet.union(rightNfa.alphabet);
        Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
          ...leftNfa._transitions,
          ...rightNfa._transitions,
          for (var ((State from, Letter symbol), Set<State> to) in leftNfa._transitions.pairs)
            if (to.contains(leftEnd))
              (from, symbol): leftNfa._transitions[(from, symbol)]! //
                  .difference(<State>{leftEnd}) //
                  .union(<State>{rightStart}),
        };

        return (id, NFA(states, alphabet, transitions, leftStart, <State>{rightEnd}));
      case Optional regularExpression:
        int id = idStart;
        NFA innerNfa;
        (id, innerNfa) = _thompsonConstruction(regularExpression.expression, id);
        State innerStart = innerNfa.start;
        State innerEnd = innerNfa.accepting.single;

        Set<State> states = <State>{...innerNfa.states};
        Set<Letter> alphabet = innerNfa.alphabet;
        Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
          ...innerNfa._transitions,
          (innerStart, epsilon): <State>{...?innerNfa._transitions[(innerStart, epsilon)], innerEnd},
        };

        return (id, NFA(states, alphabet, transitions, innerStart, <State>{innerEnd}));
      case KleeneStar regularExpression:
        int id = idStart;
        State start = State(id++, "${id - 1}");
        State end = State(id++, "${id - 1}");
        NFA innerNfa;
        (id, innerNfa) = _thompsonConstruction(regularExpression.expression, id);
        State innerStart = innerNfa.start;
        State innerEnd = innerNfa.accepting.single;

        Set<State> states = <State>{start, end, ...innerNfa.states};
        Set<Letter> alphabet = innerNfa.alphabet;
        Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
          ...innerNfa._transitions,
          (start, epsilon): <State>{innerNfa.start, end},
          (innerEnd, epsilon): <State>{...?innerNfa._transitions[(innerEnd, epsilon)], innerStart, end},
        };

        return (id, NFA(states, alphabet, transitions, start, <State>{end}));
      case KleenePlus regularExpression:
        int id = idStart;
        State start = State(id++, "${id - 1}");
        State end = State(id++, "${id - 1}");
        NFA innerNfa;
        (id, innerNfa) = _thompsonConstruction(regularExpression.expression, id);
        State innerStart = innerNfa.start;
        State innerEnd = innerNfa.accepting.single;

        Set<State> states = <State>{start, end, ...innerNfa.states};
        Set<Letter> alphabet = innerNfa.alphabet;
        Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
          ...innerNfa._transitions,
          (start, epsilon): <State>{innerNfa.start},
          (innerEnd, epsilon): <State>{...?innerNfa._transitions[(innerEnd, epsilon)], innerStart, end},
        };

        return (id, NFA(states, alphabet, transitions, start, <State>{end}));
    }
  }
}
