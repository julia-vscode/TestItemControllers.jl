julia_versions = [
    "1.0",
    "1.1",
    "1.2",
    "1.3",
    "1.4",
    "1.5",
    "1.6",
    "1.7",
    "1.8",
    "1.9",
    "1.10",
    "1.11"
]

for i in julia_versions
    version_path = normpath(joinpath(@__DIR__, "../packages/TestItemServer/app/environments/v$i"))
    mkpath(version_path)
    run(Cmd(`julia +$i --project=. -e 'using Pkg; Pkg.develop(PackageSpec(path="../../.."))'`, dir=version_path))
end

version_path = normpath(joinpath(@__DIR__, "../packages/TestItemServer/app/environments/fallback"))
mkpath(version_path)
run(Cmd(`julia +nightly --project=. -e 'using Pkg; Pkg.develop(PackageSpec(path="../../.."))'`, dir=version_path))