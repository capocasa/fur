# FIR Filter Benchmarks

This directory contains comprehensive benchmarks for the optimized FIR filter implementation.

## Benchmarks

### `sweep_benchmark.nim`
**Primary performance benchmark** - Tests audio rate coefficient updates (worst case scenario)

- **Audio Rate Sweep**: Updates coefficients every sample (40.4x real-time performance)
- **Frequency Sweeps**: Linear, exponential, sinusoidal, and random frequency changes
- **Filter Type Switching**: Performance when switching between lowpass/highpass/bandpass/notch
- **Real-time Simulation**: Typical audio buffer processing with automation
- **Static vs Dynamic**: Comparison of static filtering vs coefficient updates

**Key Result**: 1.78M samples/sec during continuous audio rate coefficient updates

### `profile_benchmark.nim`
Specialized benchmark for performance profiling with perf/profilers

- **Coefficient Update Hotpath**: Sustained CPU load for profiling
- **Mixed Workload**: Combination of coefficient updates + sample processing  
- **Filter Type Switching**: Performance across different filter types
- **Isolated Components**: Pure fastSin performance testing

### `coeff_update_benchmark.nim`
Focused benchmark for coefficient calculation performance

- Isolates coefficient calculation from sample processing
- Tests different tap counts and frequencies
- Useful for optimizing the coefficient calculation algorithms

## Usage

Compile and run benchmarks:

```bash
# Main performance benchmark
nim c -d:release --opt:speed bench/sweep_benchmark.nim
./bench/sweep_benchmark

# Profiling benchmark
nim c -d:release --opt:speed bench/profile_benchmark.nim  
./bench/profile_benchmark

# Coefficient-focused benchmark
nim c -d:release --opt:speed bench/coeff_update_benchmark.nim
./bench/coeff_update_benchmark
```

## Performance Results

The optimized implementation achieves:

- **40.4x real-time performance** during audio rate coefficient updates
- **32% improvement** from precomputed reciprocals optimization  
- **17,000%+ CPU headroom** for typical real-time audio scenarios
- Support for power-of-2 tap counts (8, 16, 32, 64, 128, 256, etc.)

## Optimization History

1. **Circular Buffer**: Power-of-2 masking for branchless operation
2. **Fast Sin Lookup**: 8192-entry table with linear interpolation  
3. **Branch Elimination**: Dual range loops without code duplication
4. **Division Elimination**: Precomputed reciprocals (`1.0 / fi`)
5. **Static Generics**: Compile-time optimization for tap counts