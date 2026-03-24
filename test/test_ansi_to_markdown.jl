@testitem "ansi_to_markdown: plain text passthrough" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    @test ansi_to_markdown("hello world") == "hello world"
    @test ansi_to_markdown("") == ""
    @test ansi_to_markdown("no escapes here\nline two") == "no escapes here\nline two"
end

@testitem "ansi_to_markdown: bold" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    # Bold on/off
    @test ansi_to_markdown("\e[1mhello\e[22m world") == "**hello** world"
    # Bold via reset
    @test ansi_to_markdown("\e[1mhello\e[0m world") == "**hello** world"
    # Unclosed bold
    @test ansi_to_markdown("\e[1mhello") == "**hello**"
end

@testitem "ansi_to_markdown: italic" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    @test ansi_to_markdown("\e[3mtext\e[23m rest") == "*text* rest"
    @test ansi_to_markdown("\e[3mtext\e[0m rest") == "*text* rest"
    # Unclosed italic
    @test ansi_to_markdown("\e[3mtext") == "*text*"
end

@testitem "ansi_to_markdown: bold + italic" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    # Bold then italic, closed separately
    @test ansi_to_markdown("\e[1mbold \e[3mbolditalic\e[23m bold\e[22m") == "**bold *bolditalic* bold**"
    # Reset closes both
    @test ansi_to_markdown("\e[1m\e[3mboth\e[0m") == "***both***"
end

@testitem "ansi_to_markdown: colors stripped" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    # Standard foreground color
    @test ansi_to_markdown("\e[31mred\e[39m text") == "red text"
    # Bright foreground
    @test ansi_to_markdown("\e[91mbright red\e[39m") == "bright red"
    # 256-color
    @test ansi_to_markdown("\e[38;5;196mcolor\e[0m") == "color"
end

@testitem "ansi_to_markdown: combined params" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    # Bold + red in single escape
    @test ansi_to_markdown("\e[1;31mhello\e[0m") == "**hello**"
    # Multiple params with bold and italic
    @test ansi_to_markdown("\e[1;3;31mboth\e[0m") == "***both***"
end

@testitem "ansi_to_markdown: idempotent on already-clean text" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    md = "**bold** and *italic*"
    @test ansi_to_markdown(md) == md
end

@testitem "ansi_to_markdown: duplicate bold on is idempotent" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    # Two bold-on in a row should only emit one **
    @test ansi_to_markdown("\e[1m\e[1mhello\e[22m") == "**hello**"
end

@testitem "ansi_to_markdown: realistic showerror output" begin
    include(joinpath(@__DIR__, "..", "testprocess", "TestItemServer", "src", "ansi_to_markdown.jl"))

    # Simulate what showerror produces for MethodError with color
    # Type name is bold, argument types may also be styled
    input = "\e[1mMethodError\e[22m: no method matching \e[1mfoo\e[22m(\e[1m::Int64\e[22m)"
    expected = "**MethodError**: no method matching **foo**(**::Int64**)"
    @test ansi_to_markdown(input) == expected
end
