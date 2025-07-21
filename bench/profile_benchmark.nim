import std/[times, math, strformat]
import ../src/fur

proc coefficientUpdateHotpath() =
  echo "=== Coefficient Update Profiling Benchmark ==="
  echo "Running intensive coefficient updates for profiling..."
  
  let taps = 128
  let iterations = 2_000_000  # 2M updates for sustained CPU load
  
  var filter = initFur(taps)
  var dummy = 0.0
  let startTime = cpuTime()
  
  # Hot loop: intensive coefficient updates
  for i in 0..<iterations:
    let progress = i.float / iterations.float
    let freq = 0.05 + 0.4 * progress  # Linear sweep 0.05 to 0.45
    
    # This is the hot path we want to profile
    filter.lopass(freq)
    
    # Prevent dead code elimination
    dummy += filter.coeff[0]
  
  let elapsed = cpuTime() - startTime
  let updatesPerSec = iterations.float / elapsed
  
  echo &"Iterations: {iterations}"
  echo &"Time: {elapsed:.3f}s"
  echo &"Updates/sec: {updatesPerSec:.0f}"
  echo &"Dummy accumulator: {dummy:.6f}"
  echo ""

proc mixedWorkloadProfile() =
  echo "=== Mixed Update+Processing Profile ==="
  echo "Testing coefficient updates + sample processing..."
  
  let taps = 128
  let signalLength = 1_000_000
  let updateInterval = 100  # Update every 100 samples
  
  # Generate test signal
  var testSignal = newSeq[float](signalLength)
  for i in 0..<signalLength:
    testSignal[i] = sin(2.0 * PI * 440.0 * i.float / 44100.0)
  
  var filter = initFur(taps)
  var totalOutput = 0.0
  let startTime = cpuTime()
  
  # Mixed workload: updates + processing
  for i, sample in testSignal:
    # Update coefficients periodically
    if i mod updateInterval == 0:
      let progress = i.float / signalLength.float
      let freq = 0.1 + 0.3 * progress
      filter.lopass(freq)
    
    # Process sample
    totalOutput += filter.process(sample)
  
  let elapsed = cpuTime() - startTime
  let samplesPerSec = signalLength.float / elapsed
  let updates = signalLength div updateInterval
  
  echo &"Signal length: {signalLength}"
  echo &"Update interval: every {updateInterval} samples"
  echo &"Total updates: {updates}"
  echo &"Time: {elapsed:.3f}s"
  echo &"Samples/sec: {samplesPerSec:.0f}"
  echo &"Total output: {totalOutput:.6f}"
  echo ""

proc filterTypeSwitchingProfile() =
  echo "=== Filter Type Switching Profile ==="
  echo "Testing different filter type coefficient calculations..."
  
  let taps = 128
  let iterations = 500_000  # 500K type switches
  
  var filter = initFur(taps)
  var dummy = 0.0
  let startTime = cpuTime()
  
  # Cycle through different filter types
  for i in 0..<iterations:
    let filterType = i mod 4
    let progress = (i div 4).float / (iterations.float / 4.0)
    
    case filterType:
    of 0:  # Lowpass
      let freq = 0.1 + 0.3 * progress
      filter.lopass(freq)
    of 1:  # Highpass  
      let freq = 0.1 + 0.3 * progress
      filter.hipass(freq)
    of 2:  # Bandpass
      let lo = 0.1 + 0.1 * progress
      let hi = 0.3 + 0.1 * progress
      filter.bandpass(hi, lo)
    of 3:  # Notch
      let lo = 0.1 + 0.1 * progress
      let hi = 0.3 + 0.1 * progress
      filter.notch(hi, lo)
    else:
      discard
    
    dummy += filter.coeff[taps div 2]  # Prevent optimization
  
  let elapsed = cpuTime() - startTime
  let updatesPerSec = iterations.float / elapsed
  
  echo &"Iterations: {iterations}"
  echo &"Time: {elapsed:.3f}s"
  echo &"Type switches/sec: {updatesPerSec:.0f}"
  echo &"Dummy accumulator: {dummy:.6f}"

proc isolateFastSinProfile() =
  echo "=== Isolated Fast Sin Profile ==="
  echo "Testing pure fast sin performance..."
  
  let iterations = 50_000_000  # 50M sin calls
  var dummy = 0.0
  let startTime = cpuTime()
  
  # Pure fast sin calls in typical FIR range
  for i in 0..<iterations:
    let x = (i.float / 1000.0) - 25.0  # Range around 0, typical for sinc
    dummy += fastSin(x)
  
  let elapsed = cpuTime() - startTime
  let callsPerSec = iterations.float / elapsed
  
  echo &"Sin calls: {iterations}"
  echo &"Time: {elapsed:.3f}s"
  echo &"Calls/sec: {callsPerSec:.0f}"
  echo &"Dummy accumulator: {dummy:.6f}"
  echo ""

when isMainModule:
  # Run different profiling scenarios
  coefficientUpdateHotpath()
  mixedWorkloadProfile()
  filterTypeSwitchingProfile()
  isolateFastSinProfile()