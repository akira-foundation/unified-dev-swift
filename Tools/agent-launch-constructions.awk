function blank(c) {
  return c == "\n" ? "\n" : " "
}

function sanitise(text,    n, i, c, d, e, state, out) {
  n = length(text)
  state = 0
  out = ""
  i = 1
  while (i <= n) {
    c = substr(text, i, 1)
    d = substr(text, i + 1, 1)
    e = substr(text, i + 2, 1)
    if (state == 0) {
      if (c == "/" && d == "/") { state = 1; out = out "  "; i += 2; continue }
      if (c == "/" && d == "*") { state = 2; out = out "  "; i += 2; continue }
      if (c == "\"" && d == "\"" && e == "\"") { state = 4; out = out "   "; i += 3; continue }
      if (c == "\"") { state = 3; out = out " "; i++; continue }
      out = out c
      i++
      continue
    }
    if (state == 1) {
      if (c == "\n") state = 0
      out = out blank(c)
      i++
      continue
    }
    if (state == 2) {
      if (c == "*" && d == "/") { state = 0; out = out "  "; i += 2; continue }
      out = out blank(c)
      i++
      continue
    }
    if (state == 3) {
      if (c == "\\") { out = out " " blank(d); i += 2; continue }
      if (c == "\"") state = 0
      if (c == "\n") state = 0
      out = out blank(c)
      i++
      continue
    }
    if (c == "\"" && d == "\"" && e == "\"") { state = 0; out = out "   "; i += 3; continue }
    out = out blank(c)
    i++
  }
  return out
}

function closing(text, open,    n, i, c, depth) {
  n = length(text)
  depth = 0
  for (i = open; i <= n; i++) {
    c = substr(text, i, 1)
    if (c == "(") depth++
    if (c == ")") {
      depth--
      if (depth == 0) return i
    }
  }
  return n
}

function lineOf(text, index_,    head) {
  head = substr(text, 1, index_)
  return gsub(/\n/, "\n", head) + 1
}

{
  source = source $0 "\n"
}

END {
  clean = sanitise(source)
  position = 1
  while (position <= length(clean)) {
    rest = substr(clean, position)
    if (!match(rest, /(AgentLaunch|WorkspaceNamerLaunch)\(/)) break
    start = position + RSTART - 1
    open = start + RLENGTH - 1
    span = substr(clean, open, closing(clean, open) - open + 1)
    if (span !~ /AgentAccountEnvironment\.apply\(/) print lineOf(clean, start)
    position = open + 1
  }
}
