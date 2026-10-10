# Link previews (OpenGraph + Twitter card tags) for Facebook, Bluesky, Mastodon, Slack, … .
# Every page gets a large image card: the event's flyer, else its YouTube thumbnail, else the site image.
og_image_url()=site_url()*"/og-image.png"   # the site's og_image (site.toml) or assets/og-image.png, copied by write_site
const OG_IMAGE_FILE=joinpath(@__DIR__,"..","..","assets","og-image-generic.png")   # without a city; sites set og_image
const OG_IMAGE_SIZE=(1200,630)
"""
    og_image(e) -> (url, alt)

The preview image for an event: flyer → YouTube thumbnail → `og_image_url()`. Squarespace originals can be many MB,
so they get `?format=1500w` (Squarespace's own resizing); a URL that already has a query is left alone.
"""
function og_image(e)
 t=_title(e); flyer=_http(get(e,"flyer_url",nothing))
 if !isempty(flyer)
  occursin(r"^https://images\.squarespace-cdn\.com/[^?#]*$"i,flyer) && (flyer*="?format=1500w")
  return (flyer,"Flyer: $t")
 end
 v=_val(e,"video",nothing)
 if v isa AbstractDict && string(_val(v,"platform",""))=="youtube" && occursin(r"^[A-Za-z0-9_-]{11}$",string(_val(v,"id","")))
  return ("https://i.ytimg.com/vi/$(v["id"])/hqdefault.jpg","Video: $t")
 end
 (og_image_url(),site_name())
end
"The `<meta>` tags for a link preview. All arguments are plain text; escaping happens here."
function _og_head(; title, desc, url, image=og_image_url(), alt=site_name())
 m(p,c)="<meta property=\"$p\" content=\"$(_esc(c))\">"
 n(p,c)="<meta name=\"$p\" content=\"$(_esc(c))\">"
 tags=[m("og:type","website"),m("og:site_name",site_name()),m("og:title",title),m("og:description",desc),m("og:url",url),
  m("og:locale",OG_LOCALE[_lang()]),(m("og:locale:alternate",OG_LOCALE[l]) for l in LANGS if l!=_lang())...,
  m("og:image",image),m("og:image:alt",alt)]
 image==og_image_url() && push!(tags,m("og:image:width",string(OG_IMAGE_SIZE[1])),m("og:image:height",string(OG_IMAGE_SIZE[2])))
 push!(tags,n("twitter:card","summary_large_image"),n("twitter:title",title),n("twitter:description",desc),n("twitter:image",image),n("twitter:image:alt",alt))
 join(tags,"")
end
