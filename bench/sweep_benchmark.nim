import std/[times, math, strformat, random]
import ../src/fur

type
  SweepType = enum
    Linear, Exponential, Sinusoidal, Random

  FilterType = enum
    Lowpass, Highpass, Bandpass, Notch

proc generateTestAudio(length: int, sampleRate: float = 44100.0): seq[float] =
  result = newSeq[float](length)
  var rng = initRand(42)
  
  for i in 0..<length:
    let t = i.float / sampleRate
    # Rich harmonic content for filter testing
    result[i] = 0.3 * sin(2.0 * PI * 220.0 * t) +      # A3 fundamental
                0.25 * sin(2.0 * PI * 440.0 * t) +     # A4 octave
                0.2 * sin(2.0 * PI * 880.0 * t) +      # A5 octave  
                0.15 * sin(2.0 * PI * 1320.0 * t) +    # E6 fifth
                0.12 * sin(2.0 * PI * 1760.0 * t) +    # A6 octave
                0.1 * sin(2.0 * PI * 2640.0 * t) +     # E7 fifth
                0.08 * sin(2.0 * PI * 3520.0 * t) +    # A7 octave
                0.05 * (rng.rand(2.0) - 1.0)           # noise

proc calculateSweepFreq(progress: float, startFreq: float, endFreq: float, sweepType: SweepType): float =
  case sweepType:
  of Linear:
    startFreq + progress * (endFreq - startFreq)
  of Exponential:
    startFreq * pow(endFreq / startFreq, progress)
  of Sinusoidal:
    let center = (startFreq + endFreq) / 2.0
    let range = (endFreq - startFreq) / 2.0
    center + range * sin(2.0 * PI * progress)
  of Random:
    startFreq + (endFreq - startFreq) * (sin(13.7 * progress) * 0.5 + 0.5)

proc frequencySweepBenchmark() =
  echo "=== Frequency Sweep Benchmark ==="
  
  let sampleRate = 44100.0
  let duration = 5.0  # 5 seconds
  let signalLength = int(sampleRate * duration)
  let taps = 128
  
  echo &"Signal: {duration}s at {sampleRate}Hz ({signalLength} samples)"
  echo &"Filter: {taps} taps"
  echo ""
  
  let testSignal = generateTestAudio(signalLength, sampleRate)
  
  # Test different sweep types and rates
  let sweepConfigs = [
    ("Slow Linear", Linear, 0.05, 0.45, 1.0),      # 1 sweep per 5s
    ("Fast Linear", Linear, 0.05, 0.45, 5.0),      # 5 sweeps per 5s  
    ("Slow Exponential", Exponential, 0.01, 0.5, 1.0),
    ("Fast Exponential", Exponential, 0.01, 0.5, 5.0),
    ("Sinusoidal", Sinusoidal, 0.1, 0.4, 2.0),     # 2 cycles per 5s
    ("Random", Random, 0.05, 0.45, 3.0)            # Pseudo-random changes
  ]
  
  for (name, sweepType, startFreq, endFreq, sweepsPerDuration) in sweepConfigs:
    echo &"Testing {name} sweep ({startFreq:.2f} to {endFreq:.2f}, {sweepsPerDuration}x)..."
    
    var filter = initFur[128]()
    var totalOutput = 0.0
    let startTime = cpuTime()
    var coeffUpdates = 0
    
    for i, sample in testSignal:
      # Calculate current sweep progress
      let timeProgress = i.float / signalLength.float
      let sweepProgress = (timeProgress * sweepsPerDuration) mod 1.0
      
      # Update filter frequency (recalculate coefficients)
      let currentFreq = calculateSweepFreq(sweepProgress, startFreq, endFreq, sweepType)
      filter.lopass(currentFreq)
      coeffUpdates += 1
      
      # Process sample
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    let updatesPerSec = coeffUpdates.float / elapsed
    
    echo &"  Time: {elapsed:.3f}s"
    echo &"  Samples/sec: {samplesPerSec:.0f}"
    echo &"  Coeff updates/sec: {updatesPerSec:.0f}"
    echo &"  Output: {totalOutput:.6f}"
    echo ""

