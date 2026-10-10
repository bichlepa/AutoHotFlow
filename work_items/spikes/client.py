import ctypes, subprocess, sys, time, os
exe = r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
script = os.path.join(os.path.dirname(__file__), "pipe_server.ahk")
hw=os.path.join(os.path.dirname(script),"hwnd.txt")
if os.path.exists(hw): os.remove(hw)
p = subprocess.Popen([exe, script])
for _ in range(100):
    if os.path.exists(hw) and os.path.getsize(hw)>0: break
    time.sleep(0.05)
hwnd = int(open(hw).read().strip())
print("hwnd", hwnd)
user32 = ctypes.windll.user32
f = None
for _ in range(50):
    try:
        f = open("//./pipe/ahf_spike".replace("/", chr(92)), "r+b", buffering=0); break
    except OSError: time.sleep(0.05)
print("connected", f is not None)
def rt(msg, wake):
    t=time.perf_counter()
    f.write(msg.encode())
    if wake: user32.PostMessageW(hwnd, 0x8001, 0, 0)
    r=f.read(len(msg)+5)
    return r, (time.perf_counter()-t)*1000
for wake in (False, True):
    lat=[rt("hello%d"%i, wake)[1] for i in range(20)]
    print("wake" if wake else "poll-only", "median ms %.1f max %.1f" % (sorted(lat)[10], max(lat)))
f.close(); p.kill()
