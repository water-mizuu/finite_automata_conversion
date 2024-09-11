sealed class RegularExpression {
  const RegularExpression();

  /// Returns all the possible [Letter]s in which the [RegularExpression] can start.
  Iterable<Letter> get prefixes;

  /// Returns all the possible [Letter]s in which the [RegularExpression] can end.
  Iterable<Letter> get suffixes;

  /// Returns all the pairs of [Letter]s that are adjacent to each other.
  /// Formally, this is the set `F(e')` for the local language `e'`.
  Iterable<(Letter, Letter)> get pairs;

  /// Recursively iterates over all the [RegularExpression], returning all the [Letter]s.
  Iterable<Letter> get letters;

  /// Returns a [bool] indicating [RegularExpression] if the [RegularExpression]
  /// accepts the empty string λ or ε.
  bool get isNullable;

  /// Returns a copy of the [RegularExpression] with all the [Letter]s being "linearized"
  /// as required by the Glushkov Construction Algorithm.
  RegularExpression get linearized => _linearized(1).$2;

  (int, RegularExpression) _linearized(int start);
}

class Letter extends RegularExpression {
  const Letter(this.rawLetter, [this.id]) : assert(rawLetter.length == 1);
  const Letter._unrestricted(this.rawLetter, [this.id]);

  final String rawLetter;
  final int? id;

  @override
  Iterable<Letter> get prefixes => <Letter>[this];

  @override
  Iterable<Letter> get suffixes => <Letter>[this];

  @override
  Iterable<(Letter, Letter)> get pairs sync* {}

  @override
  Iterable<Letter> get letters sync* {
    yield this;
  }

  @override
  bool get isNullable => false;

  @override
  String toString() {
    return "$rawLetter${switch (id) { int v => "[$v]", _ => "" }}";
  }

  @override
  (int, RegularExpression) _linearized(int start) {
    return (start + 1, Letter(rawLetter, start));
  }

  Letter get delinearized => Letter(rawLetter);

  @override
  bool operator ==(Object other) {
    if (other is Letter) {
      return rawLetter == other.rawLetter;
    }

    return false;
  }

  @override
  int get hashCode => rawLetter.hashCode;
}

class Epsilon extends Letter {
  const Epsilon([int? id]) : super._unrestricted("", id);

  @override
  String toString() => "ε";

  @override
  Epsilon get delinearized => const Epsilon();

  @override
  (int, RegularExpression) _linearized(int start) {
    return (start + 1, Epsilon(start));
  }

  @override
  bool operator ==(Object other) => other is Epsilon;

  @override
  int get hashCode => ().hashCode;
}

const Epsilon epsilon = Epsilon();

class Choice extends RegularExpression {
  const Choice(this.left, this.right);

  final RegularExpression left;
  final RegularExpression right;

  @override
  Iterable<Letter> get prefixes sync* {
    yield* left.prefixes;
    yield* right.prefixes;
  }

  @override
  Iterable<Letter> get suffixes sync* {
    yield* left.suffixes;
    yield* right.suffixes;
  }

  @override
  Iterable<(Letter, Letter)> get pairs sync* {
    yield* left.pairs;
    yield* right.pairs;
  }

  @override
  Iterable<Letter> get letters sync* {
    yield* left.letters;
    yield* right.letters;
  }

  @override
  bool get isNullable => left.isNullable || right.isNullable;

  @override
  String toString() => "($left | $right)";

  @override
  (int, RegularExpression) _linearized(int start) {
    var (int start1, RegularExpression left) = this.left._linearized(start);
    var (int start2, RegularExpression right) = this.right._linearized(start1);

    return (start2, Choice(left, right));
  }
}

class Concatenation extends RegularExpression {
  const Concatenation(this.left, this.right);

  final RegularExpression left;
  final RegularExpression right;

  @override
  Iterable<Letter> get prefixes sync* {
    yield* left.prefixes;
    if (left.isNullable) {
      yield* right.prefixes;
    }
  }

