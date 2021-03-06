(* Copyright (C) 2015, Thomas Leonard
 * See the README file for details. *)

open React    (* Provides [S] for signals (and [E] for events) *)
open Semantic_ui

(* Each module provides a [sig] block describing its public interface and a [struct]
   with its implementation. The [sig] blocks are optional, but make it easier to see
   a module's API quickly. In a larger program, you would put each module in a separate
   file.
   e.g. the contents of [Time]'s sig block would go in `time.mli` and the contents of
   its struct block in `time.ml`. *)

module Time : sig
  (** A helper module to provide the current time as a reactive signal. *)

  val current : float S.t   (** The current time, updated each second *)
end = struct
  open Lwt.Infix            (* Provides >>=, the "bind" / "and_then" operator *)

  let current, set_current = S.create (Unix.gettimeofday ())

  let () =
    (* Update [current] every second *)
    let rec loop () =
      Lwt_js.sleep 1.0 >>= fun () ->
      set_current (Unix.gettimeofday ());
      loop () in
    Lwt.async loop
end

module Model : sig
  (** The core application logic. *)

  val time : string S.t  (** The output value to display on the screen *)
  val state: string S.t
  val action: string S.t
  val start : unit -> unit
  val stop : unit -> unit
end = struct
  let state, set_state = S.create `Clear

  let start () =
    set_state (`Running_since (S.value Time.current))

  let stop () =
    set_state (
      match S.value state with
      | `Running_since start -> `Stopped_showing (S.value Time.current -. start)
      | `Stopped_showing _ | `Clear -> `Clear
    )

  (* [calc time state] returns the string to display for a given time and state.
     Note: it works on regular values, not signals. *)
  let time_t time = function
    | `Running_since start -> Printf.sprintf "%.0f" (time -. start)
    | `Stopped_showing x   -> Printf.sprintf "%.0f" x
    | `Clear               -> "0"

  let state_t = function
    | `Running_since _   -> "Started"
    | `Stopped_showing _ -> "Stopped"
    | `Clear             -> "Ready"

  let action_t = function
    | `Running_since _
    | `Stopped_showing _ -> "Reset"
    | `Clear             -> "Start"

  let time =
    (* [S.l2 calc] lifts the 2-argument function [calc] to work on 2 signals.
       [calc] will be called when either input changes. *)
    S.l2 time_t Time.current state

  let action = S.l1 action_t state
  let state = S.l1 state_t state
end

module Templates : sig
  (** Render the model using HTML elements. *)

  val main :  Html_types.div Tyxml_js.Html5.elt
  (** The <div> element for the app. *)
end = struct
  module R = Tyxml_js.R.Html5   (* Reactive elements, using signals *)
  open Tyxml_js.Html5           (* Ordinary, non-reactive HTML elements *)

  (* An "onclick" attribute that calls [fn] and returns [true],
   * ignoring the event object. *)
  let onclick fn = (fun _ev -> fn (); true)

  let main =
    Container.v ~align:[`Center] [
      Divider.v;
      Statistic.v ~value:[R.pcdata Model.time] ~label:[pcdata "seconds"];
      Divider.horizontal (R.pcdata Model.state);
      Button.v ~kind:`Primary (onclick Model.start) [
        Icon.v `Users;
        R.pcdata Model.action
      ];
      Button.v (onclick Model.stop) [
        Icon.v `Pause;
        pcdata "Stop";
      ];
    ]
end

(* Initialisation code, called at start-up. *)
let () =
  (* Add [Templates.main] to the <body>. *)
  let main_div = Tyxml_js.To_dom.of_node Templates.main in
  Dom_html.document##body##appendChild(main_div) |> ignore
