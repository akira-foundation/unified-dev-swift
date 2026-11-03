extension CanvasMarkdownPage {
    static let stylesheet = """
    :root { color-scheme: light dark; }
    body { font: -apple-system-body; font-family: -apple-system, system-ui, sans-serif; line-height: 1.5; \
    max-width: 52rem; margin: 0 auto; padding: 1.5rem; color: #1d1d1f; background: #fff; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 0.5em; }
    p, ul, ol, blockquote, pre, table { margin: 0.75em 0; }
    code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.9em; \
    background: rgba(127,127,127,0.15); padding: 0.1em 0.3em; border-radius: 4px; }
    pre { background: rgba(127,127,127,0.12); padding: 0.75rem 1rem; border-radius: 8px; overflow-x: auto; }
    pre code { background: none; padding: 0; }
    blockquote { border-left: 3px solid rgba(127,127,127,0.5); padding-left: 1rem; color: rgba(127,127,127,1); }
    table { border-collapse: collapse; }
    th, td { border: 1px solid rgba(127,127,127,0.4); padding: 0.35rem 0.7rem; }
    th { background: rgba(127,127,127,0.12); }
    img { max-width: 100%; }
    a { color: #0066cc; }
    ul.tasks { list-style: none; padding-left: 0.5rem; }
    hr { border: 0; border-top: 1px solid rgba(127,127,127,0.4); margin: 1.5em 0; }
    @media (prefers-color-scheme: dark) {
      body { color: #f5f5f7; background: #1e1e1e; }
      a { color: #4da3ff; }
    }
    """
}
