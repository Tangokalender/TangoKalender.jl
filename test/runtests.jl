# The tests run as the Oslo test site (test/fixtures/site/site.toml, with a frozen copy of the Oslo data),
# so URLs, the site name and the city in the output are Oslo's. Tests of other sites set their own with `_with_site`.
using TangoKalender
const SITE_TOML=joinpath(@__DIR__,"fixtures","site","site.toml")
TangoKalender._with_site(TangoKalender.load_site(SITE_TOML)) do
 include("tests.jl")
end
