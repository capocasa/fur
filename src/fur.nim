import std/[math, macros]

const
  twoPi = 2.0 * PI
  invPi = 1.0 / PI
  
  # Fast sin lookup table constants
  sinTableSize = 8192  # Must be power of 2
  sinTableRange = 2.0 * PI  # Cover 0 to 2π, let integer wrapping handle periodicity
  sinTableMask = sinTableSize - 1
  sinScaleFactor = float(sinTableSize) / sinTableRange

# Generate sin lookup table at compile time
const sinTable = block:
  # Compile-time power-of-2 assertion
  when (sinTableSize and (sinTableSize - 1)) != 0:
    {.error: "sinTableSize must be power of 2".}
  
  var table: array[sinTableSize, float]
  for i in 0..<sinTableSize:
    let x = (float(i) / float(sinTableSize)) * sinTableRange
    table[i] = sin(x)
  table

proc fastSin*(x: float): float {.inline.} =
  ## Ultra-fast sin lookup with linear interpolation
  ## Optimized for FIR coefficient calculation using 2π periodicity
  ## Used for sinc function: sin(π*f*n) where f is normalized frequency
  
  # Scale input to table coordinates, let integer wrapping handle periodicity
  let tablePos = x * sinScaleFactor
  let index = int(tablePos)
  let fraction = tablePos - float(index)
  
  # Branchless linear interpolation with mask for wraparound
  let y0 = sinTable[index and sinTableMask]
  let y1 = sinTable[(index + 1) and sinTableMask]
  
  result = y0 + fraction * (y1 - y0)

type
  Fur*[T: static int] = object
    coeff*: array[T, float]
    buffer*: array[T, float]
    writePos*: int
    mask*: int

proc initFur*[T: static int](): Fur[T] =
  assert (T and (T - 1)) == 0, "taps must be power of 2 for branchless operation"
  result.writePos = 0
  result.mask = T - 1
  result.coeff[T div 2] = 1.0

proc limit(freq: float): float {.inline.} =
  assert freq > 0.0 and freq <= 0.5
  freq

proc lopass*[T: static int](fur: var Fur[T], freq: float) =
  let limitedFreq = limit(freq)
  const w = T div 2
  let twoFreq = 2.0 * limitedFreq
  let twoPiFreq = twoPi * limitedFreq
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = twoFreq
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let sincVal = fastSin(twoPiFreq * fi) * invPi * invFi
      fur.coeff[i + w] = sincVal

proc lopass*[T: static int](freq: float): Fur[T] =
  result = initFur[T]()
  result.lopass(freq)

proc hipass*[T: static int](fur: var Fur[T], freq: float) =
  let limitedFreq = limit(freq)
  const w = T div 2
  let twoFreq = 2.0 * limitedFreq
  let twoPiFreq = twoPi * limitedFreq
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = 1.0 - twoFreq
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let sincVal = -fastSin(twoPiFreq * fi) * invPi * invFi
      fur.coeff[i + w] = sincVal

proc hipass*[T: static int](freq: float): Fur[T] =
  result = initFur[T]()
  result.hipass(freq)

proc bandpass*[T: static int](fur: var Fur[T], hi: float, lo: float) =
  let limitedHi = limit(hi)
  let limitedLo = limit(lo)
  assert limitedHi > limitedLo
  const w = T div 2
  let twoPiHi = twoPi * limitedHi
  let twoPiLo = twoPi * limitedLo
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = twoPi * (limitedHi - limitedLo) * invPi
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let hiSin = fastSin(twoPiHi * fi)
      let loSin = fastSin(twoPiLo * fi)
      let sincVal = (hiSin - loSin) * invPi * invFi
      fur.coeff[i + w] = sincVal

proc bandpass*[T: static int](hi: float, lo: float): Fur[T] =
  result = initFur[T]()
  result.bandpass(hi, lo)

proc notch*[T: static int](fur: var Fur[T], hi: float, lo: float) =
  let limitedHi = limit(hi)
  let limitedLo = limit(lo)
  assert limitedHi > limitedLo
  const w = T div 2
  let twoPiHi = twoPi * limitedHi
  let twoPiLo = twoPi * limitedLo
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = 1.0 + twoPi * (limitedLo - limitedHi) * invPi
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let loSin = fastSin(twoPiLo * fi)
      let hiSin = fastSin(twoPiHi * fi)
      let sincVal = (loSin - hiSin) * invPi * invFi
      fur.coeff[i + w] = sincVal

proc notch*[T: static int](hi: float, lo: float): Fur[T] =
  result = initFur[T]()
  result.notch(hi, lo)

proc process*[T: static int](fur: var Fur[T], sample: float): float {.inline.} =
  fur.buffer[fur.writePos] = sample
  
  var sum = 0.0
  var bufIdx = fur.writePos
  
  for i in 0..<T:
    sum += fur.buffer[bufIdx] * fur.coeff[i]
    bufIdx = (bufIdx - 1) and fur.mask
  
  fur.writePos = (fur.writePos + 1) and fur.mask
  result = sum