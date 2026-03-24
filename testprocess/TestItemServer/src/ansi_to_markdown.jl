function ansi_to_markdown(s::AbstractString)
    buf = IOBuffer()
    bold = false
    italic = false
    i = 1
    while i <= ncodeunits(s)
        c = @inbounds s[i]
        if c == '\e' && i + 1 <= ncodeunits(s) && @inbounds(s[i+1]) == '['
            # Parse CSI sequence: \e[ <params> m
            j = i + 2
            while j <= ncodeunits(s) && (@inbounds(s[j]) == ';' || '0' <= @inbounds(s[j]) <= '9')
                j += 1
            end
            if j <= ncodeunits(s) && @inbounds(s[j]) == 'm'
                # Parse semicolon-separated parameters
                params_str = SubString(s, i + 2, j - 1)
                params = isempty(params_str) ? Int[0] : Int[parse(Int, p) for p in split(params_str, ';')]
                for param in params
                    if param == 1  # bold on
                        if !bold
                            bold = true
                            write(buf, "**")
                        end
                    elseif param == 22 || param == 0  # bold off or reset
                        if param == 0
                            if italic
                                italic = false
                                write(buf, '*')
                            end
                            if bold
                                bold = false
                                write(buf, "**")
                            end
                        else
                            if bold
                                bold = false
                                write(buf, "**")
                            end
                        end
                    elseif param == 3  # italic on
                        if !italic
                            italic = true
                            write(buf, '*')
                        end
                    elseif param == 23  # italic off
                        if italic
                            italic = false
                            write(buf, '*')
                        end
                    end
                    # All other params (colors, underline, etc.) are silently stripped
                end
                i = j + 1
                continue
            end
            # Not a valid SGR sequence — pass through
        end
        write(buf, c)
        i = nextind(s, i)
    end
    # Close any unclosed formatting
    if italic
        write(buf, '*')
    end
    if bold
        write(buf, "**")
    end
    return String(take!(buf))
end
