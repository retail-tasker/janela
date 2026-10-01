module AdrHelper
  # A link to a decision's page on this site. The slug carries the title, so
  # it is looked up by number rather than written out, and a number with no
  # decision raises: a reference that points nowhere should fail the page, not
  # ship as a dead link.
  def adr_link(number)
    padded = format("%03d", number)
    doc = Doc.decisions.find { |decision| decision.number == padded } or
      raise ArgumentError, "no ADR #{padded} in docs/decisions"
    link_to "ADR #{padded}", doc_path(doc.slug)
  end
end
