fun readFile (p : string) : string =
  let val s = TextIO.openIn p val t = TextIO.inputAll s in TextIO.closeIn s; t end

fun die (code : int) = Posix.Process.exit (Word8.fromInt code)

fun usage () =
  (TextIO.output (TextIO.stdErr, "usage: dora-ict-register PATH [--tsv] [--fail-on medium|high|critical] [--today YYYY-MM-DD]\nExit: 0 ok, 1 findings at or above --fail-on, 2 bad input.\n"); die 2)

fun endsWith (s : string, suf : string) = String.isSuffix suf s

fun listCsv (dir : string) : string list =
  let
    val d = OS.FileSys.openDir dir
    fun loop acc = case OS.FileSys.readDir d of NONE => acc | SOME n => loop (n :: acc)
    val names = loop []
    val _ = OS.FileSys.closeDir d
  in
    Dora.sort_names (List.filter (fn n => endsWith (n, ".csv") andalso not (OS.FileSys.isDir (OS.Path.concat (dir, n)))) names)
  end

fun main () =
  let
    val args = CommandLine.arguments ()
    val path = ref (NONE : string option)
    val tsv = ref false
    val failOn = ref (NONE : string option)
    val today = ref (Option.getOpt (Dora.parseDate (Date.fmt "%Y-%m-%d" (Date.fromTimeLocal (Time.now ()))), 0))
    fun parse [] = ()
      | parse ("--tsv" :: r) = (tsv := true; parse r)
      | parse ("--fail-on" :: v :: r) =
          if v = "medium" orelse v = "high" orelse v = "critical" then (failOn := SOME v; parse r) else usage ()
      | parse ("--fail-on" :: []) = usage ()
      | parse ("--today" :: v :: r) = (case Dora.parseDate v of SOME d => (today := d; parse r) | NONE => usage ())
      | parse ("--today" :: []) = usage ()
      | parse (a :: r) =
          if String.isPrefix "-" a then usage ()
          else if isSome (!path) then usage ()
          else (path := SOME a; parse r)
    val _ = parse args
    val p = case !path of NONE => usage () | SOME p => p
    val exists = (OS.FileSys.fileSize p; true) handle _ => (OS.FileSys.isDir p handle _ => false)
    val _ = if exists then () else (TextIO.output (TextIO.stdErr, "error: no such file or directory: " ^ p ^ "\n"); die 2)
    val isDir = OS.FileSys.isDir p handle _ => false
    val files =
      if isDir then
        let val base = if size p > 1 andalso String.isSuffix "/" p then String.substring (p, 0, size p - 1) else p
        in map (fn n => (n, OS.Path.concat (base, n))) (listCsv base) end
      else [(OS.Path.file p, p)]
    val all = List.concat (map (fn (label, fp) =>
                  Dora.audit (readFile fp handle _ => "", label, !today)) files)
    val sorted = Dora.sort all
    val head = Int.toString (length files) ^ " files, " ^ Int.toString (length sorted) ^ " findings"
    val _ = print ((if !tsv then "# " ^ head else head) ^ "\n")
    val _ = List.app (fn (f : Dora.finding) =>
              if !tsv then print (#sev f ^ "\t" ^ #rule f ^ "\t" ^ Dora.where_ f ^ "\t" ^ #msg f ^ "\n")
              else
                let val up = String.map Char.toUpper (#sev f)
                    val pad = up ^ CharVector.tabulate (Int.max (0, 8 - size up), fn _ => #" ")
                in print (pad ^ " " ^ #rule f ^ " " ^ Dora.where_ f ^ "\n         " ^ #msg f ^ "\n") end) sorted
    val bad = case !failOn of
                NONE => false
              | SOME lvl => List.exists (fn (f : Dora.finding) => Dora.rank (#sev f) <= Dora.rank lvl) sorted
  in
    if bad then die 1 else die 0
  end
