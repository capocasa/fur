import std/[math]

type
  OriginalFur* = object
    coeff*: seq[float]
    buffer*: seq[float]
    taps*: int

proc initOriginalFur*(taps: int): OriginalFur =
  result.coeff = newSeq[float](taps)
  result.buffer = newSeq[float](taps)
  result.taps = taps
  result.coeff[0] = 1.0

template limit(freq: float)=
  assert freq >= 0.0 and freq <= 0.5

template lopass*(fur: var OriginalFur, freq: float) =
  let w = fur.taps div 2
  fur.coeff[w] = 0.1
  for i in -w..w-1:
    if i == 0:
      fur.coeff[w] = 2 * freq
    else:
      fur.coeff[i+w]=sin(2 * PI * freq * i.float) / (i.float * PI)

template lopass*(taps: int, freq: float) =
  initOriginalFur(taps).lopass(float)

template hipass*(fur: var OriginalFur, freq: float) =
  limit(freq)
  let w = fur.taps div 2
  for i in -w..w-1:
    if i == 0:
      fur.coeff[w] = 1.0 - 2 * freq
    else:
      fur.coeff[i+w] = -sin(2 * PI * freq * i.float) / (i.float * PI)

template hipass*(taps: int, freq: float) =
  initOriginalFur(taps).hipass(float)

template bandpass*(fur: var OriginalFur, hi: float, lo: float) =
  limit(hi)
  limit(lo)
  let w = fur.taps div 2
  for i in -w..w-1:
    if i == 0:
      fur.coeff[w] = ((2 * PI * hi) - (2 * PI * lo)) / PI
    else:
      fur.coeff[i+w]= (sin(2 * PI * hi * i.float) - sin(2 * PI * lo * i.float)) / (i.float * PI)

template bandpass*(taps: int, freq: float) =
  initOriginalFur(taps).bandpass(float)

template notch*(fur: var OriginalFur, hi: float, lo: float) =
  limit(hi)
  limit(lo)
  let w = fur.taps div 2
  for i in -w..w-1:
    if i == 0:
      fur.coeff[w] = 1 + ((2 * PI * lo) - (2 * PI * hi)) / PI
    else:
      fur.coeff[i+w] = (sin(2 * PI * lo * i.float) - sin(2 * PI * hi * i.float)) / (i.float * PI)

template notch*(taps: int, freq: float) =
  initOriginalFur(taps).notch(float)

proc process*(fur: var OriginalFur, sample: float): float =
    copyMem(addr fur.buffer[1], addr fur.buffer[0], (fur.buffer.len-1) * sizeof(float))
    fur.buffer[0]=sample
    for i in 0..fur.taps-1:
      result += fur.buffer[i] * fur.coeff[i]