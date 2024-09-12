# Finite Automata Conversion

A command-line program that implements Finite Automata related
algorithms for the purpose of study. Specifically, it implements:
  - Regular Expression structure
  - Regular Expression to NFA Conversion Algorithm
  - NFA to DFA Conversion Algorithm
  - DFA Minimization Algorithm


---

## Example (Glushkov Construction):

#### I. Regular Expression
`e = (0 | 1)*001(0 | 1)*`
- A regular expression that recognizes any string composed of 0 and 1, with the substring 001.
- Formally, `L(e) = {B*001B* | B is 0 or 1}`

#### II. Glushkov Construction
- Through the program, the resulting automata is:
![NFA-SVG](https://raw.githubusercontent.com/water-mizuu/glushkov_construction/master/nfa.svg)

#### III. NFA to DFA Conversion
- This step also removes ε-transitions from the NFA.
- Through the program, the resulting DFA with renamed states is:
![DFA-SVG](https://raw.githubusercontent.com/water-mizuu/glushkov_construction/master/dfa.svg)

#### IV. DFA Minimization
- Through the program, the resulting DFA with renamed states is:
![DFA_M-SVG](https://raw.githubusercontent.com/water-mizuu/glushkov_construction/master/dfa_m.svg)
