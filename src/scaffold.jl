# Files a city's data repo gets from the package: the GitHub issue forms (rendered from templates/ISSUE_TEMPLATE with
# the site's URL and city). The forms' labels are the parser's keys (FORM_FIELDS, CORRECTION_FIELDS, …), so they are
# kept here with the code and copied into each data repo by `tangokalender templates`.
const TEMPLATE_DIR=joinpath(@__DIR__,"..","templates")
"Fill a template's `{{site_url}}` and `{{city}}` from the current site."
render_template(text::AbstractString)=replace(text,"{{site_url}}"=>site_url(),"{{city}}"=>site_city())
"""
    write_templates(dir=".") -> files

Write the issue forms for the current site into `dir/.github/ISSUE_TEMPLATE/` (overwriting the package's forms,
leaving other files there alone).
"""
function write_templates(dir::AbstractString=".")
 src=joinpath(TEMPLATE_DIR,"ISSUE_TEMPLATE"); out=joinpath(dir,".github","ISSUE_TEMPLATE"); mkpath(out)
 [(f=joinpath(out,n); write(f,render_template(read(joinpath(src,n),String))); f) for n in sort(readdir(src)) if endswith(n,".yml")]
end
