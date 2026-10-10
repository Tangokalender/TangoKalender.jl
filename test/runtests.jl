# The tests run as the Oslo site (test/fixtures/site/site.toml once the data has moved out; site.toml until then),
# so URLs, the site name and the city in the output are Oslo's. Tests of other sites set their own with `_with_site`.
using TangoKalender
const SITE_TOML=let f=joinpath(@__DIR__,"fixtures","site","site.toml"); isfile(f) ? f : joinpath(@__DIR__,"..","site.toml") end
TangoKalender._with_site(TangoKalender.load_site(SITE_TOML)) do
 include("tests.jl")
end
