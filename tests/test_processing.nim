import std/[unittest, math, random, sequtils, strformat]
import ../src/fur
import original_fur

const epsilon = 1.3e-7  # Maximum achievable processing precision with linear interpolation

proc generateTestSignal(length: int, sampleRate: float = 44100.0): seq[float] =
  result = newSeq[float](length)
  var rng = initRand(12345) # Fixed seed for reproducible tests
  
  for i in 0..<length:
    let t = i.float / sampleRate
    # Mix of different frequency components + noise
    result[i] = 0.5 * sin(2.0 * PI * 440.0 * t) +     # 440 Hz tone
                0.3 * sin(2.0 * PI * 1000.0 * t) +    # 1 kHz tone  
                0.2 * sin(2.0 * PI * 5000.0 * t) +    # 5 kHz tone
                0.1 * (rng.rand(2.0) - 1.0)           # noise

proc processSignal(filter: var auto, signal: seq[float]): seq[float] =
  result = newSeq[float](signal.len)
  for i, sample in signal:
    result[i] = filter.process(sample)

proc compareOutputs(orig: seq[float], opt: seq[float], name: string) =
  check orig.len == opt.len
  var maxDiff = 0.0
  var avgDiff = 0.0
  
  for i in 0..<orig.len:
    let diff = abs(orig[i] - opt[i])
    maxDiff = max(maxDiff, diff)
    avgDiff += diff
    
    if diff > epsilon:
      echo &"Output mismatch in {name} at sample {i}: orig={orig[i]}, opt={opt[i]}, diff={diff}"
    check diff <= epsilon
  
  avgDiff /= orig.len.float
  echo &"{name}: max_diff={maxDiff}, avg_diff={avgDiff}"

suite "Processing Comparison Tests":
  
  test "Lowpass processing 64 taps":
    let signal = generateTestSignal(1000)
    let testFreqs = [0.1, 0.2, 0.25, 0.4]
    
    for freq in testFreqs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.lopass(freq)
      optFur.lopass(freq)
      
      let origOutput = processSignal(origFur, signal)
      let optOutput = processSignal(optFur, signal)
      
      compareOutputs(origOutput, optOutput, &"lowpass freq={freq}")
  
  test "Highpass processing 64 taps":
    let signal = generateTestSignal(1000)
    let testFreqs = [0.1, 0.2, 0.25, 0.4]
    
    for freq in testFreqs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.hipass(freq)
      optFur.hipass(freq)
      
      let origOutput = processSignal(origFur, signal)
      let optOutput = processSignal(optFur, signal)
      
      compareOutputs(origOutput, optOutput, &"highpass freq={freq}")
  
  test "Bandpass processing 64 taps":
    let signal = generateTestSignal(1000)
    let testConfigs = [(0.1, 0.3), (0.15, 0.35), (0.2, 0.4)]
    
    for (lo, hi) in testConfigs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.bandpass(hi, lo)
      optFur.bandpass(hi, lo)
      
      let origOutput = processSignal(origFur, signal)
      let optOutput = processSignal(optFur, signal)
      
      compareOutputs(origOutput, optOutput, &"bandpass lo={lo} hi={hi}")
  
  test "Notch processing 64 taps":
    let signal = generateTestSignal(1000)
    let testConfigs = [(0.1, 0.3), (0.15, 0.35), (0.2, 0.4)]
    
    for (lo, hi) in testConfigs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.notch(hi, lo)
      optFur.notch(hi, lo)
      
      let origOutput = processSignal(origFur, signal)
      let optOutput = processSignal(optFur, signal)
      
      compareOutputs(origOutput, optOutput, &"notch lo={lo} hi={hi}")

  test "Impulse response comparison":
    var origFur = initOriginalFur(64)
    var optFur = initFur[64]()
    
    origFur.lopass(0.25)
    optFur.lopass(0.25)
    
    # Generate impulse signal
    var impulse = newSeq[float](128)
    impulse[0] = 1.0
    
    let origResponse = processSignal(origFur, impulse)
    let optResponse = processSignal(optFur, impulse)
    
    compareOutputs(origResponse, optResponse, "impulse response")

  test "DC response comparison":
    var origFur = initOriginalFur(64)
    var optFur = initFur[64]()
    
    origFur.lopass(0.5) # Should pass DC
    optFur.lopass(0.5)
    
    # Generate DC signal
    let dcSignal = repeat(1.0, 200)
    
    let origResponse = processSignal(origFur, dcSignal)
    let optResponse = processSignal(optFur, dcSignal)
    
    compareOutputs(origResponse, optResponse, "DC response")
    
    # Check steady-state DC gain (should be close to 1.0)
    let steadyStateOrig = origResponse[^50..^1].sum() / 50.0
    let steadyStateOpt = optResponse[^50..^1].sum() / 50.0
    
    check abs(steadyStateOrig - 1.0) < 0.01
    check abs(steadyStateOpt - 1.0) < 0.01
    check abs(steadyStateOrig - steadyStateOpt) < epsilon

  test "Long sequence processing":
    let longSignal = generateTestSignal(10000)
    
    var origFur = initOriginalFur(128)
    var optFur = initFur[128]()
    
    origFur.lopass(0.2)
    optFur.lopass(0.2)
    
    let origOutput = processSignal(origFur, longSignal)
    let optOutput = processSignal(optFur, longSignal)
    
    compareOutputs(origOutput, optOutput, "long sequence")