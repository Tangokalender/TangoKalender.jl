#!/bin/sh
# Build the trimmed `tangoedit` executable (= `tangokalender edit` without JSONSchema) with JuliaC into build/tangoedit/.
#   bin/build_tangoedit.sh            then: build/tangoedit/bin/tangoedit TERM… [KEY=VALUE…] [--root=events]
set -eu
cd "$(dirname "$0")/.."
# General registry first (a fresh depot, e.g. on CI, has none and resolve doesn't add it); resolve picks up new
# TangoKalender deps (app/Manifest.toml is not committed)
julia --project=app -e 'using Pkg; isempty(Pkg.Registry.reachable_registries()) && Pkg.Registry.add("General"); Pkg.resolve(); Pkg.instantiate()'
rm -rf build/tangoedit   # JuliaC's bundle step refuses to overwrite an existing bundle
julia --project=app -e 'using JuliaC; JuliaC.main(ARGS)' -- \
  --output-exe tangoedit --bundle build/tangoedit --trim=safe --experimental --project=app app/tangoedit.jl
