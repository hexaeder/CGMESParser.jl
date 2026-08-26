# Shared paths to the bundled CGMES datasets.
DATA = joinpath(pkgdir(CGMESParser), "test", "data")
datapath(sub...) = joinpath(DATA, sub...)

# Every directory holding profile XML files, used by the tests that should hold for any
# dataset regardless of what the grid inside it looks like.
all_dataset_dirs() = [path for (path, _, files) in walkdir(DATA) if any(endswith(".xml"), files)]
