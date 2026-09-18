# A page of Janela's own documentation, read from the gem rather than copied
# into this site. The decisions are the files in docs/decisions, the guides are
# the ones beside them, and nothing here is written twice, so nothing can drift
# from what ships inside the gem.
class Doc
  ROOT = Janela::Engine.root.join("docs")

  # Listed under Documentation, in the sidebar and on the docs index.
  GUIDES = {
    "multi-tenancy" => "Fitting Janela into a multi tenant application"
  }.freeze

  # A guide file that is not listed as one. The naming story has a page of its
  # own at /name, which renders this same markdown, so listing it under
  # Documentation as well put one piece of writing on the site twice. It stays
  # in the catalogue because /name reads it through here, and routes.rb sends
  # /docs/naming to /name rather than 404ing a link someone already has.
  UNLISTED = {
    "naming" => "Naming Things Is Hard"
  }.freeze

  PAGES = GUIDES.merge(UNLISTED).freeze

  # The sidebar is narrow and this is the one guide title too long to sit on
  # one line there; the page itself still carries the full title above, this
  # is only what the nav says. The footer already calls this guide "Multi
  # tenancy" (see shared/_footer), so that is the shorter label rather than a
  # second phrase for the same page.
  NAV_LABELS = {
    "multi-tenancy" => "Multi tenancy"
  }.freeze

  attr_reader :slug

  # Built once and frozen: a slug that is not in here is a 404, which is also
  # why a request can never reach a path of its own choosing.
  def self.catalogue
    @catalogue ||= begin
      pages = PAGES.keys.index_with { |slug| ROOT.join("#{slug}.md") }
      ROOT.glob("decisions/*.md").sort.each do |path|
        slug = path.basename(".md").to_s
        pages[slug] = path unless slug == "INDEX"
      end
      pages.select { |_slug, path| path.exist? }.freeze
    end
  end

  def self.find!(slug)
    new(slug, catalogue.fetch(slug) { raise ActiveRecord::RecordNotFound, "no such document" })
  end

  def self.guides
    GUIDES.keys.map { |slug| find!(slug) }
  end

  def self.decisions
    (catalogue.keys - PAGES.keys).map { |slug| find!(slug) }.sort_by { |doc| doc.number.to_i }
  end

  def initialize(slug, path)
    @slug = slug
    @path = path
  end

  def number
    slug[/\A(\d+)/, 1]
  end

  def decision?
    number.present?
  end

  # The first heading, which every one of these files has, rather than a title
  # repeated in the front matter where the two could disagree.
  def title
    heading = body[/^#\s+(.+)$/, 1] || slug.humanize
    # The index already shows the number, so "ADR 012: Frames and Panes Are
    # Data" would say it twice.
    heading.sub(/\AADR\s+\d+:\s*/, "")
  end

  def nav_label
    NAV_LABELS.fetch(slug, title)
  end

  def status
    front["Status"]
  end

  def date
    front["Date"]
  end

  def topics
    front["Topics"].to_s.split(",").map(&:strip).reject(&:empty?)
  end

  def html
    Kramdown::Document.new(without_title, input: "GFM", auto_ids: true, hard_wrap: false).to_html.html_safe
  end

  private
    def parsed
      @parsed ||= begin
        raw = @path.read
        if raw.start_with?("---\n")
          _, front, body = raw.split(/^---\s*$\n/, 3)
          [ YAML.safe_load(front, permitted_classes: [ Date ]) || {}, body.to_s ]
        else
          [ {}, raw ]
        end
      end
    end

    def front
      parsed.first
    end

    def body
      parsed.last
    end

    # The page renders the title itself, so the copy in the prose would be a
    # second one.
    def without_title
      body.sub(/^#\s+.+$\n/, "")
    end
end
