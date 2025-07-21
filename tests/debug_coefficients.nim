import std/[math, strformat]
import ../src/fur
import original_fur

proc compareCoefficients() =
  echo "=== Coefficient Comparison Debug ==="
  
  let taps = 16
  let freq = 0.25
  
  var origFur = initOriginalFur(taps)
  var optFur = initFur(taps)
  
  origFur.lopass(freq)
  optFur.lopass(freq)
  
  echo &"Comparing {taps}-tap lowpass at freq={freq}"
  echo ""
  
  for i in 0..<taps:
    let orig = origFur.coeff[i]
    let opt = optFur.coeff[i]
    let diff = abs(orig - opt)
    
    let status = if diff < 1e-12: "✓" else: "✗"
    echo &"[{i:2}] orig={orig:15.12f} opt={opt:15.12f} diff={diff:.2e} {status}"
  
  echo ""

when isMainModule:
  compareCoefficients()