proc filterTypeSweepBenchmark() =
  echo "=== Filter Type Sweep Benchmark ==="
  
  let sampleRate = 44100.0
  let duration = 4.0
  let signalLength = int(sampleRate * duration)  
  let taps = 64
  let switchInterval = 0.25  # Switch filter type every 250ms
  
  echo &"Signal: {duration}s at {sampleRate}Hz ({signalLength} samples)"
  echo &"Filter: {taps} taps, switching every {switchInterval}s"
  echo ""
  
  let testSignal = generateTestAudio(signalLength, sampleRate)
  let samplesPerSwitch = int(sampleRate * switchInterval)
  
  # Define filter configurations
  let filterConfigs = [
    (Lowpass, 0.2, 0.0, "Lowpass 0.2"),
    (Highpass, 0.15, 0.0, "Highpass 0.15"), 
    (Bandpass, 0.35, 0.1, "Bandpass 0.1-0.35"),
    (Notch, 0.3, 0.15, "Notch 0.15-0.3")
  ]
  
  var filter = initFur[128]()
  var totalOutput = 0.0
  let startTime = cpuTime()
  var typeSwithces = 0
  var currentConfigIdx = 0
  
  for i, sample in testSignal:
    # Switch filter type at regular intervals
    if i mod samplesPerSwitch == 0 and i > 0:
      currentConfigIdx = (currentConfigIdx + 1) mod filterConfigs.len
      let (filterType, freq1, freq2, name) = filterConfigs[currentConfigIdx]
      
      case filterType:
      of Lowpass:
        filter.lopass(freq1)
      of Highpass:
        filter.hipass(freq1)
      of Bandpass:
        filter.bandpass(freq1, freq2)
      of Notch:
        filter.notch(freq1, freq2)
      
      typeSwithces += 1
      
      if i < 10 * samplesPerSwitch:  # Only log first few switches
        let timeStamp = i.float / sampleRate
        echo &"  {timeStamp:.2f}s: Switched to {name}"
    
    totalOutput += filter.process(sample)
  
  let elapsed = cpuTime() - startTime
  let samplesPerSec = signalLength.float / elapsed
  let switchesPerSec = typeSwithces.float / elapsed
  
  echo &"Total switches: {typeSwithces}"
  echo &"Time: {elapsed:.3f}s"
  echo &"Samples/sec: {samplesPerSec:.0f}"
  echo &"Type switches/sec: {switchesPerSec:.1f}"
  echo &"Output: {totalOutput:.6f}"
  echo ""

proc realtimeAudioSweepBenchmark() =
  echo "=== Real-time Audio Sweep Simulation ==="
  
  let sampleRate = 44100.0
  let bufferSize = 256  # Typical audio buffer size
  let numBuffers = 1000 # ~5.8 seconds of audio
  let taps = 64
  
  echo &"Simulating real-time audio processing:"
  echo &"  Sample rate: {sampleRate}Hz"
  echo &"  Buffer size: {bufferSize} samples"  
  echo &"  Buffers: {numBuffers} ({(numBuffers * bufferSize).float / sampleRate:.1f}s total)"
  echo &"  Filter: {taps} taps"
  echo ""
  
  # Generate one buffer worth of test audio
  let testBuffer = generateTestAudio(bufferSize, sampleRate)
  
  var filter = initFur[128]()
  var totalOutput = 0.0
  let startTime = cpuTime()
  var parameterUpdates = 0
  
  # Simulate real-time processing with parameter automation
  for bufferIdx in 0..<numBuffers:
    let timeStamp = bufferIdx.float * bufferSize.float / sampleRate
    
    # Update filter parameters based on automation curves
    # Simulate typical synthesizer filter envelope + LFO modulation
    let envelopePhase = min(1.0, timeStamp / 2.0)  # 2s attack
    let lfoPhase = timeStamp * 1.5  # 1.5 Hz LFO
    
    let baseFreq = 0.1 + 0.3 * envelopePhase  # Envelope: 0.1 to 0.4
    let lfoAmount = 0.1 * sin(2.0 * PI * lfoPhase)  # ±0.1 modulation
    let finalFreq = max(0.01, min(0.49, baseFreq + lfoAmount))
    
    # Update filter (in real systems this might be less frequent)
    if bufferIdx mod 4 == 0:  # Update every 4th buffer (~23ms)
      filter.lopass(finalFreq)
      parameterUpdates += 1
    
    # Process the buffer
    for sample in testBuffer:
      totalOutput += filter.process(sample)
  
  let elapsed = cpuTime() - startTime
  let totalSamples = numBuffers * bufferSize
  let samplesPerSec = totalSamples.float / elapsed
  let buffersPerSec = numBuffers.float / elapsed
  let avgLatency = elapsed / numBuffers.float * 1000.0  # ms per buffer
  
  echo &"Processing completed:"
  echo &"  Total time: {elapsed:.3f}s"
  echo &"  Samples/sec: {samplesPerSec:.0f}"
  echo &"  Buffers/sec: {buffersPerSec:.1f}"
  echo &"  Avg latency: {avgLatency:.2f}ms per buffer"
  echo &"  Parameter updates: {parameterUpdates}"
  echo &"  Output: {totalOutput:.6f}"
  
  # Check if we could meet real-time requirements
  let requiredBuffersPerSec = sampleRate / bufferSize.float
  let realtimeRatio = buffersPerSec / requiredBuffersPerSec
  
  echo &"Real-time performance:"
  echo &"  Required: {requiredBuffersPerSec:.1f} buffers/sec"
  echo &"  Achieved: {buffersPerSec:.1f} buffers/sec"
  echo &"  Ratio: {realtimeRatio:.2f}x real-time"
  
  if realtimeRatio >= 1.0:
    echo &"  ✓ Can process in real-time with {(realtimeRatio - 1.0) * 100:.1f}% CPU headroom"
  else:
    echo &"  ✗ Cannot meet real-time requirements (needs {1.0/realtimeRatio:.2f}x speedup)"
  
  echo ""

