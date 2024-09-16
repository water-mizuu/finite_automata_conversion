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
  String toString() => label;
}

final class DFA {
  const DFA(this.states, this.alphabet, this.transitions, this.start, this.accepting);

  factory DFA.fromNFA(
    NFA automaton, {
    bool minimized = false,
  }) {
    automaton = automaton.removeEpsilonTransitions();

    State start = automaton.start;
    Set<State> states = <State>{start};
    Set<Letter> alphabet = automaton.alphabet;
    Map<(State, Letter), State> transitions = <(State, Letter), State>{};
    Set<State> accepting = <State>{} //
      ..addAll(<State>{if (automaton.accepting.contains(automaton.start)) start});

    Queue<Set<State>> queue = Queue<Set<State>>()..add(states.toSet());
    Map<String, int> stateCounter = <String, int>{start.label: start.id};

    while (queue.isNotEmpty) {
      Set<State> current = queue.removeFirst();

      /// This is very hacky.
      ///   This way, we can assure that the creation of states are unique.
      String fromLabel = current.label;
      State fromState = switch (states.where((State v) => v.label == fromLabel).firstOrNull) {
        State state => state,
        null => State(stateCounter[fromLabel] ??= stateCounter.length, fromLabel),
      };
      states.add(fromState);

      for (Letter letter in alphabet) {
        Set<State> nextStates = current //
            .expand((State from) => automaton.transitions[(from, letter)] ?? <State>{})
            .toSet();

        if (nextStates.isEmpty) {
          continue;
        }

        String toLabel = nextStates.label;
        State toState = switch (states.where((State v) => v.label == toLabel).firstOrNull) {
          State state => state,
          null => State(stateCounter[toLabel] ??= stateCounter.length, toLabel),
        };

        transitions[(fromState, letter)] = toState;
        if (nextStates.intersection(automaton.accepting).isNotEmpty) {
          accepting.add(toState);
        }
        if (states.add(toState)) {
          queue.add(nextStates);
        }
      }
    }

    DFA automata = DFA(states, alphabet, transitions, start, accepting);

    if (minimized) {
      return automata.minimized();
    }
    return automata;
  }

  /// Σ
  final Set<State> states;

  /// Q
  final Set<Letter> alphabet;

  /// δ
  final Map<(State, Letter), State> transitions;

  /// q₀
  final State start;

  /// F
  final Set<State> accepting;

  DFA minimized() {
    Set<Set<State>> partitions = <Set<State>>{
      <State>{
        for (State state in states)
          if (!accepting.contains(state)) state,
      },
      <State>{...accepting},
    };
    partitions.removeWhere((Set<State> partition) => partition.isEmpty);

    /// I. Figure out the grouping of the new states.
    /// Since we should not modify the set(s) we are iterating over, we need to create a temporary set.
    Set<Set<State>> newPartitions = <Set<State>>{};
    Map<Set<State>, Set<State>> toRemoveFromPartitions = <Set<State>, Set<State>>{};
    bool run = false;

    do {
      run = false;

      for (Set<State> partition in partitions) {
        if (partition.length == 1) {
          continue;
        }

        Set<State> toRemoveFromPartition = <State>{};
        State leftComparator = partition.first;
        for (State rightComparator in partition.skip(1)) {
          for (Letter letter in alphabet) {
            State? leftTo = transitions[(leftComparator, letter)];
            State? rightTo = transitions[(rightComparator, letter)];

            if (partitions.where((Set<State> p) => p.contains(leftTo)).firstOrNull !=
                partitions.where((Set<State> p) => p.contains(rightTo)).firstOrNull) {
              /// We need to remove this from the current partition.
              toRemoveFromPartition.add(rightComparator);

              /// We need to add it to a new partition.
              newPartitions.add(<State>{rightComparator});

              run |= true;
              break;
            }
          }
        }

        toRemoveFromPartitions[partition] = toRemoveFromPartition;
      }

      partitions.addAll(newPartitions);
      for (var (Set<State> partition, Set<State> toRemove) in toRemoveFromPartitions.pairs) {
        partition.removeAll(toRemove);
      }

      newPartitions.clear();
      toRemoveFromPartitions.clear();
    } while (run);

    /// II. Create the new states.

    Map<Set<State>, int> groupIds = <Set<State>, int>{};
    for (Set<State> partition in partitions) {
      groupIds[partition] = groupIds.length;
    }

    /// Points each state to its partition.
    Map<State, Set<State>> groupings = <State, Set<State>>{
      for (State state in states)
        for (Set<State> partition in partitions)
          if (partition.contains(state)) state: partition,
    };

    /// Points each partition to its new state.
    Map<Set<State>, State> newStateMap = <Set<State>, State>{
      for (Set<State> partition in partitions) //
        partition: State(groupIds[partition]!, partition.label),
    };

    /// III. Create the new transitions.
    Map<(State, Letter), State> newTransitions = <(State, Letter), State>{
      for (var ((State source, Letter letter), State target) in transitions.pairs)
        (newStateMap[groupings[source]]!, letter): newStateMap[groupings[target]]!,
    };

    /// IV. Complete the different sets.

    Set<State> newStates = newStateMap.values.toSet();
    Set<Letter> newAlphabet = alphabet;
    State newStart = newStateMap[groupings[start]]!;
    Set<State> newAccepting = <State>{for (State state in accepting) newStateMap[groupings[state]]!};

    return DFA(newStates, newAlphabet, newTransitions, newStart, newAccepting);
  }

