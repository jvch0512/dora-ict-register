(* dora-ict-register: audit of a DORA register of information (CSV) *)
structure Dora = struct

type finding = {sev: string, rule: string, file: string, line: int, msg: string}

fun rank "critical" = 0
  | rank "high" = 1
  | rank "medium" = 2
  | rank "low" = 3
  | rank _ = 4

fun lower s = String.map Char.toLower s
fun trim s = Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full s)))

fun mk sev rule file line msg : finding = {sev = sev, rule = rule, file = file, line = line, msg = msg}

(* split one CSV line, honouring double quotes *)
fun splitCsv (line : string) : string list =
  let
    fun go [] cur q acc = rev (String.implode (rev cur) :: acc)
      | go (c :: cs) cur true acc =
          if c = #"\"" then
            (case cs of
               #"\"" :: rest => go rest (#"\"" :: cur) true acc
             | _ => go cs cur false acc)
          else go cs (c :: cur) true acc
      | go (c :: cs) cur false acc =
          if c = #"\"" then go cs cur true acc
          else if c = #"," then go cs [] false (String.implode (rev cur) :: acc)
          else go cs (c :: cur) false acc
  in go (String.explode line) [] false [] end

fun splitLines (text : string) : string list =
  let
    val t = String.translate (fn #"\r" => "" | c => String.str c) text
  in String.fields (fn c => c = #"\n") t end

(* days since 1970-01-01 (civil calendar) *)
fun dayno (y : int, m : int, d : int) : int =
  let
    val y' = if m <= 2 then y - 1 else y
    val era = (if y' >= 0 then y' else y' - 399) div 400
    val yoe = y' - era * 400
    val mp = if m > 2 then m - 3 else m + 9
    val doy = (153 * mp + 2) div 5 + d - 1
    val doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  in era * 146097 + doe - 719468 end

fun parseDate (s : string) : int option =
  let val t = trim s in
    if size t <> 10 orelse String.sub (t, 4) <> #"-" orelse String.sub (t, 7) <> #"-" then NONE
    else
      case (Int.fromString (String.substring (t, 0, 4)), Int.fromString (String.substring (t, 5, 2)),
            Int.fromString (String.substring (t, 8, 2))) of
        (SOME y, SOME m, SOME d) =>
          if m >= 1 andalso m <= 12 andalso d >= 1 andalso d <= 31 andalso
             CharVector.all Char.isDigit (String.substring (t, 0, 4)) andalso
             CharVector.all Char.isDigit (String.substring (t, 5, 2)) andalso
             CharVector.all Char.isDigit (String.substring (t, 8, 2))
          then SOME (dayno (y, m, d)) else NONE
      | _ => NONE
  end

val eea = ["AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR","HU","IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","IS","LI","NO","EU","EEA"]

fun validLei (s : string) : bool =
  size s = 20 andalso CharVector.all (fn c => Char.isDigit c orelse (Char.isAlpha c andalso Char.isUpper c)) s

fun indexOf (names : string list) (n : string) : int option =
  let fun go [] _ = NONE
        | go (x :: xs) i = if x = n then SOME i else go xs (i + 1)
  in go names 0 end

fun audit (text : string, label : string, today : int) : finding list =
  let
    val lines = List.filter (fn (_, l) => trim l <> "") (ListPair.zip (List.tabulate (length (splitLines text), fn i => i + 1), splitLines text))
  in
    case lines of
      [] => [mk "info" "DOR000" label 0 "empty file, nothing to check"]
    | (_, h) :: rows =>
        let
          val head = map (lower o trim) (splitCsv h)
          val pi = indexOf head "provider"
          val ci = indexOf head "criticality"
        in
          if not (isSome pi) orelse not (isSome ci) then
            [mk "info" "DOR000" label 0 "no header with provider and criticality columns"]
          else
            let
              fun col (fields : string list) (name : string) : string =
                case indexOf head name of
                  NONE => ""
                | SOME i => if i < length fields then trim (List.nth (fields, i)) else ""
              fun one ((ln, l) : int * string) : finding list =
                let
                  val f = splitCsv l
                  val prov = col f "provider"
                  val who = if prov = "" then "(no name)" else prov
                  val crit = lower (col f "criticality")
                  val cif = crit = "critical" orelse crit = "important"
                  val out = ref ([] : finding list)
                  fun add sev rule msg = out := mk sev rule label ln msg :: !out
                in
                  if not (cif orelse crit = "standard") then
                    add "low" "DOR007" (who ^ " has no valid criticality (use critical, important or standard)")
                  else ();
                  if cif andalso lower (col f "exit_plan") <> "yes" then
                    add "high" "DOR001" (who ^ " supports a critical or important function and has no documented exit plan")
                  else ();
                  if cif andalso lower (col f "audit_right") <> "yes" then
                    add "high" "DOR002" (who ^ " supports a critical or important function without audit and access rights")
                  else ();
                  if not (validLei (col f "lei")) then
                    add "medium" "DOR003" (who ^ " has a missing or invalid LEI")
                  else ();
                  if cif andalso not (List.exists (fn c => c = String.map Char.toUpper (col f "data_location")) eea) then
                    add "medium" "DOR004" (who ^ " keeps data in '" ^ col f "data_location" ^ "', which is not an EEA location")
                  else ();
                  if cif andalso col f "subcontractors" = "" then
                    add "medium" "DOR005" (who ^ " has no declared subcontractors (write none if there are none)")
                  else ();
                  (case parseDate (col f "contract_end") of
                     NONE => ()
                   | SOME e =>
                       if e < today then add "medium" "DOR006" (who ^ " contract ended on " ^ col f "contract_end")
                       else if e - today <= 90 then add "low" "DOR006" (who ^ " contract ends on " ^ col f "contract_end" ^ ", within 90 days")
                       else ());
                  rev (!out)
                end
            in List.concat (map one rows) end
        end
  end

fun before (a : finding, b : finding) : bool =
  let val ra = rank (#sev a) and rb = rank (#sev b) in
    if ra <> rb then ra < rb
    else if #file a <> #file b then #file a < #file b
    else if #line a <> #line b then #line a < #line b
    else #rule a < #rule b
  end

fun sort (xs : finding list) : finding list =
  let
    fun merge ([], ys) = ys
      | merge (xs, []) = xs
      | merge (x :: xs, y :: ys) = if before (y, x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
    fun split [] = ([], [])
      | split [x] = ([x], [])
      | split (x :: y :: r) = let val (a, b) = split r in (x :: a, y :: b) end
    fun ms [] = []
      | ms [x] = [x]
      | ms xs = let val (a, b) = split xs in merge (ms a, ms b) end
  in ms xs end

fun sort_names (xs : string list) : string list =
  let
    fun insert (x, []) = [x]
      | insert (x, y :: ys) = if x <= y then x :: y :: ys else y :: insert (x, ys)
  in List.foldl insert [] xs end

fun where_ (f : finding) = if #line f > 0 then #file f ^ ":" ^ Int.toString (#line f) else #file f

end
