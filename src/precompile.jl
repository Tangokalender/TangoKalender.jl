# Precompile workload: run the CLI commands once on a small temporary tree while the package is precompiled, so
# `tangokalender …` / `julia -m TangoKalender …` don't compile everything on each run. `geocode` is left out (network).
using PrecompileTools: @setup_workload, @compile_workload
@setup_workload begin
 form="""
 ### Tittel\n\nØvingskveld\n\n### Type\n\nKurs og practica\n\n### Dato\n\n2026-10-20\n\n### Starttid\n\n19:00\n\n### Sluttid\n\n22:00
 ### Gjentas\n\nUkentlig\n\n### Gjentas til\n\n2026-11-17\n\n### Unntatt datoer\n\n2026-11-03\n\n### Sted\n\nLøkka Dans
 ### Adresse\n\nThorvald Meyers gate 1, Oslo\n\n### Arrangør\n\nLøkka Tango\n\n### DJ\n\n_No response_\n\n### Lærere\n\nLærer A
 ### Pris (kr)\n\n_No response_\n\n### Studentpris (kr)\n\n_No response_\n\n### Kurspris (kr)\n\n200\n\n### Musikk\n\n- [X] Tradisjonell
 ### Flyer\n\n_No response_\n\n### Video\n\nhttps://vimeo.com/123456789\n\n### Lenke\n\nhttps://example.org/ovingskveld
 ### Beskrivelse\n\nKurs, så practica.\n\n### Samtykke\n\n- [X] Personer som er nevnt har godtatt å bli oppført.
 """
 @compile_workload begin
  _register_term_faces()   # __init__ hasn't run yet
  mktempdir() do d
   root=joinpath(d,"events"); body=joinpath(d,"issue.md"); write(body,form)
   v=joinpath(d,"venues.json")   # absent: no maps, and the repo's venues.json is never read
   redirect_stdout(devnull) do; redirect_stderr(devnull) do
    main(["from-issue",body,"--root=$root","--report=$(joinpath(d,"report.md"))","--today=2026-10-01"])
    main(["validate",root,"--venues=$v"])
    main(["edit","øvingskveld","--root=$root","--all"])
    main(["edit","øvingskveld","type:class","--root=$root","--all","--preview","class_price_nok=250","venue.name=Ny sal"])
    main(["edit","øvingskveld","--root=$root","--all","--dry-run","status=cancelled"])
    main(["edit","øvingskveld","--root=$root","--from=2026-11-01","teachers=[\"A\",\"B\"]"])
    main(["site",root,joinpath(d,"_site"),"--venues=$v"])
    main(["build",root,joinpath(d,"index.html"),"--venues=$v"])
   end end
  end
 end
end
