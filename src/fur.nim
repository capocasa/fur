import std/[math, macros]

const
  TWO_PI = 2.0 * PI
  INV_PI = 1.0 / PI
  
  # Fast sin lookup table constants
  SIN_TABLE_SIZE = 8192  # Must be power of 2, covers full sinc range
  SIN_TABLE_RANGE = 20.0 * PI  # Cover -10π to +10π for sinc calculations  
  SIN_TABLE_OFFSET = SIN_TABLE_RANGE / 2.0  # Center at 0
  SIN_TABLE_MASK = SIN_TABLE_SIZE - 1
  SIN_SCALE_FACTOR = float(SIN_TABLE_SIZE - 1) / SIN_TABLE_RANGE

# Generate sin lookup table at compile time
const sinTable = block:
  # Compile-time power-of-2 assertion
  when (SIN_TABLE_SIZE and (SIN_TABLE_SIZE - 1)) != 0:
    {.error: "SIN_TABLE_SIZE must be power of 2".}
  
  var table: array[SIN_TABLE_SIZE, float]
  for i in 0..<SIN_TABLE_SIZE:
    let x = (float(i) / float(SIN_TABLE_SIZE - 1)) * SIN_TABLE_RANGE - SIN_TABLE_OFFSET
    table[i] = sin(x)
  table

proc fastSin*(x: float): float {.inline.} =
  ## Ultra-fast sin lookup with linear interpolation
  ## Optimized for FIR coefficient calculation - covers -10π to +10π range
  ## Used for sinc function: sin(π*f*n) where f is normalized frequency
  
  # Convert to table coordinates  
  let tablePos = (x + SIN_TABLE_OFFSET) * SIN_SCALE_FACTOR
  let index = int(tablePos)
  let fraction = tablePos - float(index)
  
  # Branchless linear interpolation with mask for wraparound
  let y0 = sinTable[index and SIN_TABLE_MASK]
  let y1 = sinTable[(index + 1) and SIN_TABLE_MASK]
  
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
  assert freq >= 0.0 and freq <= 0.5
  freq

proc lopass*[T: static int](fur: var Fur[T], freq: float) =
  let limitedFreq = limit(freq)
  const w = T div 2
  let twoFreq = 2.0 * limitedFreq
  let twoPiFreq = TWO_PI * limitedFreq
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = twoFreq
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let sincVal = fastSin(twoPiFreq * fi) * INV_PI * invFi
      fur.coeff[i + w] = sincVal

proc lopass*[T: static int](freq: float): Fur[T] =
  result = initFur[T]()
  result.lopass(freq)

proc hipass*[T: static int](fur: var Fur[T], freq: float) =
  let limitedFreq = limit(freq)
  const w = T div 2
  let twoFreq = 2.0 * limitedFreq
  let twoPiFreq = TWO_PI * limitedFreq
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = 1.0 - twoFreq
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let sincVal = -fastSin(twoPiFreq * fi) * INV_PI * invFi
      fur.coeff[i + w] = sincVal

proc hipass*[T: static int](freq: float): Fur[T] =
  result = initFur[T]()
  result.hipass(freq)

proc bandpass*[T: static int](fur: var Fur[T], hi: float, lo: float) =
  let limitedHi = limit(hi)
  let limitedLo = limit(lo)
  const w = T div 2
  let twoPiHi = TWO_PI * limitedHi
  let twoPiLo = TWO_PI * limitedLo
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = TWO_PI * (limitedHi - limitedLo) * INV_PI
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let hiSin = fastSin(twoPiHi * fi)
      let loSin = fastSin(twoPiLo * fi)
      let sincVal = (hiSin - loSin) * INV_PI * invFi
      fur.coeff[i + w] = sincVal

proc bandpass*[T: static int](hi: float, lo: float): Fur[T] =
  result = initFur[T]()
  result.bandpass(hi, lo)

proc notch*[T: static int](fur: var Fur[T], hi: float, lo: float) =
  let limitedHi = limit(hi)
  let limitedLo = limit(lo)
  const w = T div 2
  let twoPiHi = TWO_PI * limitedHi
  let twoPiLo = TWO_PI * limitedLo
  
  # Handle center coefficient (i=0) separately
  fur.coeff[w] = 1.0 + TWO_PI * (limitedLo - limitedHi) * INV_PI
  
  # Process all non-center coefficients with precomputed reciprocals
  for r in [(-w)..<0, 1..<w]:
    for i in r:
      let fi = i.float
      let invFi = 1.0 / fi
      let loSin = fastSin(twoPiLo * fi)
      let hiSin = fastSin(twoPiHi * fi)
      let sincVal = (loSin - hiSin) * INV_PI * invFi
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