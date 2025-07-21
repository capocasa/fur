import std/[times, math, strformat]
import ../src/fur

proc benchmarkCoefficientUpdates() =
  echo "=== Coefficient Update Cost Analysis ==="
  
  let taps = 128
  let signalLength = 1_000_000
  let iterations = 3
  
  # Generate simple test signal
  var testSignal = newSeq[float](signalLength)
  for i in 0..<signalLength:
    testSignal[i] = sin(2.0 * PI * i.float / 1000.0)
  
  echo &"Signal: {signalLength} samples, {taps} taps, {iterations} iterations each"
  echo ""
  
  # Benchmark 1: Process only (no coefficient updates)  
  block:
    echo "1. Processing only (coefficients set once):"
    var totalTime = 0.0
    var totalOutput = 0.0
    
    for iter in 0..<iterations:
      var filter = initFur(taps)
      filter.lopass(0.25)  # Set once
      
      let startTime = cpuTime()
      for sample in testSignal:
        totalOutput += filter.process(sample)
      totalTime += cpuTime() - startTime
    
    let avgTime = totalTime / iterations.float
    let samplesPerSec = signalLength.float / avgTime
    
    echo &"  Avg time: {avgTime:.3f}s"  
    echo &"  Samples/sec: {samplesPerSec:.0f}"
    echo &"  Output: {totalOutput / iterations.float:.6f}"
    echo ""
  
  # Benchmark 2: Coefficient updates only (no processing)
  block:
    echo "2. Coefficient updates only (no sample processing):"
    var totalTime = 0.0
    
    for iter in 0..<iterations:
      var filter = initFur(taps)
      
      let startTime = cpuTime()
      for i in 0..<signalLength:
        let freq = 0.1 + 0.3 * (i.float / signalLength.float)
        filter.lopass(freq)
      totalTime += cpuTime() - startTime
    
    let avgTime = totalTime / iterations.float
    let updatesPerSec = signalLength.float / avgTime
    
    echo &"  Avg time: {avgTime:.3f}s"
    echo &"  Updates/sec: {updatesPerSec:.0f}"
    echo ""
  
  # Benchmark 3: Both updates and processing
  block:
    echo "3. Both coefficient updates and processing:"
    var totalTime = 0.0
    var totalOutput = 0.0
    
    for iter in 0..<iterations:
      var filter = initFur(taps)
      
      let startTime = cpuTime()
      for i, sample in testSignal:
        let freq = 0.1 + 0.3 * (i.float / signalLength.float)
        filter.lopass(freq)
        totalOutput += filter.process(sample)
      totalTime += cpuTime() - startTime
    
    let avgTime = totalTime / iterations.float
    let samplesPerSec = signalLength.float / avgTime
    
    echo &"  Avg time: {avgTime:.3f}s"
    echo &"  Samples/sec: {samplesPerSec:.0f}"  
    echo &"  Output: {totalOutput / iterations.float:.6f}"
    echo ""
  
  # Benchmark 4: Different update frequencies
  let updateIntervals = [1, 10, 100, 1000, 10000]
  
  echo "4. Processing with different coefficient update frequencies:"
  for interval in updateIntervals:
    var totalTime = 0.0
    var totalOutput = 0.0
    var totalUpdates = 0
    
    for iter in 0..<iterations:
      var filter = initFur(taps)
      filter.lopass(0.25)  # Initial setting
      
      let startTime = cpuTime()
      for i, sample in testSignal:
        if i mod interval == 0:
          let freq = 0.1 + 0.3 * (i.float / signalLength.float)
          filter.lopass(freq)
          totalUpdates += 1
        totalOutput += filter.process(sample)
      totalTime += cpuTime() - startTime
    
    let avgTime = totalTime / iterations.float
    let samplesPerSec = signalLength.float / avgTime
    let avgUpdates = totalUpdates / iterations
    let updateFreqHz = avgUpdates.float / avgTime
    
    echo &"  Every {interval} samples:"
    echo &"    Time: {avgTime:.3f}s, Samples/sec: {samplesPerSec:.0f}"
    echo &"    Updates: {avgUpdates}, Update freq: {updateFreqHz:.1f}Hz"
    echo &"    Output: {totalOutput / iterations.float:.6f}"

