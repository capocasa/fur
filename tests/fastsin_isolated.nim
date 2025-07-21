import std/[times, math, strformat]
import ../src/fur

proc fastSinIsolatedProfile() =
  echo "=== Isolated Fast Sin Bottleneck Analysis ==="
  
  let iterations = 100_000_000  # 100M calls for detailed profiling
  var dummy = 0.0
  
  echo &"Running {iterations} fast sin calls for profiling..."
  let startTime = cpuTime()
  
  # Pure fast sin calls - this is the hot path for coefficient updates
  for i in 0..<iterations:
    # Typical range for FIR coefficient calculation: TWO_PI * freq * tap_index
    # freq ranges 0.01-0.5, tap_index ranges -64 to +64 for 128-tap filter
    let x = (i.float * 0.0001) - 5.0  # Range around -5 to +5, typical sinc range
    dummy += fastSin(x)
  
  let elapsed = cpuTime() - startTime
  let callsPerSec = iterations.float / elapsed
  
  echo &"Time: {elapsed:.3f}s"
  echo &"Calls/sec: {callsPerSec:.0f}"
  echo &"Dummy accumulator: {dummy:.6f}"

when isMainModule:
  fastSinIsolatedProfile()