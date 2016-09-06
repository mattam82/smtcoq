# SMTCoq

SMTCoq is a Coq tool that checks proof witnesses coming from external
SAT and SMT solvers.

It relies on a certified checker for such witnesses. On top of it,
vernacular commands and tactics to interface with the SAT solver zChaff
and the SMT solvers veriT and CVC4 are provided. It is designed in a modular way
allowing to extend it easily to other solvers.

SMTCoq also provides an extracted version of the checker, that can be
run outside Coq.

The current stable version is version 1.3.


### Installation

See the INSTALL.md file for instructions.


### License

SMTCoq is released under the CeCILL-C license; see LICENSE for more
details.


### Use

Examples are given in the file examples/Example.v. They are meant to be
easily re-usable for your own usage.


#### Overview

The SMTCoq module can be used in Coq files via the `Require Import
SMTCoq.` command. For each supported solver, it provides:

- a vernacular command to check answers:
  `XXX_Checker "problem_file" "witness_file"` returns `true` only if
  `witness_file` contains a zChaff proof of the unsatisfiability of the
  problem stated in `problem_file`;

- a vernacular command to safely import theorems:
  `XXX_Theorem theo "problem_file" "witness_file"` produces a Coq term
  `teo` whose type is the theorem stated in `problem_file` if
  `witness_file` is a proof of the unsatisfiability of it, and fails
  otherwise.

- a safe tactic to try to solve a Coq goal using the chosen solver.

The SMTCoq checker can also be extracted to OCaml and then used
independently from Coq.

We now give more details for each solver, and explanations on
extraction.


#### zChaff

Compile and install zChaff as explained in the installation
instructions. In the following, we consider that the command `zchaff` is
in your `PATH` variable environment.


##### Checking zChaff answers of unsatisfiability and importing theorems

To check the result given by zChaff on an unsatisfiable dimacs file
`file.cnf`:

- Produce a zChaff proof witness: `zchaff file.cnf`. This command
  produces a proof witness file named `resolve_trace`.

- In a Coq file `file.v`, put:
```
Require Import SMTCoq.
Zchaff_Checker "file.cnf" "resolve_trace".
```

- Compile `file.v`: `coqc file.v`. If it returns `true` then zChaff
  indeed proved that the problem was unsatisfiable.

- You can also produce Coq theorems from zChaff proof witnesses: the
  commands
```
Require Import SMTCoq.
Zchaff_Theorem theo "file.cnf" "resolve_trace".
```
will produce a Coq term `theo` whose type is the theorem stated in
`file.cnf`.


##### zChaff as a Coq decision procedure

The `zchaff` tactic can be used to solve any goal of the form:
```
forall l, b1 = b2
```
where `l` is a list of Booleans (that can be concrete terms).


#### veriT

Compile and install veriT as explained in the installation instructions.
In the following, we consider that the command `veriT` is in your `PATH`
variable environment.


##### Checking veriT answers of unsatisfiability and importing theorems

To check the result given by veriT on an unsatisfiable SMT-LIB2 file
`file.smt2`:

- Produce a veriT proof witness:
```
veriT --proof-prune --proof-merge --proof-with-sharing --cnf-definitional --disable-e --disable-ackermann --input=smtlib2 --proof=file.log file.smt2
```
This command produces a proof witness file named `file.log`.

- In a Coq file `file.v`, put:
```
Require Import SMTCoq.
Section File.
  Verit_Checker "file.smt2" "file.log".
End File.
```

- Compile `file.v`: `coqc file.v`. If it returns `true` then veriT
  indeed proved that the problem was unsatisfiable.

- You can also produce Coq theorems from zChaff proof witnesses: the
  commands
```
Require Import SMTCoq.
Section File.
  Verit_Theorem theo "file.smt2" "file.log".
End File.
```
will produce a Coq term `theo` whose type is the theorem stated in
`file.smt2`.

The theories that are currently supported are `QF_UF`, `QF_LIA`,
`QF_IDL` and their combinations.


##### veriT as a Coq decision procedure

The `verit` tactic can be used to solve any goal of the form:
```
forall l, b1 = b2
```
where `l` is a list of Booleans. Those Booleans can be any concrete
terms. The theories that are currently supported are `QF_UF`, `QF_LIA`,
`QF_IDL` and their combinations.

#### CVC4

Compile and install `CVC4` as explained in the installation instructions.

##### Checking CVC4 answers of unsatisfiability and importing theorems

To check the result given by CVC4 on an unsatisfiable SMT-LIB2 file
`name.smt2` (in `..smtcoq/src/lfsc/tests` directory):

- Produce a CVC4 proof witness; run 1, 2 and 3 in a row:

```
1. DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
2. cvc4 --dump-proof --no-simplification --fewer-preprocessing-holes --no-bv-eq --no-bv-ineq --no-bv-algebraic name.smt2 > name.tmp.lfsc
3. cat $DIR/signatures/{sat,smt,th_base,th_int,th_bv,th_bv_bitblast,th_bv_rewrites,th_arrays}.plf name.tmp.lfsc > name.lfsc
```

This set of commands produces a proof witness file named `name.lfsc`.

- In a Coq file `name.v`, put:
```
Require Import SMTCoq Bool List.
Import ListNotations BVList.BITVECTOR_LIST FArray.
Local Open Scope list_scope.
Local Open Scope farray_scope.
Local Open Scope bv_scope.

Section File.
  Lfsc_Checker "name.smt2" "name.lfsc".
End File.
```

- Compile `name.v`: `coqc name.v`. If it returns `true` then CVC4 indeed proved that the problem was unsatisfiable.

NB: Use `cvc4tocoq` script in `..smtcoq/src/lfsc/tests` to automatize above steps.

- Ex: `./cvc4tocoq name.smt2`, similary returned `true` amounts to correct unsatisfiability proof of the problem by CVC4.

##### CVC4 as a Coq decision procedure

The `cvc4` tactic can be used to solve any goal of the form:
```
forall l, b1 = b2
```
where `l` is a list of Booleans. Those Booleans can be any concrete
terms. The theories that are currently supported are `QF_UF`, `QF_LIA`,
`QF_IDL`, `QF_BV`, `QF_A` and their combinations.

