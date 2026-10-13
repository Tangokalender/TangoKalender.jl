# Experimental spike for an interactive tangoedit (plan: a full-screen form): can a trimmed program (juliac
# --trim=safe) put the terminal in raw mode, read keys and draw, on Linux, macOS and Windows? Raw mode comes from libuv
# (uv_tty_set_mode, on a tty handle of our own), bytes are read directly. Shows the bytes of each key; q or Esc quits.
# Tachikoma.jl was tried first and doesn't trim (64 verifier errors: REPL/Pkg extension, Preferences, Any-typed state).
# A libuv tty handle on fd 0 of our own: in a trimmed program `stdin` isn't a `Base.TTY`.
function _tty_handle()
 (Sys.iswindows() ? ccall(:_isatty,Cint,(Cint,),0) : ccall(:isatty,Cint,(Cint,),0))!=0 || return C_NULL
 h=Libc.malloc(Base._sizeof_uv_tty)
 ccall(:uv_tty_init,Cint,(Ptr{Cvoid},Ptr{Cvoid},Cint,Cint),Base.eventloop(),h,0,1)==0 ? h : (Libc.free(h); C_NULL)
end
function _raw!(h::Ptr{Cvoid}, on::Bool)
 on || return ccall(:uv_tty_reset_mode,Cint,())
 rc=ccall(:uv_tty_set_mode,Cint,(Ptr{Cvoid},Cint),h,Cint(Sys.iswindows() ? 3 : 1))   # UV_TTY_MODE_RAW_VT on Windows, RAW elsewhere
 rc==0 ? rc : ccall(:uv_tty_set_mode,Cint,(Ptr{Cvoid},Cint),h,Cint(1))
end
_out(s::String)=(write(Core.stdout,s); nothing)
# One byte from the terminal, read directly (reading through libuv's stream doesn't trim); `nothing` after `ms`
# milliseconds without input (ms<0 waits forever).
@static if Sys.iswindows()
 const _STDIN=Ref{Ptr{Cvoid}}(C_NULL)
 function _byte(ms::Int)
  _STDIN[]==C_NULL && (_STDIN[]=ccall((:GetStdHandle,"kernel32"),stdcall,Ptr{Cvoid},(UInt32,),0xfffffff6))
  ms>=0 && ccall((:WaitForSingleObject,"kernel32"),stdcall,UInt32,(Ptr{Cvoid},UInt32),_STDIN[],UInt32(ms))!=0 && return nothing
  b=Ref{UInt8}(0); n=Ref{UInt32}(0)
  ccall((:ReadFile,"kernel32"),stdcall,Cint,(Ptr{Cvoid},Ptr{UInt8},UInt32,Ptr{UInt32},Ptr{Cvoid}),_STDIN[],b,1,n,C_NULL)
  n[]==1 ? b[] : nothing
 end
else
 function _byte(ms::Int)   # uv_tty_init makes fd 0 non-blocking, so wait with poll and retry on EAGAIN
  b=Ref{UInt8}(0)
  while true
   pfd=Ref((Cint(0),Cshort(1),Cshort(0)))   # struct pollfd {fd, events=POLLIN, revents}
   ccall(:poll,Cint,(Ptr{Cvoid},Culong,Cint),pfd,1,ms)<=0 && ms>=0 && return nothing
   n=ccall(:read,Cssize_t,(Cint,Ptr{UInt8},Csize_t),0,b,1)
   n==1 && return b[]
   n==0 && return nothing   # end of input
   Libc.errno() in (Libc.EAGAIN,Libc.EINTR) || return nothing
  end
 end
end
function @main(args::Vector{String})::Cint
 tty=_tty_handle()
 tty==C_NULL && (write(Core.stderr,"not a terminal\n"); return Cint(2))
 _raw!(tty,true); _out("\e[?1049h\e[?25l\e[2J\e[H")
 seen=UInt8[]
 try
  while true
   _out("\e[H\e[2Jtrim spike – trykk taster (q/Esc avslutter)\r\nbytes: "*join(string.(seen," "))*"\r\n")
   b=_byte(-1); isnothing(b) && break
   if b==0x1b
    nx=_byte(30); isnothing(nx) && break   # a lone Esc
    push!(seen,b); b=nx
   end
   b==UInt8('q') && break
   push!(seen,b); length(seen)>40 && popfirst!(seen)
  end
 finally
  _raw!(tty,false); _out("\e[?25h\e[?1049l")
 end
 _out("ok\n"); Cint(0)
end
Base.Experimental.entrypoint(main,(Vector{String},))
