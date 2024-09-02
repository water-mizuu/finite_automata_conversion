import "dart:collection";

import "package:glushkov_construction/regular_expression.dart";

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

final class DeterministicFiniteAutomata {
  const DeterministicFiniteAutomata(this.states, this.alphabet, this.transitions, this.start, this.accepting);

  factory DeterministicFiniteAutomata.fromNonDeterministicAutomaton(NonDeterministicFiniteAutomata automaton) {
    State start = automaton.start;
    Set<State> states = <State>{start};
    Set<Letter> alphabet = automaton.alphabet;
    Map<(State, Letter), State> transitions = <(State, Letter), State>{};
    Set<State> accepting = <State>{if (automaton.accepting.contains(automaton.start)) start};

    Queue<Set<State>> queue = Queue<Set<State>>()..add(states.toSet());
    Map<String, int> stateCounter = <String, int>{start.label: start.id};

    while (queue.isNotEmpty) {
      Set<State> current = queue.removeFirst();
      String fromLabel = current.label;

      for (Letter letter in alphabet) {
        Set<State> nextStates = current //
            .expand((State from) => automaton.transitions[(from, letter)] ?? <State>{})
            .toSet();

        State source = State(
          stateCounter[fromLabel] ??= stateCounter.length,
          fromLabel,
        );

        String toLabel = nextStates.label;
        State target = State(
          stateCounter[toLabel] ??= stateCounter.length,
          toLabel,
        );

        transitions[(source, letter)] = target;
        if (nextStates.intersection(automaton.accepting).isNotEmpty) {
          accepting.add(target);
        }
        if (states.add(target)) {
          queue.add(nextStates);
        }
      }
    }
    return DeterministicFiniteAutomata(states, alphabet, transitions, start, accepting);
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
          ((int, List<String>) row) => switch (row) {
            (1, List<String> row) => row.join("-+-"),
            (_, List<String> row) => row.join(" | "),
          },
        )
        .join("\n");
  }

  String dot() {
    StringBuffer buffer = StringBuffer("digraph G {\n");

    buffer.writeln("  rankdir=LR;");
    buffer.writeln('  n__ [label="" shape=none width=.0];');
    for (State state in states) {
      buffer.writeln(
        '  ${state.id} [shape=${accepting.contains(state) ? "double" "circle" : "circle"} label="${state.label}"];',
      );
    }

    buffer.writeln("  n__ -> ${start.id};");
    for (var ((State source, Letter letter), State target) in transitions.pairs) {
      buffer.writeln('  ${source.id} -> ${target.id} [label="${letter.rawLetter}"];');
    }

    buffer.writeln("}");

    return buffer.toString();
  }
}

final class NonDeterministicFiniteAutomata {
  const NonDeterministicFiniteAutomata(this.states, this.alphabet, this.transitions, this.start, this.accepting);
  factory NonDeterministicFiniteAutomata.fromRegularExpression(
    RegularExpression regularExpression, {
    bool renameStates = false,
  }) {
    RegularExpression linearized = regularExpression.linearized;

    Set<Letter> prefixes = Set<Letter>.identity()..addAll(linearized.prefixes);
    Set<Letter> suffixes = Set<Letter>.identity()..addAll(linearized.suffixes);
    Set<(Letter, Letter)> pairs = Set<(Letter, Letter)>.identity()..addAll(linearized.pairs);

    State start = renameStates ? const State(0, "q0") : const State(0, "^");
    Set<Letter> alphabet = Set<Letter>.identity()..addAll(regularExpression.letters);
    Set<State> states = Set<State>.identity()..add(start);
    Set<State> accepting = Set<State>.identity();

    for (Letter letter in linearized.letters) {
      State state = State(letter.id!, renameStates ? "q${letter.id}" : letter.toString());

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

    return NonDeterministicFiniteAutomata(states, alphabet, transitions, start, accepting);
  }

  /// Σ
  final Set<State> states;

  /// Q
  final Set<Letter> alphabet;

  /// δ
  final Map<(State, Letter), Set<State>> transitions;

  /// q₀
  final State start;

  /// F
  final Set<State> accepting;

  bool accepts(String string) {
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
          ((int, List<String>) row) => switch (row) {
            (1, List<String> row) => row.join("-+-"),
            (_, List<String> row) => row.join(" | "),
          },
        )
        .join("\n");
  }

  String dot() {
    StringBuffer buffer = StringBuffer("digraph G {\n");

    buffer.writeln("  rankdir=LR;");
    buffer.writeln('  n__ [label="" shape=none width=.0];');
    for (State state in states) {
      buffer.writeln(
        '  ${state.id} [shape=${accepting.contains(state) ? "double" "circle" : "circle"} label="${state.label}"];',
      );
    }

    buffer.writeln("  n__ -> ${start.id};");
    for (var ((State source, Letter letter), Set<State> targets) in transitions.pairs) {
      for (State target in targets) {
        buffer.writeln('  ${source.id} -> ${target.id} [label="${letter.rawLetter}"];');
      }
    }

    buffer.writeln("}");

    return buffer.toString();
  }
}

extension on Set<State> {
  String get label {
    List<(int, String)> labels = <(int, String)>[
      for (State state in this)
        switch (RegExp(r".*\[(\d+)\]").matchAsPrefix(state.label)) {
          RegExpMatch match => (int.parse(match.group(1)!), state.label),
          _ => (0, state.label),
        },
    ];
    labels.sort(((int, String) a, (int, String) b) => a.$1.compareTo(b.$1));

    return labels.map(((int, String) pair) => pair.$2).join(", ");
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
  DeterministicFiniteAutomata get automata => DeterministicFiniteAutomata($1, $2, $3, $4, $5);
}

extension NonDeterministicFiniteAutomataCreator on (
  Set<State> states,
  Set<Letter> alphabet,
  Map<(State, Letter), Set<State>> transitions,
  State start,
  Set<State> accepting,
) {
  NonDeterministicFiniteAutomata get automata => NonDeterministicFiniteAutomata($1, $2, $3, $4, $5);
}
