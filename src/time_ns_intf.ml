open! Import
open! Import_time

module type Option = sig
  include Immediate_option.S_int63
  include Identifiable with type t := t
end

module type Span = sig
  type t = Core_kernel.Time_ns.Span.t [@@deriving typerep, sexp_of]

  include Identifiable         with type t := t
  include Comparable.With_zero with type t := t

  (** Similar to {!Time.Span.Parts}. *)
  module Parts : sig
    type t = private
      { sign : Sign.t
      ; hr   : int
      ; min  : int
      ; sec  : int
      ; ms   : int
      ; us   : int
      ; ns   : int
      }
    [@@deriving sexp]
  end

  val nanosecond  : t
  val microsecond : t
  val millisecond : t
  val second      : t
  val minute      : t
  val hour        : t
  val day         : t

  val of_ns  : float -> t
  val of_us  : float -> t
  val of_ms  : float -> t
  val of_sec : float -> t
  val of_min : float -> t
  val of_hr  : float -> t
  val of_day : float -> t
  val to_ns  : t     -> float
  val to_us  : t     -> float
  val to_ms  : t     -> float
  val to_sec : t     -> float
  val to_min : t     -> float
  val to_hr  : t     -> float
  val to_day : t     -> float

  val of_int_us  : int -> t
  val of_int_ms  : int -> t
  val of_int_sec : int -> t
  val to_int_us  : t -> int
  val to_int_ms  : t -> int
  val to_int_sec : t -> int

  val zero : t
  val min_value : t
  val max_value : t
  val ( + ) : t -> t -> t (** overflows silently *)

  val ( - ) : t -> t -> t (** overflows silently *)

  val abs : t -> t
  val neg : t -> t
  val scale     : t -> float -> t
  val scale_int : t -> int   -> t (** overflows silently *)

  val div : t -> t -> Int63.t
  val ( / ) : t -> float -> t
  val ( // ) : t -> t -> float

  (** Overflows silently. *)
  val create
    :  ?sign : Sign.t
    -> ?day : int
    -> ?hr  : int
    -> ?min : int
    -> ?sec : int
    -> ?ms  : int
    -> ?us  : int
    -> ?ns  : int
    -> unit
    -> t

  val to_short_string : t -> string
  val randomize : t -> percent : Percent.t -> t

  val to_parts : t -> Parts.t

  val to_unit_of_time : t -> Unit_of_time.t
  val of_unit_of_time : Unit_of_time.t -> t

  (** See [Time.Span.to_string_hum]. *)
  val to_string_hum
    :  ?delimiter:char              (** defaults to ['_'] *)
    -> ?decimals:int                (** defaults to 3 *)
    -> ?align_decimal:bool          (** defaults to [false] *)
    -> ?unit_of_time:Unit_of_time.t (** defaults to [to_unit_of_time t] *)
    -> t
    -> string

  (** See [Core_kernel.Time_ns.Span]. *)
  val to_span : t -> Time.Span.t
  val of_span : Time.Span.t -> t

  include Robustly_comparable with type t := t

  val to_int63_ns : t -> Int63.t (** Fast, implemented as the identity function. *)

  val of_int63_ns : Int63.t -> t (** Somewhat fast, implemented as a range check. *)

  (** Will raise on 32-bit platforms with spans corresponding to contemporary {!now}.
      Consider [to_int63_ns] instead. *)
  val to_int_ns : t   -> int
  val of_int_ns : int -> t

  (** The only condition [to_proportional_float] is supposed to satisfy is that for all
      [t1, t2 : t]: [to_proportional_float t1 /. to_proportional_float t2 = t1 // t2]. *)
  val to_proportional_float : t -> float

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving hash]
      include Stable_int63able with type t := t
    end
    module V2 : sig
      type nonrec t = t [@@deriving hash]
      include Stable_int63able with type t := t
    end
  end

  val random : ?state:Random.State.t -> unit -> t

  (** [Span.Option.t] is like [Span.t option], except that the value is immediate on
      architectures where [Int63.t] is immediate.  This module should mainly be used to
      avoid allocations. *)
  module Option : sig
    include Option with type value := t
    module Stable : sig
      module V1 : Stable_int63able with type t = t
      module V2 : Stable_int63able with type t = t
    end
  end
end

module type Ofday = sig
  include module type of struct include Time_ns.Ofday end

  val now : zone:Time.Zone.t -> t

  val to_ofday : t -> Time.Ofday.t
  val of_ofday : Time.Ofday.t -> t

  module Zoned : sig
    (** Sexps look like "(12:01 nyc)"

        Two [t]'s may or may not correspond to the same times depending on which date
        they're evaluated. *)
    type t [@@deriving bin_io, sexp, hash]

    include Pretty_printer.S with type t := t
    include Stringable       with type t := t (** Strings look like "12:01 nyc" *)

    val create       : Time_ns.Ofday.t -> Time.Zone.t -> t
    val create_local : Time_ns.Ofday.t                -> t

    val ofday : t -> Time_ns.Ofday.t
    val zone  : t -> Time.Zone.t

    val to_time_ns : t -> Date.t -> Time_ns.t

    module With_nonchronological_compare : sig
      (** It is possible to consistently compare [t]'s, but due to the complexities of
          time zones and daylight savings, the resulting ordering is not chronological.
          That is, [compare t1 t2 > 0] does not imply [t2] occurs after [t1] every day,
          or any day. *)
      type nonrec t = t [@@deriving bin_io, sexp, compare, hash]
    end
  end

  module Option : sig
    include Option with type value := t
    module Stable : sig
      module V1 : Stable_int63able with type t = t
    end
  end
end

(** An absolute point in time, more efficient and precise than the [float]-based {!Time},
    but representing a narrower range of times.

    This module represents absolute times with nanosecond precision, approximately between
    the years 1823 and 2116 CE.

    You should normally default to using [Time] instead of this module!  The reasons are:

    - Many functions around our libraries expect [Time.t] values, so it will likely be
      much more convenient for you.

    - It leads to greater consistency across different codebases.  It would be bad to end
      up with half our libraries expecting [Time.t] and the other half expecting
      [Time_ns.t].

    - [Time_ns] silently ignores overflow.

    Some reasons you might want want to actually prefer [Time_ns.t] in certain cases:

    - It has superior performance.

    - It uses [int]s rather than [float]s internally, which makes certain things easier to
      reason about, since [int]s respect a bunch of arithmetic identities that [float]s
      don't, e.g., [x + (y + z) = (x + y) + z].


    - It is available on non-UNIX platforms, including Javascript via js_of_ocaml.

    All in all, it would have been nice to have chosen [Time_ns.t] to begin with, but
    we're unlikely to flip everything to [Time_ns.t] in the short term (see comment at the
    end of [time_ns.ml]).

    See {!Core_kernel.Time_ns} for additional low level documentation. *)
module type Time_ns = sig

  type t = Core_kernel.Time_ns.t [@@deriving typerep]

  module Span : Span

  (** [Option.t] is like [t option], except that the value is immediate.  This module
      should mainly be used to avoid allocations. *)
  module Option : sig
    include Option with type value := t
    module Stable : sig
      module V1 : Stable_int63able with type t = t
    end
  end

  (** See {!Time.Ofday}. *)
  module Ofday : Ofday





  include Identifiable with type t := t

  module Zone : module type of Time.Zone with type t = Time.Zone.t

  val epoch : t (** Unix epoch (1970-01-01 00:00:00 UTC) *)

  val min_value : t
  val max_value : t

  val now : unit -> t

  val add      : t -> Span.t -> t (** overflows silently *)

  val sub      : t -> Span.t -> t (** overflows silently *)

  val diff     : t -> t -> Span.t (** overflows silently *)

  val abs_diff : t -> t -> Span.t (** overflows silently *)

  val to_span_since_epoch : t -> Span.t
  val of_span_since_epoch : Span.t -> t

  val to_time : t -> Time.t
  val of_time : Time.t -> t (** not injective (rounds to nearest microsecond) *)

  val to_string_fix_proto : [ `Utc | `Local ] -> t -> string
  val of_string_fix_proto : [ `Utc | `Local ] -> string -> t

  (** See [Time] for documentation. *)
  val to_string_abs : t -> zone:Time.Zone.t -> string
  val of_string_abs : string -> t
  val to_sec_string : t -> zone:Zone.t -> string

  val to_int63_ns_since_epoch : t -> Int63.t
  val of_int63_ns_since_epoch : Int63.t -> t

  (** Will raise on 32-bit platforms.  Consider [to_int63_ns_since_epoch] instead. *)
  val to_int_ns_since_epoch : t -> int
  val of_int_ns_since_epoch : int -> t

  (** See [Time] for documentation *)
  val to_filename_string : t      -> zone:Zone.t -> string
  val of_filename_string : string -> zone:Zone.t -> t

  (** See [Core_kernel.Time_ns].

      Overflows silently. *)
  val next_multiple
    :  ?can_equal_after:bool  (** default is [false] *)
    -> base:t
    -> after:t
    -> interval:Span.t
    -> unit
    -> t

  val of_date_ofday : zone:Zone.t -> Date.t -> Ofday.t -> t
  val to_ofday : t -> zone:Zone.t -> Ofday.t
  val to_date  : t -> zone:Zone.t -> Date.t
  val to_date_ofday: t -> zone:Zone.t -> Date.t * Ofday.t
  val occurrence
    :  [ `First_after_or_at | `Last_before_or_at ]
    -> t
    -> ofday:Ofday.t
    -> zone:Time.Zone.t
    -> t

  (** [pause span] sleeps for [span] time. *)
  val pause : Span.t -> unit

  (** [interruptible_pause span] sleeps for [span] time unless interrupted (e.g. by
      delivery of a signal), in which case the remaining unslept portion of time is
      returned. *)
  val interruptible_pause : Span.t -> [ `Ok | `Remaining of Span.t ]

  (** [pause_forever] sleeps indefinitely. *)
  val pause_forever : unit -> never_returns

  module Stable : sig
    module V1 : Stable_int63able with type t = t
    module Option : sig
      module V1 : Stable_int63able with type t = Option.t
    end
    module Span : sig
      module V1 : sig
        type t = Span.t [@@deriving hash]
        include Stable_int63able with type t := t
      end
      module V2 : sig
        type t = Span.t [@@deriving hash]
        include Stable_int63able with type t := t
      end
      module Option : sig
        module V1 : Stable_int63able with type t = Span.Option.t
        module V2 : Stable_int63able with type t = Span.Option.t
      end
    end
    module Ofday : sig
      module V1 : Stable_int63able with type t = Ofday.t
      module Zoned : sig
        module V1 : sig
          type nonrec t = Ofday.Zoned.t [@@deriving hash]
          include Stable_without_comparator with type t := t
        end
      end
      module Option : sig
        module V1 : Stable_int63able with type t = Ofday.Option.t
      end
    end
  end

  val random : ?state:Random.State.t -> unit -> t

end
