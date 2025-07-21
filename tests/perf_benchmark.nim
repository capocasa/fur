import std/[times, random, strformat, os, math]
import ../src/fur

proc generatePerfTestSignal(length: int): seq[float] =
  result = newSeq[float](length)
  var rng = initRand(12345)
  
  for i in 0..<length:
    let t = i.float / 44100.0
    # Complex multi-frequency signal
    result[i] = 0.4 * sin(2.0 * PI * 440.0 * t) +      # 440 Hz
                0.3 * sin(2.0 * PI * 1000.0 * t) +     # 1 kHz  
                0.2 * sin(2.0 * PI * 2500.0 * t) +     # 2.5 kHz
                0.15 * sin(2.0 * PI * 5000.0 * t) +    # 5 kHz
                0.1 * sin(2.0 * PI * 8000.0 * t) +     # 8 kHz
                0.05 * (rng.rand(2.0) - 1.0)           # noise

proc runExtendedBenchmark() =
  echo "=== Extended Performance Benchmark for Profiling ==="
  echo "This benchmark will run for several seconds to enable detailed profiling"
  echo ""
  
  # Large signal for sustained processing
  let signalLength = 1_000_000  # 1M samples
  let iterations = 100          # Process 100M samples total
  let tapCounts = [64, 128, 256]
  
  echo &"Processing {signalLength * iterations} samples total..."
  echo &"Signal length per iteration: {signalLength}"
  echo &"Iterations: {iterations}"
  echo ""
  
  let testSignal = generatePerfTestSignal(signalLength)
  echo "Generated test signal with complex frequency content"
  echo ""
  
  for taps in tapCounts:
    echo &"=== Profiling {taps}-tap filter ==="
    
    # Lowpass filter benchmark
    block:
      echo "Running lowpass filter benchmark..."
      var filter = initFur(taps)
      filter.lopass(0.1)  # 10% of Nyquist
      
      let startTime = cpuTime()
      var totalOutput = 0.0
      
      for iter in 0..<iterations:
        for sample in testSignal:
          totalOutput += filter.process(sample)
      
      let elapsed = cpuTime() - startTime
      let samplesPerSec = (signalLength * iterations).float / elapsed
      
      echo &"  Time: {elapsed:.3f}s"
      echo &"  Samples/sec: {samplesPerSec:.0f}"
      echo &"  Total output sum: {totalOutput:.6f} (prevents optimization)"
      echo ""
    
    # Highpass filter benchmark  
    block:
      echo "Running highpass filter benchmark..."
      var filter = initFur(taps)
      filter.hipass(0.3)  # 30% of Nyquist
      
      let startTime = cpuTime()
      var totalOutput = 0.0
      
      for iter in 0..<iterations:
        for sample in testSignal:
          totalOutput += filter.process(sample)
      
      let elapsed = cpuTime() - startTime
      let samplesPerSec = (signalLength * iterations).float / elapsed
      
      echo &"  Time: {elapsed:.3f}s"
      echo &"  Samples/sec: {samplesPerSec:.0f}"
      echo &"  Total output sum: {totalOutput:.6f} (prevents optimization)"
      echo ""
    
    # Bandpass filter benchmark
    block:
      echo "Running bandpass filter benchmark..."
      var filter = initFur(taps)
      filter.bandpass(0.4, 0.1)  # 10%-40% of Nyquist
      
      let startTime = cpuTime()
      var totalOutput = 0.0
      
      for iter in 0..<iterations:
        for sample in testSignal:
          totalOutput += filter.process(sample)
      
      let elapsed = cpuTime() - startTime
      let samplesPerSec = (signalLength * iterations).float / elapsed
      
      echo &"  Time: {elapsed:.3f}s"
      echo &"  Samples/sec: {samplesPerSec:.0f}"
      echo &"  Total output sum: {totalOutput:.6f} (prevents optimization)"
      echo ""
  
  echo "=== CPU-intensive workload completed ==="
  echo "This process is suitable for perf profiling with:"
  echo "  perf record -g ./perf_benchmark"
  echo "  perf report"

# Hot loop function for focused profiling
proc hotLoopBenchmark() =
  echo "=== Hot Loop Benchmark (CPU-intensive) ==="
  
  let taps = 128
  let signalLength = 500_000
  let iterations = 200
  
  var filter = initFur(taps)
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
  
  echo &"Hot loop completed in {elapsed:.3f}s"
  echo &"Processed {totalSamples} samples at {samplesPerSec:.0f} samples/sec"
  echo &"Accumulator: {accumulator:.6f} (prevents dead code elimination)"

when isMainModule:
  # Check command line argument for hot loop mode
  if paramCount() > 0 and paramStr(1) == "hotloop":
    hotLoopBenchmark()
  else:
    runExtendedBenchmark()