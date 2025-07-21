import std/[unittest, math, sequtils, strformat]
import ../src/fur
import original_fur

const EPSILON = 1e-4  # Relaxed for fast sin lookup table precision

proc compareCoeffs[T](orig: seq[float], opt: array[T, float], name: string) =
  check orig.len == opt.len
  for i in 0..<orig.len:
    let diff = abs(orig[i] - opt[i])
    if diff > EPSILON:
      echo &"Coefficient mismatch in {name} at index {i}: orig={orig[i]}, opt={opt[i]}, diff={diff}"
    check diff <= EPSILON

suite "Coefficient Comparison Tests":
  
  test "Lowpass filter coefficients 64 taps":
    let testFreqs = [0.1, 0.2, 0.25, 0.3, 0.4, 0.5]
    
    for freq in testFreqs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.lopass(freq)
      optFur.lopass(freq)
      
      compareCoeffs(origFur.coeff, optFur.coeff, &"lowpass freq={freq}")
  
  test "Highpass filter coefficients 64 taps":
    let testFreqs = [0.1, 0.2, 0.25, 0.3, 0.4, 0.5]
    
    for freq in testFreqs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.hipass(freq)
      optFur.hipass(freq)
      
      compareCoeffs(origFur.coeff, optFur.coeff, &"highpass freq={freq}")
  
  test "Bandpass filter coefficients 64 taps":
    let testParams = [
      (0.1, 0.2), (0.15, 0.35), (0.2, 0.4), (0.1, 0.5), (0.25, 0.45)
    ]
    
    for (lo, hi) in testParams:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.bandpass(hi, lo)
      optFur.bandpass(hi, lo)
      
      compareCoeffs(origFur.coeff, optFur.coeff, &"bandpass lo={lo} hi={hi}")
  
  test "Notch filter coefficients 64 taps":
    let testParams = [
      (0.1, 0.2), (0.15, 0.35), (0.2, 0.4), (0.1, 0.5), (0.25, 0.45)
    ]
    
    for (lo, hi) in testParams:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.notch(hi, lo)
      optFur.notch(hi, lo)
      
      compareCoeffs(origFur.coeff, optFur.coeff, &"notch lo={lo} hi={hi}")

  test "Edge case frequencies":
    let edgeFreqs = [0.001, 0.01, 0.05, 0.45, 0.49, 0.499]
    
    for freq in edgeFreqs:
      var origFur = initOriginalFur(64)
      var optFur = initFur[64]()
      
      origFur.lopass(freq)
      optFur.lopass(freq)
      
      compareCoeffs(origFur.coeff, optFur.coeff, &"edge lowpass freq={freq}")