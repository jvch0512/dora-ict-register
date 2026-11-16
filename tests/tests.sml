val passed = ref 0
val failed = ref 0
fun check (ok : bool) (name : string) =
  if ok then passed := !passed + 1 else (failed := !failed + 1; print ("FAIL: " ^ name ^ "\n"))

val H = "provider,lei,function,criticality,subcontractors,exit_plan,audit_right,data_location,contract_end\n"
val LEI = "5493001KJTIIGC8Y1R12"
val today = valOf (Dora.parseDate "2026-11-16")
fun rules (t : string) : string =
  String.concatWith "," (map #rule (Dora.audit (t, "t.csv", today)))
fun row (lei, crit, sub, exit, aud, loc, endd) =
  H ^ "Acme," ^ lei ^ ",fn," ^ crit ^ "," ^ sub ^ "," ^ exit ^ "," ^ aud ^ "," ^ loc ^ "," ^ endd ^ "\n"
val good = row (LEI, "critical", "none", "yes", "yes", "ES", "2029-01-01")

val _ = check (rules good = "") "clean critical provider"
val _ = check (rules (row (LEI, "critical", "none", "no", "yes", "ES", "2029-01-01")) = "DOR001") "exit plan no"
val _ = check (rules (row (LEI, "critical", "none", "", "yes", "ES", "2029-01-01")) = "DOR001") "exit plan empty"
val _ = check (rules (row (LEI, "important", "none", "no", "yes", "ES", "2029-01-01")) = "DOR001") "important also needs exit plan"
val _ = check (rules (row (LEI, "standard", "", "no", "no", "US", "2029-01-01")) = "") "standard provider is not held to CIF rules"
val _ = check (rules (row (LEI, "critical", "none", "yes", "no", "ES", "2029-01-01")) = "DOR002") "audit right no"
val _ = check (rules (row (LEI, "critical", "none", "yes", "YES", "ES", "2029-01-01")) = "") "yes is case-insensitive"
val _ = check (rules (row ("", "critical", "none", "yes", "yes", "ES", "2029-01-01")) = "DOR003") "empty LEI"
val _ = check (rules (row ("12345", "standard", "", "", "", "", "2029-01-01")) = "DOR003") "short LEI"
val _ = check (rules (row ("5493001kjtiigc8y1r12", "standard", "", "", "", "", "2029-01-01")) = "DOR003") "lowercase LEI"
val _ = check (rules (row ("5493001KJTIIGC8Y1R1!", "standard", "", "", "", "", "2029-01-01")) = "DOR003") "punctuation in LEI"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "US", "2029-01-01")) = "DOR004") "US data location"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "", "2029-01-01")) = "DOR004") "empty data location"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "eea", "2029-01-01")) = "") "eea lowercase accepted"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "NO", "2029-01-01")) = "") "Norway is in the EEA"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "GB", "2029-01-01")) = "DOR004") "GB is not in the EEA"
val _ = check (rules (row (LEI, "critical", "", "yes", "yes", "ES", "2029-01-01")) = "DOR005") "no subcontractors declared"
val _ = check (rules (row (LEI, "critical", "\"A, B\"", "yes", "yes", "ES", "2029-01-01")) = "") "quoted subcontractor list"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "ES", "2026-11-15")) = "DOR006") "contract ended yesterday"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "ES", "2026-11-16")) = "DOR006") "contract ends today is low"
val _ = check (Dora.rank (#sev (hd (Dora.audit (row (LEI, "critical", "none", "yes", "yes", "ES", "2026-11-15"), "t", today)))) = 2) "ended is medium"
val _ = check (Dora.rank (#sev (hd (Dora.audit (row (LEI, "critical", "none", "yes", "yes", "ES", "2026-12-01"), "t", today)))) = 3) "ending soon is low"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "ES", "2027-02-14")) = "DOR006") "day 90 is included"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "ES", "2027-02-15")) = "") "day 91 is not"
val _ = check (rules (row (LEI, "critical", "none", "yes", "yes", "ES", "soon")) = "") "invalid date ignored"
val _ = check (rules (row (LEI, "", "none", "yes", "yes", "ES", "2029-01-01")) = "DOR007") "empty criticality"
val _ = check (rules (row (LEI, "vital", "none", "yes", "yes", "ES", "2029-01-01")) = "DOR007") "unknown criticality"

val _ = check (rules "" = "DOR000") "empty file"
val _ = check (rules "\n\n" = "DOR000") "blank file"
val _ = check (rules "a,b\n1,2\n" = "DOR000") "wrong header"
val _ = check (#sev (hd (Dora.audit ("", "e", today))) = "info") "DOR000 is info"
val _ = check (rules (String.translate (fn #"\n" => "\r\n" | c => String.str c) good) = "") "crlf file"
val _ = check (rules (H) = "") "header only is fine"

(* csv *)
val _ = check (Dora.splitCsv "a,\"b,c\",d" = ["a", "b,c", "d"]) "quoted comma"
val _ = check (Dora.splitCsv "a,\"say \"\"hi\"\"\"" = ["a", "say \"hi\""]) "escaped quote"
val _ = check (Dora.splitCsv "" = [""]) "empty line"
val _ = check (Dora.splitCsv "a,,b" = ["a", "", "b"]) "empty field"
val _ = check (Dora.splitCsv "a,b," = ["a", "b", ""]) "trailing comma"

(* dates *)
val _ = check (Dora.dayno (1970, 1, 1) = 0) "epoch"
val _ = check (Dora.dayno (2000, 3, 1) - Dora.dayno (2000, 2, 28) = 2) "leap year 2000"
val _ = check (Dora.dayno (1900, 3, 1) - Dora.dayno (1900, 2, 28) = 1) "1900 is not leap"
val _ = check (Dora.dayno (2027, 1, 1) - Dora.dayno (2026, 1, 1) = 365) "plain year"
val _ = check (Dora.parseDate "2026-13-01" = NONE) "month 13"
val _ = check (Dora.parseDate "2026-1-01" = NONE) "short month"
val _ = check (Dora.parseDate "26-11-16" = NONE) "short year"
val _ = check (Dora.parseDate "abcd-ef-gh" = NONE) "letters"
val _ = check (isSome (Dora.parseDate " 2026-11-16 ")) "spaces trimmed"

(* sorting and where *)
val fs = [{sev="low", rule="B", file="a", line=1, msg=""}, {sev="high", rule="A", file="z", line=9, msg=""},
          {sev="high", rule="A", file="a", line=10, msg=""}, {sev="high", rule="A", file="a", line=2, msg=""}]
val sorted = Dora.sort fs
val _ = check (map (fn f => #file f ^ Int.toString (#line f)) sorted = ["a2", "a10", "z9", "a1"]) "severity, file, numeric line"
val _ = check (Dora.where_ {sev="low", rule="x", file="f.csv", line=0, msg=""} = "f.csv") "where without line"
val _ = check (Dora.where_ {sev="low", rule="x", file="f.csv", line=7, msg=""} = "f.csv:7") "where with line"

(* fuzz: deterministic LCG *)
val seed = ref 12345
fun rnd n = (seed := (!seed * 1103515245 + 12345) mod 2147483648; (!seed div 65536) mod n)
val bits = Vector.fromList ["", ",", "\"", "\n", "provider", "criticality", "critical", "yes", "2026-01-01", " ", "\r", "a,b", "ES", "5493001KJTIIGC8Y1R12"]
fun gen 0 = "" | gen n = Vector.sub (bits, rnd (Vector.length bits)) ^ gen (n - 1)
val crashed = ref false
val _ = List.app (fn _ => (Dora.audit (gen (1 + rnd 30), "f", today); ()) handle _ => crashed := true) (List.tabulate (3000, fn i => i))
val _ = check (not (!crashed)) "3000 random inputs do not raise"

val _ = print (Int.toString (!passed) ^ " passed, " ^ Int.toString (!failed) ^ " failed\n")
val _ = if !failed = 0 then OS.Process.exit OS.Process.success else OS.Process.exit OS.Process.failure
