#!/bin/sh
# Build the trimmed `tangoedit` executable (= `tangokalender edit` without JSONSchema) with JuliaC into build/tangoedit/.
#   bin/build_tangoedit.sh            then: build/tangoedit/bin/tangoedit TERM… [KEY=VALUE…] [--root=events]
set -eu
cd "$(dirname "$0")/.."
julia --project=app -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'   # resolve: picks up new TangoKalender deps (the manifest is not committed)
julia --project=app -e 'using JuliaC; JuliaC.main(ARGS)' -- \
  --output-exe tangoedit --bundle build/tangoedit --trim=safe --experimental --project=app app/tangoedit.jl
