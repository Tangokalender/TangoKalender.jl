# Entry point of the trimmed `tangoedit` executable, built by bin/build_tangoedit.sh with JuliaC (`--trim=safe`):
# `tangokalender edit` with ANSI output instead of StyledStrings and `check_event_tree` instead of JSONSchema, neither
# of which can be trimmed yet. The renderers, geocoding and JSONSchema are never reached and are left out.
# `stdout`/`stderr` have no fixed type, so output goes to buffers and is copied to `Core.stdout`/`Core.stderr`.
using TangoKalender
_tty(fd)=ccall(:isatty,Cint,(Cint,),fd)==1
_columns()=(c=tryparse(Int,get(ENV,"COLUMNS","")); isnothing(c) ? 100 : c)
function @main(args::Vector{String})::Cint
 out=IOContext(IOBuffer(),:displaysize=>(24,_columns())); err=IOBuffer()
 color=_tty(1) && get(ENV,"NO_COLOR","")==""
 code=TangoKalender.edit_main(args;io=out,err,tree_check=TangoKalender.check_event_tree,
  render=l->TangoKalender.ansi_text(l;color))
 write(Core.stderr,take!(err)); write(Core.stdout,take!(out.io))
 return Cint(code)
end
Base.Experimental.entrypoint(main,(Vector{String},))
