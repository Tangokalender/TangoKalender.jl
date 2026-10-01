#!/usr/bin/env julia
# Thin wrapper around `tangokalender build`; see `julia -m TangoKalender --help`.
using Pkg; Pkg.activate(joinpath(@__DIR__,".."); io=devnull)
using TangoKalender
exit(TangoKalender.main(["build"; ARGS]))
