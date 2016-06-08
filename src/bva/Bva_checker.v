(**************************************************************************)
(*                                                                        *)
(*     SMTCoq                                                             *)
(*     Copyright (C) 2011 - 2016                                          *)
(*                                                                        *)
(*     Chantal Keller                                                     *)
(*                                                                        *)
(*     Inria - École Polytechnique - Université Paris-Sud                 *)
(*                                                                        *)
(*   This file is distributed under the terms of the CeCILL-C licence     *)
(*                                                                        *)
(**************************************************************************)


(** A small checker for bit-vectors bit-blasting *)

Require Import Int63 PArray.
(*Add LoadPath "/home/burak/Desktop/smtcoq/src/bva".*)
Require Import Misc State SMT_terms BVList Psatz.
Require Import Bool List BoolEq NZParity.
Require Import BinPos BinNat Pnat.
Import ListNotations.
Import Form.

Local Open Scope array_scope.
Local Open Scope int63_scope.

Set Implicit Arguments.
Unset Strict Implicit.


Section Checker.

  Import Atom.

  Print atom.

  Variable t_atom : PArray.array atom.
  Variable t_form : PArray.array form.

  Local Notation get_form := (PArray.get t_form) (only parsing).
  Local Notation get_atom := (PArray.get t_atom) (only parsing).


  (* Bit-blasting a variable:

              x ∈ BV n
       ----------------------- bbVar
        bbT(x, [x₀; ...; xₙ₋₁])
   *)

  Fixpoint check_bb (a: int) (bs: list _lit) (i n: nat) :=
    match bs with
    | nil => Nat_eqb i n                     (* We go up to n *)
    | b::bs =>
      if Lit.is_pos b then
        match get_form (Lit.blit b) with
        | Fatom a' =>
          match get_atom a' with
          | Auop (UO_BVbitOf N p) a' =>
            (* TODO:
               Do not need to check [Nat_eqb l (N.to_nat N)] at every iteration *)
            if (a == a')                     (* We bit blast the right bv *)
                 && (Nat_eqb i p)            (* We consider bits after bits *)
                 && (Nat_eqb n (N.to_nat N)) (* The bv has indeed type BV n *)
            then check_bb a bs (S i) n
            else false
          | _ => false
          end
        | _ => false
        end
      else false
    end.               

  Definition check_bbVar lres :=
    if Lit.is_pos lres then
      match get_form (Lit.blit lres) with
      | FbbT a bs =>
        if check_bb a bs O (List.length bs)
        then lres::nil
        else C._true
      | _ => C._true
      end
    else C._true.

 Check check_bbVar.

  Variable s : S.t.


  (* Bit-blasting bitwise operations: bbAnd, bbOr, ...
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbAnd
             bbT(a&b, [a0 /\ b0; ...; an /\ bn])
   *)

  Definition get_and (f: form) :=
    match f with
    | Fand args => if PArray.length args == 2 then Some (args.[0], args.[1]) else None
    | _ => None
    end.

  Definition get_or (f: form) :=
    match f with
    | For args => if PArray.length args == 2 then Some (args.[0], args.[1]) else None
    | _ => None
    end.

  Definition get_xor (f: form) :=
    match f with
    | Fxor arg0 arg1 => Some (arg0, arg1)
    | _ => None
    end.


(*
  Definition get_not (f: form) :=
    match f with
    | Fnot arg => Some arg
    | _ => None
    end.
*)

  (* Check the validity of a *symmetric* operator *)
  Definition check_symop (bs1 bs2 bsres : list _lit) (get_op: form -> option (_lit * _lit)) :=
    match bs1, bs2, bsres with
    | nil, nil, nil => true
    | b1::bs1, b2::bs2, bres::bsres =>
      if Lit.is_pos bres then
        match get_op (get_form (Lit.blit bres)) with
        | Some (a1, a2) => ((a1 == b1) && (a2 == b2)) || ((a1 == b2) && (a2 == b1))
        | _ => false
        end
      else false
    | _, _, _ => false
    end.

Lemma get_and_none: forall (n: int), (forall a, t_form .[ Lit.blit n] <> Fand a) ->
(get_and (get_form (Lit.blit n))) = None.
Proof. intros n H.
       unfold get_and.
       case_eq (t_form .[ Lit.blit n]); try reflexivity.
       intros. contradict H0. apply H.
Qed.

Lemma get_and_some: forall (n: int), 
(forall a, PArray.length a == 2 -> t_form .[ Lit.blit n] = Fand a ->
 (get_and (get_form (Lit.blit n))) = Some (a .[ 0], a .[ 1])).
Proof. intros. rewrite H0. unfold get_and. now rewrite H. Qed.

Lemma check_symop_op_some: 
forall a0 b0 c0 la lb lc get_op,
let a := a0 :: la in
let b := b0 :: lb in
let c := c0 :: lc in
Lit.is_pos c0 -> get_op (get_form (Lit.blit c0)) = Some (a0, b0) -> 
check_symop a b c get_op = true.
Proof. intros. simpl.
       rewrite H.
       rewrite H0.
       cut (a0 == a0 = true).
       intros H1; rewrite H1.
       cut (b0 == b0 = true).
       intros H2; rewrite H2.
       simpl. reflexivity.
       now rewrite Lit.eqb_spec.
       now rewrite Lit.eqb_spec. 
Qed.

Lemma empty_false1: forall a b c get_op, a = [] -> c <> [] -> check_symop a b c get_op = false.
Proof. intro a.
       induction a as [ | a xs IHxs].
       - intros [ | ys IHys].
         + intros [ | zs IHzs].
           * intros. now contradict H0.
           * intros. simpl. reflexivity.
         + intros. simpl. reflexivity.
       - intros. contradict H. easy.
Qed.

Lemma empty_false2: forall a b c, b = [] -> c <> [] -> check_symop a b c get_and = false.
Proof. intro a.
       induction a as [ | a xs IHxs].
       - intros [ | ys IHys].
         + intros [ | zs IHzs].
           * intros. now contradict H0.
           * intros. simpl. reflexivity.
         + intros. simpl. reflexivity.
       - intros. rewrite H. simpl. reflexivity.
Qed.

Lemma empty_false3: forall a b c, c = [] -> a <> [] -> check_symop a b c get_and = false.
Proof. intro a.
       induction a as [ | a xs IHxs].
       - intros [ | ys IHys].
         + intros [ | zs IHzs].
           * intros. now contradict H0.
           * intros. simpl. reflexivity.
         + intros. simpl. reflexivity.
       - intros. rewrite H. simpl.
         case b; reflexivity.
Qed.

Lemma empty_false4: forall a b c, c = [] -> b <> [] -> check_symop a b c get_and = false.
Proof. intro a.
       induction a as [ | a xs IHxs].
       - intros [ | ys IHys].
         + intros [ | zs IHzs].
           * intros. now contradict H0.
           * intros. simpl. reflexivity.
         + intros. simpl. reflexivity.
       - intros. rewrite H. simpl.
         case b; reflexivity.
Qed.

  Fixpoint check_symopp (bs1 bs2 bsres : list _lit) (bvop: binop) :=
    match bs1, bs2, bsres with
    | nil, nil, nil => true
    | b1::bs1, b2::bs2, bres::bsres =>
      if Lit.is_pos bres then
        let ires := 
        match get_form (Lit.blit bres), bvop with
          | Fand args, BO_BVand n  =>
            if PArray.length args == 2 then
              let a1 := args.[0] in
              let a2 := args.[1] in
              ((a1 == b1) && (a2 == b2)) || ((a1 == b2) && (a2 == b1))
            else false

          | For args, BO_BVor n  =>
            if PArray.length args == 2 then
              let a1 := args.[0] in
              let a2 := args.[1] in
              ((a1 == b1) && (a2 == b2)) || ((a1 == b2) && (a2 == b1))
            else false

          | Fxor a1 a2, BO_BVxor n =>
              ((a1 == b1) && (a2 == b2)) || ((a1 == b2) && (a2 == b1))
                   
          | _, _ => false
        end in
        if ires then check_symopp bs1 bs2 bsres bvop
        else false
          
      else false
    | _, _, _ => false
    end.

  Lemma empty_list_length: forall {A: Type} (a: list A), (length a = 0)%nat <-> a = [].
  Proof. intros A a.
         induction a; split; intros; auto; contradict H; easy.
  Qed.
  (* TODO: check the first argument of BVand, BVor *)
  Definition check_bbOp pos1 pos2 lres :=
    match S.get s pos1, S.get s pos2 with
    | l1::nil, l2::nil =>
      if (Lit.is_pos l1) && (Lit.is_pos l2) && (Lit.is_pos lres) then
        match get_form (Lit.blit l1), get_form (Lit.blit l2), get_form (Lit.blit lres) with
        | FbbT a1 bs1, FbbT a2 bs2, FbbT a bsres =>
          match get_atom a with
          | Abop (BO_BVand _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symop bs1 bs2 bsres get_and)
            then lres::nil
            else C._true
          | Abop (BO_BVor _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symop bs1 bs2 bsres get_or)
            then lres::nil
            else C._true
          | Abop (BO_BVxor _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symop bs1 bs2 bsres get_xor)
            then lres::nil
            else C._true
    (*      | Abop (UO_BVneg _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symop bs1 bs2 bsres get_xor)
            then lres::nil
            else C._true
    *)
       | _ => C._true
          end
        | _, _, _ => C._true
        end
      else C._true
    | _, _ => C._true
    end.

  (* TODO: check the first argument of BVand, BVor *)
  Definition check_bbOpp pos1 pos2 lres n :=
    match S.get s pos1, S.get s pos2 with
    | l1::nil, l2::nil =>
      if (Lit.is_pos l1) && (Lit.is_pos l2) && (Lit.is_pos lres) then
        match get_form (Lit.blit l1), get_form (Lit.blit l2), get_form (Lit.blit lres) with
        | FbbT a1 bs1, FbbT a2 bs2, FbbT a bsres =>
          match get_atom a with
          | Abop (BO_BVand _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (@check_symopp bs1 bs2 bsres (BO_BVand n))
            then lres::nil
            else C._true
          | Abop (BO_BVor _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symopp bs1 bs2 bsres  (BO_BVor n))
            then lres::nil
            else C._true
          | Abop (BO_BVxor _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symopp bs1 bs2 bsres  (BO_BVxor n))
            then lres::nil
            else C._true
    (*      | Abop (UO_BVneg _) a1' a2' =>
            if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                 && (check_symop bs1 bs2 bsres get_xor)
            then lres::nil
            else C._true
    *)
       | _ => C._true
          end
        | _, _, _ => C._true
        end
      else C._true
    | _, _ => C._true
    end.


Lemma bbOp0: forall pos1 pos2 lres, S.get s pos1 = [] ->  check_bbOp pos1 pos2 lres = [Lit._true].
Proof. intros pos1 pos2 lres H0.
       unfold check_bbOp. rewrite H0.
       reflexivity.
Qed.

Lemma bbOp1: forall pos1 pos2 lres, S.get s pos2 = [] ->  check_bbOp pos1 pos2 lres = [Lit._true].
Proof. intros pos1 pos2 lres H0.
       unfold check_bbOp.
       case_eq (S.get s pos1). reflexivity.
       intros i l H1.
       induction l. 
       - now rewrite H0.
       - reflexivity.
Qed.

   (* Bit-blasting equality
        bbT(a, [a0; ...; an])      bbT(b, [b0; ...; bn])
       -------------------------------------------------- bbEq
         (a = b) <-> [(a0 <-> b0) /\ ... /\ (an <-> bn)]
   *)

  Definition get_iff f :=
    match f with
    | Fiff l1 l2 => Some (l1, l2)
    | _ => None
    end.

  Definition check_bbEq pos1 pos2 lres :=
    match S.get s pos1, S.get s pos2 with
    | l1::nil, l2::nil =>
      if (Lit.is_pos l1) && (Lit.is_pos l2) && (Lit.is_pos lres) then
        match get_form (Lit.blit l1), get_form (Lit.blit l2), get_form (Lit.blit lres) with
        | FbbT a1 bs1, FbbT a2 bs2, Fiff leq lbb =>
          match get_form (Lit.blit leq), get_form (Lit.blit lbb) with
          | Fatom a, Fand bsres | Fand bsres, Fatom a =>
            match get_atom a with
            | Abop (BO_eq (Typ.TBV _)) a1' a2' =>
              if (((a1 == a1') && (a2 == a2')) || ((a1 == a2') && (a2 == a1')))
                   && (check_symop bs1 bs2 (PArray.to_list bsres) get_iff)
              then lres::nil
              else C._true
            | _ => C._true
            end
          | _, _ => C._true
          end
        | _, _, _ => C._true
        end
      else C._true
    | _, _ => C._true
    end.

  Section Proof.

    Variables (t_i : array typ_eqb)
              (t_func : array (Atom.tval t_i))
              (ch_atom : Atom.check_atom t_atom)
              (ch_form : Form.check_form t_form)
              (wt_t_atom : Atom.wt t_i t_func t_atom).

    Local Notation check_atom :=
      (check_aux t_i t_func (get_type t_i t_func t_atom)).

    Local Notation interp_form_hatom :=
      (Atom.interp_form_hatom t_i t_func t_atom).

    Local Notation interp_form_hatom_bv :=
      (Atom.interp_form_hatom_bv t_i t_func t_atom).

    Local Notation rho :=
      (Form.interp_state_var interp_form_hatom interp_form_hatom_bv t_form).

    Hypothesis Hs : S.valid rho s.

    Local Notation t_interp := (t_interp t_i t_func t_atom).

    Local Notation interp_atom :=
      (interp_aux t_i t_func (get t_interp)).

    Let wf_t_atom : Atom.wf t_atom.
    Proof. destruct (Atom.check_atom_correct _ ch_atom); auto. Qed.

    Let def_t_atom : default t_atom = Atom.Acop Atom.CO_xH.
    Proof. destruct (Atom.check_atom_correct _ ch_atom); auto. Qed.

    Let def_t_form : default t_form = Form.Ftrue.
    Proof.
      destruct (Form.check_form_correct interp_form_hatom interp_form_hatom_bv _ ch_form) as [H _]; destruct H; auto.
    Qed.

    Let wf_t_form : Form.wf t_form.
    Proof.
      destruct (Form.check_form_correct interp_form_hatom interp_form_hatom_bv _ ch_form) as [H _]; destruct H; auto.
    Qed.

    Let wf_rho : Valuation.wf rho.
    Proof.
      destruct (Form.check_form_correct interp_form_hatom interp_form_hatom_bv _ ch_form); auto.
    Qed.

    (* Lemma lit_interp_true : Lit.interp rho Lit._true = true. *)
    (* Proof. *)
    (*   apply Lit.interp_true. *)
    (*   apply wf_rho. *)
    (* Qed. *)

     Let rho_interp : forall x : int, rho x = Form.interp interp_form_hatom interp_form_hatom_bv t_form (t_form.[ x]).
     Proof. intros x;apply wf_interp_form;trivial. Qed.

(*
Lemma prop_checkbb: forall (a: int) (bs: list _lit) (i n: nat),
                    (check_bb a bs i n = true) ->
                    (length bs = (n - i))%nat /\ 
                    (forall i0, (i0 < n )%nat ->
                    Lit.interp rho (nth i0 bs false) = 
                    BITVECTOR_LIST.bitOf i0 (interp_form_hatom_bv a (N.of_nat n))).
Proof.
Admitted.
*)

Lemma prop_checkbb': forall (a: int) (bs: list _lit),
                     (check_bb a bs 0 (length bs) = true) ->
                     (forall i0, (i0 < (length bs) )%nat ->
                     Lit.interp rho (nth i0 bs false) = 
                     (@BITVECTOR_LIST.bitOf (N.of_nat(length bs)) i0 
                     (interp_form_hatom_bv a (N.of_nat (length bs))))).
Proof. 
Admitted.

(*
  Lemma of_bits_bitOf: forall i l, (@BITVECTOR_LIST.bitOf (N.of_nat (length l)) i 
                                                          (BITVECTOR_LIST.of_bits l))
                                                           = nth i l (Lit.interp rho false).
  Proof.
  Admitted.
*)

Lemma bitOf_of_bits: forall l (a: BITVECTOR_LIST.bitvector (N.of_nat (length l))), 
                               (forall i, 
                               (i < (length l))%nat ->
                               nth i l (Lit.interp rho false) = 
                               (@BITVECTOR_LIST.bitOf (N.of_nat (length l)) i a))
                               ->
                               (BITVECTOR_LIST.bv_eq a (BITVECTOR_LIST.of_bits l)).
Proof. 
Admitted.

    Lemma valid_check_bbVar lres : C.valid rho (check_bbVar lres).
    Proof.
      unfold check_bbVar.
      case_eq (Lit.is_pos lres); intro Heq1; [ |now apply C.interp_true].
      case_eq (t_form .[ Lit.blit lres]); try (intros; now apply C.interp_true).
      intros a bs Heq0.
      case_eq (check_bb a bs 0 (Datatypes.length bs)); intro Heq2; [ |now apply C.interp_true].
      unfold C.valid. simpl. rewrite orb_false_r.
      unfold Lit.interp. rewrite Heq1.
      unfold Var.interp.
      rewrite wf_interp_form; trivial. rewrite Heq0. simpl.
      apply bitOf_of_bits. intros. rewrite map_nth.
      remember (@prop_checkbb' a bs Heq2 i).
      rewrite map_length in H.
      rewrite map_length.
      clear Heqe.
      now apply e in H.
    Qed.

    Lemma valid_check_bbOp pos1 pos2 lres : C.valid rho (check_bbOp pos1 pos2 lres).
    
    Proof.
      unfold check_bbOp.
      case_eq (S.get s pos1); [intros _|intros l1 [ |l] Heq1]; try now apply C.interp_true.
      case_eq (S.get s pos2); [intros _|intros l2 [ |l] Heq2]; try now apply C.interp_true.
      case_eq (Lit.is_pos l1); intro Heq3; simpl; try now apply C.interp_true.
      case_eq (Lit.is_pos l2); intro Heq4; simpl; try now apply C.interp_true.
      case_eq (Lit.is_pos lres); intro Heq5; simpl; try now apply C.interp_true.
      case_eq (t_form .[ Lit.blit l1]); try (intros; now apply C.interp_true). intros a1 bs1 Heq6.
      case_eq (t_form .[ Lit.blit l2]); try (intros; now apply C.interp_true). intros a2 bs2 Heq7.
      case_eq (t_form .[ Lit.blit lres]); try (intros; now apply C.interp_true). intros a bsres Heq8.
      case_eq (t_atom .[ a]); try (intros; now apply C.interp_true).
      intros [ | | | | | | |A|N|N|N|N|N|N] a1' a2' Heq9; try now apply C.interp_true.
      (* BVand *)
      - case_eq ((a1 == a1') && (a2 == a2') || (a1 == a2') && (a2 == a1')); simpl; intros Heq10; try (now apply C.interp_true).
        case_eq (check_symop bs1 bs2 bsres get_and); simpl; intros Heq11; try (now apply C.interp_true).
        unfold C.valid. simpl. rewrite orb_false_r.
        unfold Lit.interp. rewrite Heq5.
        unfold Var.interp.
        rewrite wf_interp_form; trivial. rewrite Heq8. simpl.
        unfold Atom.interp_form_hatom_bv at 2, Atom.interp_hatom.
        rewrite Atom.t_interp_wf; trivial.
        rewrite Heq9. simpl. unfold apply_binop.
        case_eq (t_interp .[ a1']). intros V1 v1 Heq21.
        case_eq (t_interp .[ a2']). intros V2 v2 Heq22.
        admit.
        (* rewrite Typ.neq_cast. case_eq (Typ.eqb V1 (Typ.TBV N)); simpl. *)
        (* We need to use well-typedness information *)
      (* BVor *)
      - admit.
      (* BVxor *)
      - admit.
    Admitted.

 Lemma eq_head: forall {A: Type} a b (l: list A), (a :: l) = (b :: l) <-> a = b.
 Proof. intros A a b l.
        induction l as [ | l xs IHxs].
        intros.
        split. intros. now inversion H.
         intros. now rewrite H.
         intros.
         split. intros. apply IHxs. now inversion H.
         intros; now rewrite H.
  Qed.

Axiom afold_left_and : forall a, 
      afold_left bool int true andb (Lit.interp rho) a = List.forallb (Lit.interp rho) (to_list a).

Lemma eqb_spec : forall x y, (x == y) = true <-> x = y.
Proof.
 split;auto using eqb_correct, eqb_complete.
Qed.

Lemma to_list_two: forall {A:Type} (a: PArray.array A), 
       PArray.length a = 2 -> (to_list a) = a .[0] :: a .[1] :: nil.
Proof. intros A a H.
       rewrite to_list_to_list_ntr. unfold to_list_ntr.
       rewrite H.
       cut (0 == 2 = false). intro H1.
       rewrite H1.
       unfold foldi_ntr. rewrite foldi_cont_lt; auto.
       auto.
Qed.

Lemma check_symopp_and: forall ibs1 ibs2 xbs1 ybs2 ibsres zbsres n,
      check_symopp (ibs1 :: xbs1) (ibs2 :: ybs2) (ibsres :: zbsres) (BO_BVand (N.of_nat n)) = true ->
      check_symopp xbs1 ybs2 zbsres (BO_BVand (N.of_nat (n - 1))) = true.
Proof. intros.
       induction n. simpl.
       simpl in H. 
       case (Lit.is_pos ibsres) in H.
       case (t_form .[ Lit.blit ibsres]) in H; try (contradict H; easy).
       case (PArray.length a == 2) in H.
       case ((a .[ 0] == ibs1) && (a .[ 1] == ibs2)
         || (a .[ 0] == ibs2) && (a .[ 1] == ibs1)) in H.
       exact H.
       now contradict H.
       now contradict H.
       now contradict H.
       simpl in H.
       case (Lit.is_pos ibsres) in H.
       case (t_form .[ Lit.blit ibsres]) in H; try (contradict H; easy).
       case (PArray.length a == 2) in H.       
       admit. (*****)
       now contradict H.
       now contradict H.
Admitted.

Lemma asd: forall bs1 bs2 bsres, 
  let n := length bsres in
  (length bs1 = n)%nat -> 
  (length bs2 = n)%nat -> 
  check_symopp bs1 bs2 bsres (BO_BVand (N.of_nat n)) = true ->
  (List.map (Lit.interp rho) bsres) = 
  (RAWBITVECTOR_LIST.map2 andb (List.map (Lit.interp rho) bs1) (List.map (Lit.interp rho) bs2)).
Proof. intro bs1.
         induction bs1 as [ | ibs1 xbs1 IHbs1].
         - intros. simpl in *. rewrite <- H0 in H.
           rewrite <- H in H0. unfold n in H0.
           symmetry in H0.
           rewrite empty_list_length in H0.
           unfold map. now rewrite H0.
         - intros [ | ibs2 ybs2].
           + intros.
             simpl in *. now contradict H1.
           + intros [ | ibsres zbsres ].
             * intros. simpl in *. now contradict H.
             * intros. simpl.
               specialize (IHbs1 ybs2 zbsres). 
               rewrite IHbs1. rewrite eq_head.
               unfold Lit.interp, Var.interp.
               case_eq (Lit.is_pos ibsres); intro Heq0.
               case_eq (Lit.is_pos ibs1); intro Heq1.
               case_eq (Lit.is_pos ibs2); intro Heq2.
               rewrite wf_interp_form; trivial.
               simpl in H1.
               rewrite Heq0 in H1.
               case_eq (t_form .[ Lit.blit ibsres]).
               try (intros i Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               intros. rewrite H2 in H1. simpl.
               rewrite afold_left_and.
 
                case_eq (PArray.length a == 2). intros. rewrite H3 in H1.
                rewrite eqb_spec in H3.
                apply to_list_two in H3.
             (*   apply length_to_list in H4. *)
                unfold forallb.
                rewrite H3.
                case_eq ((a .[ 0] == ibs1) && (a .[ 1] == ibs2)). intros H5.
                rewrite andb_true_iff in H5. destruct H5 as (H5 & H6).
                rewrite eqb_spec in H5, H6. rewrite H5, H6.
                unfold Lit.interp.
                rewrite Heq1, Heq2.
                unfold Var.interp. now rewrite andb_true_r.
                intros. rewrite H4 in H1. simpl in *.
                case_eq ((a .[ 0] == ibs2) && (a .[ 1] == ibs1)).
                intros H5.
                rewrite andb_true_iff in H5. destruct H5 as (H5 & H6).
                rewrite eqb_spec in H5, H6.
                rewrite H5, H6. rewrite andb_true_r.
                unfold Lit.interp.
                rewrite Heq1, Heq2.
                unfold Var.interp. now rewrite andb_comm.
                intros. rewrite H5 in H1. now contradict H1.
                intros. rewrite H3 in H1. now contradict H1.
              
              try (intros a Heq; rewrite Heq in H1; now contradict H1).
              try (intros a Heq; rewrite Heq in H1; now contradict H1).
              try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
              try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
              try (intros i i0 i1 Heq; rewrite Heq in H1; now contradict H1).
              try (intros i l Heq; rewrite Heq in H1; now contradict H1).

              rewrite wf_interp_form; trivial. simpl in H1.
              case_eq (t_form .[ Lit.blit ibsres]).
              rewrite Heq0 in H1.
              case_eq (t_form .[ Lit.blit ibsres]).
               try (intros i Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               rewrite Heq0 in H1.
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros a Heq; rewrite Heq in H1; now contradict H1).
               intros. rewrite H2 in H1. simpl.
               rewrite afold_left_and.

                case_eq (PArray.length a == 2). intros. rewrite H3 in H1.
                rewrite eqb_spec in H3.
                apply to_list_two in H3.
             (*   apply length_to_list in H3. *)
                unfold forallb.
                rewrite H3.
                case_eq ((a .[ 0] == ibs1) && (a .[ 1] == ibs2)). intros H5.
                rewrite andb_true_iff in H5. destruct H5 as (H5 & H6).
                rewrite eqb_spec in H5, H6. rewrite H5, H6.
                unfold Lit.interp.
                rewrite Heq1, Heq2.
                unfold Var.interp. now rewrite andb_true_r.
                intros H4. rewrite H4 in H1. simpl in *.
                case_eq ((a .[ 0] == ibs2) && (a .[ 1] == ibs1)). intros H5.
                rewrite andb_true_iff in H5. destruct H5 as (H6 & H7).
                rewrite eqb_spec in H6, H7.
                rewrite H6, H7. rewrite andb_true_r.
                unfold Lit.interp.
                rewrite Heq1, Heq2.
                unfold Var.interp. now rewrite andb_comm.
                intros. rewrite H5 in H1. now contradict H1.
                intros. rewrite H3 in H1. now contradict H1.

               rewrite Heq0 in H1.
               try (intros a Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros a Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i i0 i1 Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i l Heq; rewrite Heq in H1; now contradict H1).

               case_eq (Lit.is_pos ibs2).
               intro Heq2.

              rewrite wf_interp_form; trivial. simpl in H1.
              case_eq (t_form .[ Lit.blit ibsres]).
              rewrite Heq0 in H1.
              case_eq (t_form .[ Lit.blit ibsres]).
               try (intros i Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               rewrite Heq0 in H1.
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros a Heq; rewrite Heq in H1; now contradict H1).
               intros. rewrite H2 in H1. simpl.
               rewrite afold_left_and.
                
                case_eq (PArray.length a == 2). intros. rewrite H3 in H1.
                rewrite eqb_spec in H3.
                apply to_list_two in H3.
             (*   apply length_to_list in H3. *)
                unfold forallb.
                rewrite H3.
                case_eq ((a .[ 0] == ibs1) && (a .[ 1] == ibs2)). intros H5.
                rewrite andb_true_iff in H5. destruct H5 as (H5 & H6).
                rewrite eqb_spec in H5, H6. rewrite H5, H6.
                unfold Lit.interp.
                rewrite Heq1, Heq2.
                unfold Var.interp. now rewrite andb_true_r.
                intros. rewrite H4 in H1. simpl in *.
                case_eq ((a .[ 0] == ibs2) && (a .[ 1] == ibs1)). intros H5.
                rewrite andb_true_iff in H5. destruct H5 as (H6 & H7).
                rewrite eqb_spec in H6, H7.
                rewrite H6, H7. rewrite andb_true_r.
                unfold Lit.interp.
                rewrite Heq1, Heq2.
                unfold Var.interp. now rewrite andb_comm.
                intros. rewrite H5 in H1. now contradict H1.
                intros. rewrite H3 in H1. now contradict H1.
              
              rewrite Heq0 in H1.
              try (intros a Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros a Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i i0 i1 Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i l Heq; rewrite Heq in H1; now contradict H1).
              
              intros.

              rewrite wf_interp_form; trivial. simpl in H1.
              case_eq (t_form .[ Lit.blit ibsres]).
              rewrite Heq0 in H1.
              case_eq (t_form .[ Lit.blit ibsres]).
               try (intros i Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               intros. contradict H3. discriminate.
               rewrite Heq0 in H1.
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
               rewrite Heq0 in H1.
               try (intros a Heq; rewrite Heq in H1; now contradict H1).
               intros. rewrite H3 in H1. simpl.
               rewrite afold_left_and.

               case_eq (PArray.length a == 2). intros H5.
                rewrite H5 in H1.
                rewrite eqb_spec in H5.
                apply to_list_two in H5.
             (*   apply length_to_list in H3. *)
                unfold forallb.
                rewrite H5.
                case_eq ((a .[ 0] == ibs1) && (a .[ 1] == ibs2)). intros H6.
                rewrite andb_true_iff in H6. destruct H6 as (H6 & H7).
                rewrite eqb_spec in H6, H7. rewrite H6, H7.
                unfold Lit.interp.
                rewrite Heq1, H2.
                unfold Var.interp. now rewrite andb_true_r.
                intros H6. rewrite H6 in H1. simpl in *.
                case_eq ((a .[ 0] == ibs2) && (a .[ 1] == ibs1)). intros H7.
                rewrite andb_true_iff in H7. destruct H7 as (H7 & H8).
                rewrite eqb_spec in H7, H8.
                rewrite H7, H8. rewrite andb_true_r.
                unfold Lit.interp.
                rewrite Heq1, H2.
                unfold Var.interp. now rewrite andb_comm.
                intros. rewrite H4 in H1. now contradict H1.
                intros. rewrite H4 in H1. now contradict H1.
            

              rewrite Heq0 in H1.
              try (intros a Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros a Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i i0 Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i i0 i1 Heq; rewrite Heq in H1; now contradict H1).
              rewrite Heq0 in H1.
              try (intros i l Heq; rewrite Heq in H1; now contradict H1).

              rewrite wf_interp_form; trivial. simpl in H1.
              rewrite Heq0 in H1. now contradict H1.
              now inversion H.
              now inversion H0.
              remember (@check_symopp_and ibs1 ibs2 xbs1 ybs2 ibsres zbsres).
              cut ((length zbsres = (n - 1))%nat). intros. rewrite H2.
              apply (@check_symopp_and ibs1 ibs2 xbs1 ybs2 ibsres zbsres).
              exact H1.
              unfold n. simpl. omega.
Qed.  
 
   Lemma valid_check_bbOpp pos1 pos2 lres n: C.valid rho (check_bbOpp pos1 pos2 lres n).
    Proof.
      unfold check_bbOpp.
      case_eq (S.get s pos1); [intros _|intros l1 [ |l] Heq1]; try now apply C.interp_true.
      case_eq (S.get s pos2); [intros _|intros l2 [ |l] Heq2]; try now apply C.interp_true.
      case_eq (Lit.is_pos l1); intro Heq3; simpl; try now apply C.interp_true.
      case_eq (Lit.is_pos l2); intro Heq4; simpl; try now apply C.interp_true.
      case_eq (Lit.is_pos lres); intro Heq5; simpl; try now apply C.interp_true.
      case_eq (t_form .[ Lit.blit l1]); try (intros; now apply C.interp_true). intros a1 bs1 Heq6.
      case_eq (t_form .[ Lit.blit l2]); try (intros; now apply C.interp_true). intros a2 bs2 Heq7.
      case_eq (t_form .[ Lit.blit lres]); try (intros; now apply C.interp_true).
      intros a bsres Heq8.
      case_eq (t_atom .[ a]); try (intros; now apply C.interp_true).
      intros [ | | | | | | |A|N|N|N|N|N|N] a1' a2' Heq9; try now apply C.interp_true.
      (* BVand *)
      - case_eq ((a1 == a1') && (a2 == a2') || (a1 == a2') && (a2 == a1')); simpl; intros Heq10; try (now apply C.interp_true).
        case_eq (check_symopp bs1 bs2 bsres (BO_BVand n)); simpl; intros Heq11; try (now apply C.interp_true).
        unfold C.valid. simpl. rewrite orb_false_r.
        unfold Lit.interp. rewrite Heq5.
        unfold Var.interp.
        rewrite wf_interp_form; trivial. rewrite Heq8. simpl.
        unfold Atom.interp_form_hatom_bv at 2, Atom.interp_hatom.
        rewrite Atom.t_interp_wf; trivial.
        rewrite Heq9. simpl. unfold apply_binop.
        case_eq (t_interp .[ a1']). intros V1 v1 Heq21.
        case_eq (t_interp .[ a2']). intros V2 v2 Heq22.
        admit.
        (* rewrite Typ.neq_cast. case_eq (Typ.eqb V1 (Typ.TBV N)); simpl. *)
        (* We need to use well-typedness information *)
      (* BVor *)
      - admit.
      (* BVxor *)
      - admit.
    Admitted.

    Lemma valid_check_bbEq pos1 pos2 lres : C.valid rho (check_bbEq pos1 pos2 lres).
    Admitted.

  End Proof.

End Checker.