proc realWorldScenarios() =
  echo ""
  echo "=== Real-world Scenario Benchmarks ==="
  
  # Scenario 1: Synthesizer filter envelope  
  block:
    echo "1. Synthesizer filter envelope (exponential decay):"
    let sampleRate = 44100.0
    let duration = 2.0  # 2-second note
    let signalLength = int(sampleRate * duration)
    let taps = 64
    
    var filter = initFur(taps)
    var totalOutput = 0.0
    let startTime = cpuTime()
    
    for i in 0..<signalLength:
      let t = i.float / sampleRate
      let envelope = exp(-t * 2.0)  # Exponential decay
      let freq = 0.05 + 0.4 * envelope  # 0.05 to 0.45
      
      filter.lopass(freq)
      
      # Simple sawtooth wave
      let phase = (i.float * 440.0 / sampleRate) mod 1.0
      let sample = 2.0 * phase - 1.0
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    
    echo &"  Duration: {duration}s, Sample rate: {sampleRate}Hz"
    echo &"  Time: {elapsed:.3f}s, Samples/sec: {samplesPerSec:.0f}"
    echo &"  Output: {totalOutput:.6f}"
    echo ""
  
  # Scenario 2: LFO modulation
  block:
    echo "2. LFO-modulated filter (1 Hz sine wave modulation):"
    let sampleRate = 44100.0
    let duration = 3.0  # 3 seconds
    let signalLength = int(sampleRate * duration)
    let taps = 64
    let lfoFreq = 1.0  # 1 Hz LFO
    
    var filter = initFur(taps)
    var totalOutput = 0.0
    let startTime = cpuTime()
    
    for i in 0..<signalLength:
      let t = i.float / sampleRate
      let lfo = sin(2.0 * PI * lfoFreq * t)
      let freq = 0.2 + 0.15 * lfo  # 0.05 to 0.35 range
      
      filter.lopass(freq)
      
      # White noise input
      let sample = sin(i.float * 0.1)  # Simple test signal
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    
    echo &"  Duration: {duration}s, LFO: {lfoFreq}Hz"
    echo &"  Time: {elapsed:.3f}s, Samples/sec: {samplesPerSec:.0f}"
    echo &"  Output: {totalOutput:.6f}"
    echo ""
  
  # Scenario 3: Manual parameter automation  
  block:
    echo "3. Manual parameter automation (typical DAW automation):"
    let sampleRate = 44100.0
    let duration = 4.0
    let signalLength = int(sampleRate * duration)
    let taps = 128
    let automationRate = 20.0  # 20 Hz automation (typical for smooth sweeps)
    
    var filter = initFur(taps)
    var totalOutput = 0.0
    let startTime = cpuTime()
    var updates = 0
    
    let updateInterval = int(sampleRate / automationRate)
    
    for i in 0..<signalLength:
      if i mod updateInterval == 0:
        let progress = i.float / signalLength.float
        let freq = 0.05 + 0.4 * progress  # Linear sweep
        filter.lopass(freq)
        updates += 1
      
      # Rich harmonic test signal  
      let t = i.float / sampleRate
      let sample = 0.5 * sin(2.0 * PI * 220.0 * t) +
                   0.3 * sin(2.0 * PI * 440.0 * t) +
                   0.2 * sin(2.0 * PI * 880.0 * t)
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    
    echo &"  Duration: {duration}s, Automation rate: {automationRate}Hz"
    echo &"  Updates: {updates}, Samples/sec: {samplesPerSec:.0f}"
    echo &"  Time: {elapsed:.3f}s"
    echo &"  Output: {totalOutput:.6f}"

when isMainModule:
  benchmarkCoefficientUpdates()
  realWorldScenarios()