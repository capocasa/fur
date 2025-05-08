
{.compile: "rtfir.c".}
{.header: "ftfir.h".}

type
  Fur = object
    coeff: ptr float
    buffer: ptr float
    taps: cuint

// Initializes FIR objects of various types
prof initLowpass(fur: ptr Fur, taps: cuint, freq: float)

#bool RTFIR_init_lowpass(RTFIR *Filter,const unsigned int Taps,const double Freq);
#bool RTFIR_init_highpass(RTFIR *Filter,const unsigned int Taps,const double Freq);
#bool RTFIR_init_bandpass(RTFIR *Filter,const unsigned int Taps,const double Low,const double High);
#bool RTFIR_init_bandstop(RTFIR *Filter,const unsigned int Taps,const double Low,const double High);

#// Filters a sample with a FIR object
#double RTFIR_filter(RTFIR *Filter,const double Sample);

#// Deletes a FIR object
#void RTFIR_close(RTFIR *Filter);



