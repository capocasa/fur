Fur
===

Fur is a set of finite impulse response filters (FIR) for realtime use.

Minimal example
---------------

```nim
import fur

# fixed buffer size
var b = newSeq[float](64)

# steepish, sounds decent and only 16 samples latency
var f = initFur(32)

# scale to sample rate
let d = 1 / 48_000

# set coefficients to 220-240hz bandpass (you could turn the same filter into a lowpass later)
f.bandpass(220.0 * d, 240.0 * d)

# example data - a half buffer of slope
let nh = 1.0 / b.len.float
for i in 0 .. (b.len div 2) - 1:
  b[i] = i.float * nh

echo $s
for i in 0..s.len-1:
  s[i] = f.process(s[i])
echo $s
```

Realtime audio example
----------------------

And here is how to use it realtime, using the `jill` wrapper
for the jack audio connection kit. Since this works on sample
level it can be used for any DSP, e.g. supercollider ugen or
any DAW plugin.

note: 
This one sweeps the filter at every block (commonly called
"control rate"). For a real system the coefficients should
be precalculated and the sweep done at each sample.

```nim

import std/[math]
import jill, fur

# buffer size
let n = 64

# inverse of buffer size
let nh = 1.0 / n.float

#sample duration
let cs = 1 / 48000

# low latency but not completely distorted
var f = initFur(128)

# frequency init at 50hz
var c = 50 * cs

withJack output=out:
  c += 5 * cs
  if c > 2000 / 48000:
    c = 50 * cs
  #f.lopass(c)
  #f.hipass(c)
  f.bandpass(c, c+200*cs)
  #f.notch(c)
  for i in 0 .. (n div 2) - 1:
    out[i] = i.float * nh
    out[i] = f.process(out[i])

```

Notes
-----




Algorithms are from the [rtfir C library](https://github.com/vfiksdal)

