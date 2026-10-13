# Run a program in a pseudo-terminal, send keystrokes one by one, show the last screen line after each.
import os, pty, sys, time, select
exe=sys.argv[1]; args=sys.argv[2:]
keys=[a.encode('latin-1').decode('unicode_escape').encode('latin-1') if '\\' in a else a.encode() for a in args]
pid,fd=pty.fork()
if pid==0: os.execv(exe,[exe])
buf=b''
def drain(t):
    global buf
    end=time.time()+t
    while time.time()<end:
        r,_,_=select.select([fd],[],[],0.05)
        if r:
            try: d=os.read(fd,4096)
            except OSError: return False
            if not d: return False
            buf+=d
    return True
def frame():
    t=buf.decode('utf-8','replace'); i=t.rfind('bytes:')
    return t[i:].split('\r')[0] if i>=0 else '(no frame)'
alive=drain(1.5); print('start   ->',frame())
for a,k in zip(args,keys):
    if not alive: print('(exited)'); break
    os.write(fd,k); alive=drain(0.5); print(f'{a!r:8}->',frame())
_,st=os.waitpid(pid,0); drain(0.2)
t=buf.decode('utf-8','replace')
print('exit',os.waitstatus_to_exitcode(st),'| restored:', '\x1b[?1049l' in t and '\x1b[?25h' in t,'| tail:',repr(t[-12:]))
