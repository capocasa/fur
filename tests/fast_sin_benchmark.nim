import std/[times, math, strformat, random]
import ../src/fur
import original_fur

proc accuracyTest() =
  echo "=== Fast Sin Accuracy Analysis ==="
  
  var maxError = 0.0
  var avgError = 0.0
  let testCount = 100000
  var rng = initRand(42)
  
  # Test across the range used in FIR coefficient calculations
  for i in 0..<testCount:
    let x = rng.rand(-10.0 * PI..10.0 * PI)
    let standardSin = sin(x)
    let lookupSin = fastSin(x)
    let error = abs(standardSin - lookupSin)
    
    maxError = max(maxError, error)
    avgError += error
  
  avgError /= testCount.float
  
  echo &"Test points: {testCount}"
  echo &"Range: -10π to +10π"
  echo &"Max error: {maxError:.2e} ({maxError/1.0:.1f} LSB at 24-bit)"
  echo &"Avg error: {avgError:.2e} ({avgError/1.0:.1f} LSB at 24-bit)"
  echo &"Max error in dB: {20.0 * log10(maxError):.1f} dB"
  echo &"Avg error in dB: {20.0 * log10(avgError):.1f} dB"
  
  # Audio quality assessment
  if maxError < 1e-5:
    echo "✓ Excellent audio quality (>100 dB SNR)"
  elif maxError < 1e-4:
    echo "✓ Very good audio quality (>80 dB SNR)"  
  elif maxError < 1e-3:
    echo "⚠ Good audio quality (>60 dB SNR)"
  else:
    echo "✗ Poor audio quality (<60 dB SNR)"
  
  echo ""

proc performanceComparison() =
  echo "=== Performance Comparison ==="
  
  let iterations = 10_000_000
  var rng = initRand(12345)
  
  # Generate test values in FIR coefficient range
  var testValues = newSeq[float](iterations)
  for i in 0..<iterations:
    testValues[i] = rng.rand(-8.0 * PI..8.0 * PI)  # Typical FIR range
  
  # Benchmark standard sin
  var standardResult = 0.0
  let standardStart = cpuTime()
  for val in testValues:
    standardResult += sin(val)
  let standardTime = cpuTime() - standardStart
  
  # Benchmark fast sin
  var fastResult = 0.0  
  let fastStart = cpuTime()
  for val in testValues:
    fastResult += fastSin(val)
  let fastTime = cpuTime() - fastStart
  
  let speedup = standardTime / fastTime
  let standardOpsPerSec = iterations.float / standardTime
  let fastOpsPerSec = iterations.float / fastTime
  
  echo &"Iterations: {iterations}"
  echo &"Standard sin: {standardTime:.3f}s ({standardOpsPerSec:.0f} ops/sec)"
  echo &"Fast sin:     {fastTime:.3f}s ({fastOpsPerSec:.0f} ops/sec)"
  echo &"Speedup:      {speedup:.2f}x"
  echo &"Results differ by: {abs(standardResult - fastResult):.2e}"
  echo ""

proc coefficientUpdateBenchmark() =
  echo "=== Coefficient Update Performance ==="
  
  let taps = 128
  let updates = 100_000
  
  # Create filters for comparison
  var origFur = initOriginalFur(taps)
  var fastFur = initFur(taps)
  
  # Benchmark original coefficient updates
  let origStart = cpuTime()
  for i in 0..<updates:
    let freq = 0.1 + 0.3 * (i.float / updates.float)
    origFur.lopass(freq)
  let origTime = cpuTime() - origStart
  
  # Benchmark fast coefficient updates
  let fastStart = cpuTime()
  for i in 0..<updates:
    let freq = 0.1 + 0.3 * (i.float / updates.float)
    fastFur.lopass(freq)
  let fastTime = cpuTime() - fastStart
  
  let speedup = origTime / fastTime
  let origUpdatesPerSec = updates.float / origTime
  let fastUpdatesPerSec = updates.float / fastTime
  
  echo &"Filter: {taps} taps"
  echo &"Updates: {updates}"
  echo &"Original:  {origTime:.3f}s ({origUpdatesPerSec:.0f} updates/sec)"
  echo &"Fast sin:  {fastTime:.3f}s ({fastUpdatesPerSec:.0f} updates/sec)"  
  echo &"Speedup:   {speedup:.2f}x coefficient updates"
  
  # Verify coefficients are still close
  origFur.lopass(0.25)
  fastFur.lopass(0.25)
  
  var maxCoeffDiff = 0.0
  for i in 0..<taps:
    let diff = abs(origFur.coeff[i] - fastFur.coeff[i])
    maxCoeffDiff = max(maxCoeffDiff, diff)
  
  echo &"Max coeff difference: {maxCoeffDiff:.2e}"
  echo ""

proc realTimeAudioImpact() =
  echo "=== Real-time Audio Impact ==="
  
  let sampleRate = 44100.0
  let bufferSize = 256
  let numBuffers = 2000  # ~11.6 seconds
  let taps = 64
  
  # Generate test audio
  var testBuffer = newSeq[float](bufferSize)
  for i in 0..<bufferSize:
    testBuffer[i] = sin(2.0 * PI * 440.0 * i.float / sampleRate)
  
  # Test with frequent coefficient updates (every buffer)
  echo "Testing with coefficient updates every buffer:"
  
  # Original implementation
  block:
    var filter = initOriginalFur(taps)
    var totalOutput = 0.0
    
    let startTime = cpuTime()
    for bufferIdx in 0..<numBuffers:
      # Update coefficients (simulating parameter automation)
      let freq = 0.2 + 0.2 * sin(2.0 * PI * bufferIdx.float / 500.0)
      filter.lopass(freq)
      
      # Process buffer
      for sample in testBuffer:
        totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let realtimeRatio = (numBuffers.float * bufferSize.float / sampleRate) / elapsed
    
    echo &"  Original: {elapsed:.3f}s ({realtimeRatio:.1f}x real-time)"
    echo &"  Output: {totalOutput:.6f}"
  
  # Fast sin implementation
  block:
    var filter = initFur(taps)
    var totalOutput = 0.0
    
    let startTime = cpuTime()
    for bufferIdx in 0..<numBuffers:
      # Update coefficients (simulating parameter automation)
      let freq = 0.2 + 0.2 * sin(2.0 * PI * bufferIdx.float / 500.0)
      filter.lopass(freq)
      
      # Process buffer
      for sample in testBuffer:
        totalOutput += filter.process(sample)
    
    let elapsed = cpuTime() - startTime
    let realtimeRatio = (numBuffers.float * bufferSize.float / sampleRate) / elapsed
    
    echo &"  Fast sin: {elapsed:.3f}s ({realtimeRatio:.1f}x real-time)"
    echo &"  Output: {totalOutput:.6f}"

when isMainModule:
  accuracyTest()
  performanceComparison()
  coefficientUpdateBenchmark()
  realTimeAudioImpact()