  @override
  Iterable<Letter> get suffixes sync* {
    yield* right.suffixes;
    if (right.isNullable) {
      yield* left.suffixes;
    }
  }

  @override
  Iterable<(Letter, Letter)> get pairs sync* {
    yield* left.pairs;
    yield* right.pairs;
    for (Letter left in left.suffixes) {
      for (Letter right in right.prefixes) {
        yield (left, right);
      }
    }
  }

  @override
  Iterable<Letter> get letters sync* {
    yield* left.letters;
    yield* right.letters;
  }

  @override
  bool get isNullable => left.isNullable && right.isNullable;

  @override
  String toString() => "$left $right";

  @override
  (int, RegularExpression) _linearized(int start) {
    var (int start1, RegularExpression left) = this.left._linearized(start);
    var (int start2, RegularExpression right) = this.right._linearized(start1);

    return (start2, Concatenation(left, right));
  }
}

class Optional extends RegularExpression {
  const Optional(this.expression);

  final RegularExpression expression;

  @override
  Iterable<Letter> get prefixes => expression.prefixes;

  @override
  Iterable<Letter> get suffixes => expression.suffixes;

  @override
  Iterable<(Letter, Letter)> get pairs => expression.pairs;

  @override
  Iterable<Letter> get letters => expression.letters;

  @override
  bool get isNullable => true;

  @override
  String toString() => "${expression.toString().parenthesize}?";

  @override
  (int, RegularExpression) _linearized(int start) {
    var (int end, RegularExpression left) = expression._linearized(start);

    return (end, Optional(left));
  }
}

class KleeneStar extends RegularExpression {
  const KleeneStar(this.expression);

  final RegularExpression expression;

  @override
  Iterable<Letter> get prefixes => expression.prefixes;

  @override
  Iterable<Letter> get suffixes => expression.suffixes;

  @override
  Iterable<(Letter, Letter)> get pairs sync* {
    yield* expression.pairs;

    /// Since we can repeat ourselves, we can also pair the prefixes and suffixes of the expression.
    for (Letter suffix in expression.suffixes) {
      for (Letter prefix in expression.prefixes) {
        yield (suffix, prefix);
      }
    }
  }

  @override
  Iterable<Letter> get letters sync* {
    yield* expression.letters;
  }

  @override
  bool get isNullable => true;

  @override
  String toString() => "${expression.toString().parenthesize}*";

  @override
  (int, RegularExpression) _linearized(int start) {
    var (int end, RegularExpression left) = expression._linearized(start);

    return (end, KleeneStar(left));
  }
}

class KleenePlus extends RegularExpression {
  const KleenePlus(this.expression);

  final RegularExpression expression;

  @override
  Iterable<Letter> get prefixes => expression.prefixes;

  @override
  Iterable<Letter> get suffixes => expression.suffixes;

  @override
  Iterable<(Letter, Letter)> get pairs sync* {
    yield* expression.pairs;

    /// Since we can repeat ourselves, we can also pair the prefixes and suffixes of the expression.
    for (Letter suffix in expression.suffixes) {
      for (Letter prefix in expression.prefixes) {
        yield (suffix, prefix);
      }
    }
  }

  @override
  Iterable<Letter> get letters sync* {
    yield* expression.letters;
  }

  @override
  bool get isNullable => expression.isNullable;

  @override
  String toString() => "${expression.toString().parenthesize}+";

  @override
  (int, RegularExpression) _linearized(int start) {
    var (int end, RegularExpression left) = expression._linearized(start);

    return (end, KleenePlus(left));
  }
}

extension RegularExpressionExtension on RegularExpression {
  RegularExpression operator |(RegularExpression other) => Choice(this, other);
  RegularExpression operator &(RegularExpression other) => Concatenation(this, other);
  RegularExpression get star => KleeneStar(this);
  RegularExpression get plus => KleenePlus(this);
  RegularExpression get optional => Optional(this);
}

extension StringExtension on String {
  Letter get r => Letter(this);
}

extension on String {
  String get parenthesize => switch (split("")) {
        ["(", ..., ")"] => this,
        _ => "($this)",
      };
}
