import std/[times, stats, sequtils, strformat, random]
import ../src/fur
import original_fur

proc benchmarkFilter[T](filter: var T, samples: seq[float], iterations: int = 1): float =
  let start = cpuTime()
  
  for iter in 0..<iterations:
    for sample in samples:
      discard filter.process(sample)
  
  let elapsed = cpuTime() - start
  return elapsed

proc generateBenchmarkSignal(length: int): seq[float] =
  result = newSeq[float](length)
  var rng = initRand(42)
  
  for i in 0..<length:
    result[i] = rng.rand(2.0) - 1.0

proc runBenchmarkSuite() =
  echo "=== FIR Filter Performance Benchmark ==="
  echo ""
  
  let signalLengths = [1000, 10000, 100000]
  let tapCounts = [16, 32, 64, 128, 256]
  let iterations = 10
  
  for signalLength in signalLengths:
    echo &"Signal length: {signalLength} samples"
    echo "Tap Count | Original (ms) | Optimized (ms) | Speedup | Samples/sec (opt)"
    echo "----------|---------------|----------------|---------|------------------"
    
    let testSignal = generateBenchmarkSignal(signalLength)
    
    for taps in tapCounts:
      var origTimes: seq[float]
      var optTimes: seq[float]
      
      # Benchmark original implementation
      for i in 0..<iterations:
        var origFilter = initOriginalFur(taps)
        origFilter.lopass(0.25)
        
        let origTime = benchmarkFilter(origFilter, testSignal)
        origTimes.add(origTime * 1000.0) # Convert to ms
      
      # Benchmark optimized implementation  
      for i in 0..<iterations:
        var optFilter = initFur(taps)
        optFilter.lopass(0.25)
        
        let optTime = benchmarkFilter(optFilter, testSignal)
        optTimes.add(optTime * 1000.0) # Convert to ms
      
      let origMean = origTimes.mean()
      let optMean = optTimes.mean()
      let speedup = origMean / optMean
      let samplesPerSec = signalLength.float / (optMean / 1000.0)
      
      echo &"{taps:>8} | {origMean:>11.3f} | {optMean:>12.3f} | {speedup:>5.2f}x | {samplesPerSec:>12.0f}"
    
    echo ""
  
  # Memory allocation benchmark
  echo "=== Memory Allocation Benchmark ==="
  echo "Testing filter creation overhead..."
  
  let numFilters = 10000
  
  block:
    let start = cpuTime()
    for i in 0..<numFilters:
      discard initOriginalFur(64)
    let elapsed = cpuTime() - start
    echo &"Original: {numFilters} filters created in {elapsed*1000:.3f}ms ({elapsed*1000000/numFilters.float:.1f}μs per filter)"
  
  block:
    let start = cpuTime()  
    for i in 0..<numFilters:
      discard initFur(64)
    let elapsed = cpuTime() - start
    echo &"Optimized: {numFilters} filters created in {elapsed*1000:.3f}ms ({elapsed*1000000/numFilters.float:.1f}μs per filter)"
  
  echo ""
  
  # Cache performance test
  echo "=== Cache Performance Test ==="
  echo "Testing with different tap counts to show cache effects..."
  
  let largeTapCounts = [64, 128, 256, 512, 1024, 2048]
  let cacheTestSignal = generateBenchmarkSignal(50000)
  
  echo "Tap Count | Optimized (ms) | Samples/sec | Cache Efficiency"
  echo "----------|----------------|-------------|------------------"
  
  var baselineTime = 0.0
  for taps in largeTapCounts:
    var optFilter = initFur(taps)
    optFilter.lopass(0.25)
    
    let optTime = benchmarkFilter(optFilter, cacheTestSignal) * 1000.0
    let samplesPerSec = cacheTestSignal.len.float / (optTime / 1000.0)
    
    if baselineTime == 0.0:
      baselineTime = optTime
    
    let efficiency = baselineTime / optTime * 100.0
    echo &"{taps:>8} | {optTime:>12.3f} | {samplesPerSec:>9.0f} | {efficiency:>14.1f}%"

when isMainModule:
  runBenchmarkSuite()