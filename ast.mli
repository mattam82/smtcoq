type mpz = Big_int.big_int
type mpq = Num.num


type name = Name of string | S_Hole
type symbol = { sname : name; stype : term }

and dterm =
  | Type
  | Kind
  | Mpz
  | Mpq
  | App of symbol * term list
  | Int of mpz
  | Rat of mpq
  | Pi of symbol * term
  | Lambda of symbol * term
  | Hole

and term = { tname: dterm; ttype: term }

type command =
  | Check of term
  | Define of string * term
  | Declare of string * term


type proof = command list


exception TypingError of term * term

val lfsc_type : term

val kind : term

val mpz : term

val mpq : term

val mk_mpz : mpz -> term

val mk_mpq : mpq -> term

val unify : term -> term -> unit

val mk_symbol : string -> term -> symbol

val mk_symbol_hole : term -> symbol

val mk_app : string -> term list -> term

(* val mk_hole : term -> term *)

val mk_hole_hole : unit -> term

val mk_pi : symbol -> term -> term

val mk_lambda : symbol -> term -> term

val mk_ascr : term -> term -> term


val print_term : Format.formatter -> term -> unit
  
val print_command : Format.formatter -> command -> unit

val print_proof : Format.formatter -> proof -> unit


val mk_declare : string -> term -> unit

val mk_check : term -> unit

val mk_command : command -> unit

val mk_proof : proof -> unit

val register_symbol : symbol -> unit

val remove_symbol : symbol -> unit