proc staticFilterComparison() =
  echo "=== Static vs Sweeping Filter Comparison ==="
  
  let signalLength = 500_000
  let taps = 128
  let testSignal = generateTestAudio(signalLength)
  
  echo &"Signal: {signalLength} samples, {taps} taps"
  echo ""
  
  # Static filter benchmark
  block:
    echo "Static filter (no coefficient updates):"
    var filter = initFur[128]()
    filter.lopass(0.25)  # Set once
    
    var totalOutput = 0.0
    let startTime = cpuTime()
    
    for sample in testSignal:
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    
    echo &"  Time: {elapsed:.3f}s"
    echo &"  Samples/sec: {samplesPerSec:.0f}"
    echo &"  Output: {totalOutput:.6f}"
    echo ""
  
  # Sweeping filter benchmark (worst case - every sample)
  block:
    echo "Sweeping filter (coefficient update every sample):"
    var filter = initFur[128]()
    
    var totalOutput = 0.0
    let startTime = cpuTime()
    
    for i, sample in testSignal:
      # Linear frequency sweep
      let progress = i.float / signalLength.float
      let freq = 0.05 + 0.4 * progress  # 0.05 to 0.45
      filter.lopass(freq)
      
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    
    echo &"  Time: {elapsed:.3f}s"
    echo &"  Samples/sec: {samplesPerSec:.0f}" 
    echo &"  Output: {totalOutput:.6f}"
    echo ""
  
  # Moderate sweeping (every 100 samples)
  block:
    echo "Moderate sweeping (coefficient update every 100 samples):"
    var filter = initFur[128]()
    
    var totalOutput = 0.0
    let startTime = cpuTime()
    var updates = 0
    
    for i, sample in testSignal:
      if i mod 100 == 0:
        let progress = i.float / signalLength.float
        let freq = 0.05 + 0.4 * progress
        filter.lopass(freq)
        updates += 1
      
      totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let samplesPerSec = signalLength.float / elapsed
    
    echo &"  Time: {elapsed:.3f}s"
    echo &"  Samples/sec: {samplesPerSec:.0f}"
    echo &"  Updates: {updates}"
    echo &"  Output: {totalOutput:.6f}"

proc runSweepBenchmarks() =
  echo "=== Filter Sweep Benchmark Suite ==="
  echo "Testing dynamic filter parameter changes during processing"
  echo ""
  
  frequencySweepBenchmark()
  filterTypeSweepBenchmark()  
  realtimeAudioSweepBenchmark()
  staticFilterComparison()
  
  echo "=== Sweep benchmarks completed ==="

when isMainModule:
  runSweepBenchmarks()