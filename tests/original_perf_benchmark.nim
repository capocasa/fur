import std/[times, random, strformat, os, math]
import original_fur

# Hot loop function using original implementation
proc originalHotLoopBenchmark() =
  echo "=== Original Implementation Hot Loop Benchmark ==="
  
  let taps = 128
  let signalLength = 500_000
  let iterations = 200
  
  var filter = initOriginalFur(taps)
  filter.lopass(0.25)
  
  # Generate simple sine wave (less overhead than complex signal)
  var signal = newSeq[float](signalLength)
  for i in 0..<signalLength:
    signal[i] = sin(2.0 * PI * i.float / 1000.0)
  
  echo &"Hot loop: {taps} taps, {signalLength} samples, {iterations} iterations"
  
  let startTime = cpuTime()
  var accumulator = 0.0
  
  # This is the hot path we want to profile
  for iter in 0..<iterations:
    for sample in signal:
      accumulator += filter.process(sample)
  
  let elapsed = cpuTime() - startTime
  let totalSamples = signalLength * iterations
  let samplesPerSec = totalSamples.float / elapsed
  
  echo &"Original hot loop completed in {elapsed:.3f}s"
  echo &"Processed {totalSamples} samples at {samplesPerSec:.0f} samples/sec"
  echo &"Accumulator: {accumulator:.6f} (prevents dead code elimination)"

when isMainModule:
  originalHotLoopBenchmark()