  bool accepts(String string) {
    State state = start;

    for (String char in string.split("")) {
      if (transitions[(state, Letter(char))] case State newState) {
        state = newState;
      } else {
        return false;
      }
    }

    return accepting.contains(state);
  }

  String generateTransitionTable() {
    /// 0. Prerequisites
    List<State> sortedStates = <State>[...states]..sort((State a, State b) => a.id - b.id);

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
    for (var ((State source, Letter letter), State value) in transitions.pairs) {
      int x = yLabels.indexOf(letter.rawLetter);
      int y = xLabels.indexOf(source.label) + 2;
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

  String dot({StateName stateName = StateName.blank}) {
    StringBuffer buffer = StringBuffer("digraph G {\n");

    /// By utilizing the topological sorting, we can:
    ///   1. Rename the states.
    ///   2. Remove the states that are not reachable from the start state.
    Map<State, String> topologicalSorting = _topologicalSortRenames(this.states);

    Set<(bool, State)> states = <(bool, State)>{
      for (State state in this.states)
        if (topologicalSorting.containsKey(state)) (accepting.contains(state), state),
    };
    Map<(State, Letter), State> transitions = <(State, Letter), State>{
      for (var ((State source, Letter letter), State target) in this.transitions.pairs)
        if (topologicalSorting.containsKey(source) && topologicalSorting.containsKey(target)) //
          (source, letter): target,
    };
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
    for (var ((State source, Letter letter), State target) in transitions.pairs) {
      buffer.writeln('  ${source.id} -> ${target.id} [label="${letter.delinearized}"];');
    }

    buffer.writeln("}");

    return buffer.toString();
  }

  Map<State, String> _topologicalSortRenames(Set<State> states) {
    Map<State, String> renames = Map<State, String>.identity();
    Queue<State> queue = Queue<State>()..add(start);

    while (queue.isNotEmpty) {
      State state = queue.removeFirst();

      if (renames.containsKey(state)) {
        continue;
      }

      renames[state] = "q${renames.length}";

      for (Letter letter in alphabet.union(<Letter>{epsilon})) {
        if (transitions[(state, letter)] case State next) {
          queue.addLast(next);
        }
      }
    }

    return renames;
  }
}

enum NfaConversionMode {
  glushkov,
  thompson,
}

final class NFA {
  const NFA(this.states, this.alphabet, this.transitions, this.start, this.accepting);
  factory NFA.fromRegularExpression(
    RegularExpression regularExpression, {
    NfaConversionMode mode = NfaConversionMode.glushkov,
  }) =>
      switch (mode) {
        NfaConversionMode.glushkov => NFA.fromGlushkovConstruction(regularExpression),
        NfaConversionMode.thompson => NFA.fromThompsonConstruction(regularExpression),
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

  factory NFA.fromThompsonConstruction(RegularExpression regularExpression) {
    var (int id, NFA nfa) = _thompsonConstruction(regularExpression, 0);

    return nfa;
  }

  /// Σ
  final Set<State> states;

  /// Q
  final Set<Letter> alphabet;

  /// δ : Q × Σ --> Q
  final Map<(State, Letter), Set<State>> transitions;

  /// q₀
  final State start;

  /// F
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
          if (transitions[(currentState, epsilon)] case Set<State> nextStates) {
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
              .expand((State state) => transitions[(state, letter)] ?? <State>{})
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

  DFA toDFA() => DFA.fromNFA(this);

  bool accepts(String string) {
    if (alphabet.contains(epsilon)) {
      return removeEpsilonTransitions().accepts(string);
    }

    Set<State> states = <State>{start};

    for (String char in string.split("")) {
      if (states.isEmpty) {
        return false;
      }

      states = states.expand((State state) => transitions[(state, Letter(char))] ?? <State>{}).toSet();
    }

    return states.intersection(accepting).isNotEmpty;
  }

  String generateTransitionTable() {
    /// 0. Prerequisites
    List<State> sortedStates = <State>[...states]..sort((State a, State b) => a.id - b.id);

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
    for (var ((State source, Letter letter), Set<State> value) in transitions.pairs) {
      int x = yLabels.indexOf(letter.rawLetter);
      int y = xLabels.indexOf(source.label) + 2;
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

  String dot({StateName stateName = StateName.blank}) {
    StringBuffer buffer = StringBuffer("digraph G {\n");

    /// By utilizing the topological sorting, we can:
    ///   1. Rename the states.
    ///   2. Remove the states that are not reachable from the start state.
    Map<State, String> topologicalSorting = _topologicalSortRenames(this.states);

    Set<(bool, State)> states = <(bool, State)>{
      for (State state in this.states)
        if (topologicalSorting.containsKey(state)) (accepting.contains(state), state),
    };
    Map<(State, Letter), Set<State>> transitions = <(State, Letter), Set<State>>{
      for (var ((State source, Letter letter), Set<State> targets) in this.transitions.pairs)
        if (topologicalSorting.containsKey(source))
          (source, letter): <State>{
            for (State target in targets)
              if (topologicalSorting.containsKey(target)) target,
          },
    };
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
    for (var ((State source, Letter letter), Set<State> targets) in transitions.pairs) {
      for (State target in targets) {
        buffer.writeln('  ${source.id} -> ${target.id} [label="${letter.delinearized}"];');
      }
    }

    buffer.writeln("}");

    return buffer.toString();
  }

  Map<State, String> _topologicalSortRenames(Set<State> states) {
    Map<State, String> renames = Map<State, String>.identity();
    Queue<State> queue = Queue<State>()..add(start);

    while (queue.isNotEmpty) {
      State state = queue.removeFirst();

      if (renames.containsKey(state)) {
        continue;
      }

      renames[state] = "q${renames.length}";

      for (Letter letter in alphabet.union(<Letter>{epsilon})) {
        transitions[(state, letter)]?.forEach(queue.addLast);
      }
    }

    return renames;
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
          ...leftNfa.transitions,
          ...rightNfa.transitions,
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
          ...leftNfa.transitions,
          ...rightNfa.transitions,
          for (var ((State from, Letter symbol), Set<State> to) in leftNfa.transitions.pairs)
            if (to.contains(leftEnd))
              (from, symbol): leftNfa.transitions[(from, symbol)]! //
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
          ...innerNfa.transitions,
          (innerStart, epsilon): <State>{...?innerNfa.transitions[(innerStart, epsilon)], innerEnd},
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
          ...innerNfa.transitions,
          (start, epsilon): <State>{innerNfa.start, end},
          (innerEnd, epsilon): <State>{...?innerNfa.transitions[(innerEnd, epsilon)], innerStart, end},
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
          ...innerNfa.transitions,
          (start, epsilon): <State>{innerNfa.start},
          (innerEnd, epsilon): <State>{...?innerNfa.transitions[(innerEnd, epsilon)], innerStart, end},
        };

        return (id, NFA(states, alphabet, transitions, start, <State>{end}));
    }
  }
}

extension on Set<State> {
  String get label {
    List<Indexed<String>> labels = <Indexed<String>>[
      for (State state in this)
        switch (RegExp(r".*\[(\d+)\]").matchAsPrefix(state.label)) {
          RegExpMatch match => (int.parse(match.group(1)!), state.label),
          _ => (0, state.label),
        },
    ];
    labels.sort((Indexed<String> a, Indexed<String> b) => a.$1.compareTo(b.$1));

    return labels.map((Indexed<String> pair) => pair.$2).join(", ");
  }
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
