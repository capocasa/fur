import std/[unittest, math, sequtils]
import ../src/fur

const EPSILON = 1e-4  # Relaxed for fast sin lookup table precision

suite "Edge Case Tests":
  
  test "Power-of-2 requirement check":
    # These should work
    discard initFur[8]()
    discard initFur[16]()
    discard initFur[32]()
    discard initFur[64]()
    discard initFur[128]()

  test "Boundary frequencies":
    var fur = initFur[32]()
    
    # Test very low frequencies (should not crash)
    fur.lopass(0.001)
    check not fur.coeff.anyIt(it.isNaN)
    
    # Test near-Nyquist frequencies
    fur.lopass(0.499)
    check not fur.coeff.anyIt(it.isNaN)
    
    # Test maximum frequency
    fur.lopass(0.5)
    check not fur.coeff.anyIt(it.isNaN)

  test "Zero frequency handling":
    var fur = initFur[16]()
    
    expect AssertionDefect:
      fur.lopass(0.0)
    
    expect AssertionDefect:
      fur.hipass(0.0)

  test "Invalid frequency ranges":
    var fur = initFur[16]()
    
    # Negative frequencies should fail
    expect AssertionDefect:
      fur.lopass(-0.1)
    
    # Frequencies > 0.5 should fail
    expect AssertionDefect:
      fur.lopass(0.6)
    
    # Invalid bandpass ranges
    expect AssertionDefect:
      fur.bandpass(0.2, 0.1)  # hi < lo should fail

  test "Filter coefficient sum properties":
    var fur = initFur[64]()
    
    # Lowpass at 0.5 should have coefficients sum to ~1
    fur.lopass(0.5)
    let lowpassSum = fur.coeff.sum()
    check abs(lowpassSum - 1.0) < 0.01
    
    # Highpass at very low frequency should sum to ~0
    fur.hipass(0.01) 
    let highpassSum = fur.coeff.sum()
    check abs(highpassSum) < 0.1  # More tolerant for lookup table precision

  test "Processing with extreme values":
    var fur = initFur[32]()
    fur.lopass(0.25)
    
    # Test with very large input
    let largeOutput = fur.process(1000.0)
    check not largeOutput.isNaN
    
    # Test with very small input
    let smallOutput = fur.process(1e-20)
    check not smallOutput.isNaN
    
    # Test with negative input
    let negOutput = fur.process(-100.0)
    check not negOutput.isNaN

  test "Multiple filter updates":
    var fur = initFur[64]()
    
    # Rapidly change filter parameters
    for i in 0..<100:
      let freq = 0.1 + 0.3 * (i.float / 100.0)
      fur.lopass(freq)
      
      # Process a sample after each update
      let output = fur.process(sin(2.0 * PI * freq * i.float))
      check not output.isNaN

  test "Buffer wraparound":
    var fur = initFur[8]()  # Small buffer for quick wraparound
    fur.lopass(0.25)
    
    # Process enough samples to wrap around buffer multiple times
    var outputs: seq[float]
    for i in 0..<32:  # 4x buffer size
      outputs.add(fur.process(sin(2.0 * PI * 0.1 * i.float)))
    
    # All outputs should be valid
    for output in outputs:
      check not output.isNaN

  test "Coefficient symmetry":
    var fur = initFur[64]()
    fur.lopass(0.3)
    
    # FIR coefficients should be symmetric around center
    let center = 32
    for i in 0..<(center-1):  # Avoid out of bounds
      let leftCoeff = fur.coeff[center - 1 - i]
      let rightCoeff = fur.coeff[center + 1 + i]
      check abs(leftCoeff - rightCoeff) < EPSILON