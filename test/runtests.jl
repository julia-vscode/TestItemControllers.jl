using TestItemRunner

@run_package_tests filter = ti -> startswith(ti.filename, @__DIR__)
