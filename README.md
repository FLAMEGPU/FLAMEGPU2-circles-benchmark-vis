# FLAMEGPU2 Circles Benchmark Visualisation

This repository contains a [FLAME GPU 2](https://github.com/FLAMEGPU/FLAMEGPU2) implementation of the Circles agent based model, to visualise the model benchmarked in [https://github.com/FLAMEGPU/FLAMEGPU2-circles-benchmark](https://github.com/FLAMEGPU/FLAMEGPU2-circles-benchmark) and extract drift data for plotting.

## Benchmark Description and Results

There is a single experiment within this example which mean measures drift of the agents per time step. This gives an indication of population stability and convergence towards a stable state. The communication radius is varied to show how this effects the emergent behaviour of the populations.

If the example is built with the CMAKE `FLAMEGPU_VISUALISATION` option enabled then the experiment runs a single experimental configuration with a fixed communication radius.

An example visualisation can be viewed [on YouTube](https://www.youtube.com/watch?v=ZedroqmOaHU).

[![Circles model visualisation](https://img.youtube.com/vi/ZedroqmOaHU/0.jpg)](https://www.youtube.com/watch?v=ZedroqmOaHU)

The is an example of raw data in the [`sample/data`](sample/data) directory with a description of the machine configurations used to generate it in each directory.

The results below are from a RTX 2080 Ti.

### Drift Experiment

+ Communication Radius is varied between `1.0` and `5.0` with a  step of `1.0`
+ Population size is fixed at `64000`
+ Environment width is fixed at `40.0`
+ The number of simulation steps is `3000`
+ 10 simulations are completed with unique seeds for each communication radius

[![Combined Figure](sample/figures/2080Ti-11.4-471.41/alpha.2-2080Ti-11.4-beltsoff/figure.png)](sample/figures/2080Ti-11.4-471.41/alpha.2-2080Ti-11.4-beltsoff/figure.png)

## Building and Running the 3D Visualisation

Detail of dependencies and the `cmake` build process are described in full in the [FLAMEGPU2-example-template repository](https://github.com/FLAMEGPU/FLAMEGPU2-example-template) and are not repeated here. 
For visualisation purposes, this should be built with visualisation enabled (e.g. `-DFLAMEGPU_VISUALISATION=ON`) and seatbelts off (e.g. `-DFLAMEGPU_SEATBELTS=OFF` passed to the `cmake` configuration step) to disable additional run-time checks.

For example, to build for Volta (`SM_70`) GPUs under Linux:

```bash
# Configure 
cmake . -B build -DCMAKE_BUILD_TYPE=Release -DFLAMEGPU_VISUALISATION=ON -DFLAMEGPU_SEATBELTS=OFF -DCMAKE_CUDA_ARCHITECTURES=70
# Build
cmake --build build -j`nproc` 
```

The generated binary can then be executed to run the visualisation, which will begin paused. Press `p` to unpause (or re-pause) the simulation.

```bash
cd build
./bin/Release/circles-benchmark-vis
```

## Building and Running the Drift Benchmark

Detail of dependencies and the `cmake` build process are described in full in the [FLAMEGPU2-example-template repository](https://github.com/FLAMEGPU/FLAMEGPU2-example-template) and are not repeated here. The benchmark should be built with seatbelts off (e.g. `-DFLAMEGPU_SEATBELTS=OFF` passed to the `cmake` configuration step) to disable additional run-time checks.

For example, to build for Volta (`SM_70`) GPUs under Linux:

```bash
# Configure 
cmake . -B build -DCMAKE_BUILD_TYPE=Release -DFLAMEGPU_SEATBELTS=OFF -DCMAKE_CUDA_ARCHITECTURES=70
# Build
cmake --build build -j`nproc` 
```

Running the generated executable will run the benchmark and generate output files:

```bash
cd build
./bin/Release/circles-benchmark-vis
```

This will produce a number of `.csv` files in the `build` directory.

Note: The `FLAMEGPU2_INC_DIR` environment variable may need to be set to `./_deps/flamegpu2-src/include/` for run-time compilation (RTC) to succeed if the source directory is not automatically found.

## Plotting Results

Figures can be generated from data in CSV files via a python script.

### Dependencies

It is recommended to use python virtual environment or conda environment for plotting dependencies.

I.e. for Linux to install the dependencies into a python3 virtual environment and plot the results from all experiments output to the `build` directory.

```bash
# From the root of the repository
# Create the venv
python3 -m venv .venv
# Activate the venv
source .venv/bin/activate
# Install the dependencies via pip
python3 -m pip install -Ur requirements.txt
# Plot using csv files contained within the build directory
python3 plot_publication.py -i build -o build/figures
# Use -h / --help for more information on optional plotting script parameters.
```

The sample figures were generated from the root directory using

```bash
python3 plot_publication.py -i sample/data/2080Ti-11.4-471.41/alpha.2-2080Ti-11.4-beltsoff -o sample/figures/2080Ti-11.4-471.41/alpha.2-2080Ti-11.4-beltsoff
```
