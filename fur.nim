
{.compile: "rtfir.c".}
{.passl: "-lm" }
type
  Fur* = ref object
    coeff*: ptr float
    buffer*: ptr float
    taps*: cuint

proc initLowpass*(fur: Fur, taps: cuint, freq: float) {.importc: "RTFIR_init_lowpass".}
proc process*(fur: Fur, sample: float): float {.importc: "RTFIR_filter"}

#bool RTFIR_init_lowpass(RTFIR *Filter,const unsigned int Taps,const double Freq);
#bool RTFIR_init_highpass(RTFIR *Filter,const unsigned int Taps,const double Freq);
#bool RTFIR_init_bandpass(RTFIR *Filter,const unsigned int Taps,const double Low,const double High);
#bool RTFIR_init_bandstop(RTFIR *Filter,const unsigned int Taps,const double Low,const double High);

#// Filters a sample with a FIR object
#double RTFIR_filter(RTFIR *Filter,const double Sample);

#// Deletes a FIR object
#void RTFIR_close(RTFIR *Filter);



