; extends

; Highlight html`...` tagged templates as HTML.
(
  (call_expression
    function: (identifier) @_tag
    arguments: ((template_string) @injection.content
      (#set! injection.include-children)
      (#set! injection.language "html")))
  (#eq? @_tag "html")
)
