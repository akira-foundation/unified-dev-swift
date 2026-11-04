function blank(c) {
  return c == "\n" ? "\n" : " "
}

function hashes(count,    result, k) {
  result = ""
  for (k = 0; k < count; k++) result = result "#"
  return result
}

function spaces(count,    result, k) {
  result = ""
  for (k = 0; k < count; k++) result = result " "
  return result
}

function hashRun(text, from,    k) {
  k = 0
  while (substr(text, from + k, 1) == "#") k++
  return k
}

function sanitise(text,    n, i, c, d, e, state, out, depth, level, fence, escape, skip) {
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
      if (c == "/" && d == "*") { state = 2; depth = 1; out = out "  "; i += 2; continue }
      level = 0
      if (c == "#") level = hashRun(text, i)
      if (substr(text, i + level, 1) == "\"") {
        fence = hashes(level)
        escape = "\\" fence
        if (substr(text, i + level + 1, 2) == "\"\"") {
          state = 4
          out = out spaces(level + 3)
          i += level + 3
        } else {
          state = 3
          out = out spaces(level + 1)
          i += level + 1
        }
        continue
      }
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
      if (c == "/" && d == "*") { depth++; out = out "  "; i += 2; continue }
      if (c == "*" && d == "/") {
        depth--
        if (depth == 0) state = 0
        out = out "  "
        i += 2
        continue
      }
      out = out blank(c)
      i++
      continue
    }
    if (substr(text, i, length(escape)) == escape) {
      skip = length(escape)
      out = out spaces(skip) blank(substr(text, i + skip, 1))
      i += skip + 1
      continue
    }
    if (state == 3 && substr(text, i, 1 + length(fence)) == "\"" fence) {
      state = 0
      out = out spaces(1 + length(fence))
      i += 1 + length(fence)
      continue
    }
    if (state == 4 && substr(text, i, 3 + length(fence)) == "\"\"\"" fence) {
      state = 0
      out = out spaces(3 + length(fence))
      i += 3 + length(fence)
      continue
    }
    if (state == 3 && c == "\n") {
      unreadable = 1
      state = 0
    }
    out = out blank(c)
    i++
  }
  if (state != 0) unreadable = 1
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
  unreadable = 1
  return 0
}

function lineOf(text, index_,    head) {
  head = substr(text, 1, index_)
  return gsub(/\n/, "\n", head) + 1
}

function ownText(text, open, last,    inner, innerOpen, innerClose) {
  inner = substr(text, open + 1, last - open - 1)
  while (match(inner, /(^|[^A-Za-z0-9_])(AgentLaunch|WorkspaceNamerLaunch)\(/)) {
    innerOpen = RSTART + RLENGTH - 1
    innerClose = closing(inner, innerOpen)
    if (innerClose == 0) return inner
    inner = substr(inner, 1, innerOpen - 1) " " substr(inner, innerClose + 1)
  }
  return inner
}

{
  source = source $0 "\n"
}

END {
  clean = sanitise(source)
  found = ""
  position = 1
  while (position <= length(clean)) {
    rest = substr(clean, position)
    if (!match(rest, /(^|[^A-Za-z0-9_])(AgentLaunch|WorkspaceNamerLaunch)\(/)) break
    open = position + RSTART + RLENGTH - 2
    close_ = closing(clean, open)
    if (close_ == 0) break
    if (ownText(clean, open, close_) !~ /AgentAccountEnvironment\.apply\(/) found = found lineOf(clean, open) "\n"
    position = open + 1
  }
  if (unreadable) {
    print "unreadable" > "/dev/stderr"
    exit 2
  }
  printf "%s", found
}
