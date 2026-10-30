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
# Favicon and home-screen icons: drawn per site by bin/make_icons.jl into the folder `icons` (site.toml) and copied to the
# site root by write_site, with site.webmanifest (Android «Legg til på startskjermen»). Every page with _og_head links them.
const ICON_FILES=["favicon.ico","favicon-32.png","apple-touch-icon.png","icon-192.png","icon-512.png","icon-maskable-512.png"]
const ICONS_DIR=joinpath(@__DIR__,"..","..","assets","icons-generic")   # a «T» at every size; sites set icons
const MANIFEST_FILE="site.webmanifest"
const THEME_COLOUR="#872b49"
"Short name under a home-screen icon («Tango Oslo»)."
_short_name()="Tango "*site_city()
"The web app manifest: name, colours and the home-screen icons (absolute URLs, so every language tree shares one)."
function web_manifest()
 i(f,s;purpose="any")=Dict("src"=>"$(site_url())/$f","sizes"=>"$(s)x$s","type"=>"image/png","purpose"=>purpose)
 Dict("name"=>site_name(),"short_name"=>_short_name(),"start_url"=>site_url()*"/","scope"=>site_url()*"/",
  "display"=>"browser","theme_color"=>THEME_COLOUR,"background_color"=>"#f5f1eb",
  "icons"=>[i("icon-192.png",192),i("icon-512.png",512),i("icon-maskable-512.png",512;purpose="maskable")])
end
"The `<head>` tags for the favicon, the iOS home-screen icon and the manifest."
_icon_head()="<link rel=\"icon\" href=\"$(site_url())/favicon.ico\" sizes=\"32x32\"><link rel=\"icon\" type=\"image/png\" href=\"$(site_url())/favicon-32.png\" sizes=\"32x32\">"*
 "<link rel=\"apple-touch-icon\" href=\"$(site_url())/apple-touch-icon.png\"><link rel=\"manifest\" href=\"$(site_url())/$MANIFEST_FILE\">"*
 "<meta name=\"apple-mobile-web-app-title\" content=\"$(_esc(_short_name()))\"><meta name=\"theme-color\" content=\"$THEME_COLOUR\">"
"The `<meta>` tags for a link preview (and, since every site page has them, the icon tags). All arguments are plain text; escaping happens here."
function _og_head(; title, desc, url, image=og_image_url(), alt=site_name())
 m(p,c)="<meta property=\"$p\" content=\"$(_esc(c))\">"
 n(p,c)="<meta name=\"$p\" content=\"$(_esc(c))\">"
 tags=[m("og:type","website"),m("og:site_name",site_name()),m("og:title",title),m("og:description",desc),m("og:url",url),
  m("og:locale",OG_LOCALE[_lang()]),(m("og:locale:alternate",OG_LOCALE[l]) for l in LANGS if l!=_lang())...,
  m("og:image",image),m("og:image:alt",alt)]
 image==og_image_url() && push!(tags,m("og:image:width",string(OG_IMAGE_SIZE[1])),m("og:image:height",string(OG_IMAGE_SIZE[2])))
 push!(tags,n("twitter:card","summary_large_image"),n("twitter:title",title),n("twitter:description",desc),n("twitter:image",image),n("twitter:image:alt",alt))
 join(tags,"")*_icon_head()
end
