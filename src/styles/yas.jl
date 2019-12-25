# YAS style !!!

using Cassette

Cassette.@context YASCtx

function yasformat(s::AbstractString, kwargs...)
    Cassette.overdub(Cassette.disablehooks(YASCtx()), format_text, s, kwargs...)
end


function Cassette.overdub(::YASCtx, ::typeof(nestable), cst::CSTParser.EXPR)
    nest_assignment(cst) && return false
    true
end

function Cassette.overdub(::YASCtx, ::typeof(p_kw), cst::CSTParser.EXPR, s::State)
    @info "why u not printing ughhhhhhh"
    t = FST(cst, nspaces(s))
    for a in cst
        add_node!(t, pretty(a, s), s, join_lines = true)
    end
    t
end

@inline function _call(cst::CSTParser.EXPR, s::State)
    t = FST(cst, nspaces(s))
    add_node!(t, pretty(cst[1], s), s)
    add_node!(t, pretty(cst[2], s), s, join_lines = true)

    for (i, a) in enumerate(cst.args[3:end])
        if CSTParser.is_comma(a) && i < length(cst) - 3 && !is_punc(cst[i+3])
            add_node!(t, pretty(a, s), s, join_lines = true)
            add_node!(t, Placeholder(1), s)
        else
            add_node!(t, pretty(a, s), s, join_lines = true)
        end
    end
    t
end

function Cassette.overdub(::YASCtx, ::typeof(p_call), cst::CSTParser.EXPR, s::State)
    _call(cst, s)
end

function Cassette.overdub(::YASCtx, ::typeof(p_ref), cst::CSTParser.EXPR, s::State)
    _call(cst, s)
end

function Cassette.overdub(::YASCtx, ::typeof(p_curly), cst::CSTParser.EXPR, s::State)
    _call(cst, s)
end

function Cassette.overdub(::YASCtx, ::typeof(n_call!), fst::FST, s::State)
    line_offset = s.line_offset
    fst.indent = line_offset + sum(length.(fst[1:2]))

    @info "" fst.typ fst.force_nest

    if fst.force_nest
        for (i, n) in enumerate(fst.nodes)
            if n.typ === NEWLINE
                s.line_offset = fst.indent
            elseif n.typ === PLACEHOLDER
                fst[i] = Newline(length = n.len)
                s.line_offset = fst.indent
            elseif n.typ === TRAILINGSEMICOLON
                n.val = ""
                n.len = 0
                nest!(n, s)
            elseif n.typ === CSTParser.Parameters
                n.force_nest = true
                n.extra_margin = 1
                nest!(n, s)
            else
                n.extra_margin = 1
                nest!(n, s)
            end
        end
        return
    end

    for (i, n) in enumerate(fst.nodes)
        if n.typ === PLACEHOLDER
            margin = s.line_offset + length(fst[i+1]) 
            if i + 1 == length(fst.nodes) - 1 
                margin += fst.extra_margin
            end
            if margin > s.margin  || fst[i+1].typ === NOTCODE
                fst[i] = Newline(length = n.len)
                s.line_offset = fst.indent
            end
        elseif n.typ === NEWLINE
            s.line_offset = fst.indent
        elseif n.typ === TRAILINGSEMICOLON
            n.val = ""
            n.len = 0
            nest!(n, s)
        else
            n.extra_margin = 1
            nest!(n, s)
        end
    end
end

