# Glushkov Construction Algorithm

A command-line program that implements Finite Automata related
algorithms for the purpose of study. Specifically, it implements:
  1. Glushkov Construction Algorithm (Regular Expression to NFA)
  2. NFA to DFA Conversion Algorithm
  3. DFA Minimization Algorithm


---

## Example:

#### I. Regular Expression
`e = (0 | 1)*001(0 | 1)*`
- A regular expression that recognizes any string composed of 0 and 1, with the substring 001.
- Formally, `L(e) = {B*001B* | B is 0 or 1}`

#### 2. Glushkov Construction
- Through the program, the resulting automata is:
![NFA-SVG](https://raw.githubusercontent.com/water-mizuu/glushkov_construction/master/nfa.svg)

### 3. NFA to DFA Conversion
- Through the program, the resulting DFA with renamed states is:
![DFA-SVG](https://raw.githubusercontent.com/water-mizuu/glushkov_construction/master/dfa.svg)

### 4. DFA Minimization
- Through the program, the resulting DFA with renamed states is:
![DFA_M-SVG](https://raw.githubusercontent.com/water-mizuu/glushkov_construction/master/dfa_m.svg)