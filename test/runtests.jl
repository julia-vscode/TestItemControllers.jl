using TestItemRunner, Logging

ENV["JULIA_DEBUG"] = "TestItemControllers"

@run_package_tests filter = ti -> startswith(ti.filename, @__DIR__)
