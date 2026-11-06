# Release notes guard for ListAll
# Blocks App Store publishing when "What's New" text was not updated for the
# new version: each locale's release_notes.txt must be non-empty and differ
# from the text of every earlier App Store version.

module ReleaseNotesGuard
  # Returns { locale => contents } for each <metadata_dir>/<locale>/release_notes.txt
  def self.read_local(metadata_dir)
    Dir.glob(File.join(metadata_dir, '*', 'release_notes.txt')).sort.to_h do |path|
      [File.basename(File.dirname(path)), File.read(path)]
    end
  end

  # local: { locale => text }, previous: { locale => [texts of earlier versions] }.
  # Locales known to App Store Connect but missing locally are checked too:
  # deliver would leave their old text in place.
  # Returns a list of human-readable problems.
  def self.problems(local:, previous:)
    (local.keys | previous.keys).sort.filter_map do |locale|
      text = normalize(local[locale])
      if text.empty?
        "#{locale}: release_notes.txt is missing or empty"
      elsif Array(previous[locale]).any? { |old| normalize(old) == text }
        "#{locale}: release_notes.txt is identical to an earlier App Store version's \"What's New\""
      end
    end
  end

  # Compare on content only: line endings, trailing spaces, blank-line padding
  # and Unicode composition (ä vs a + ¨) differ between the repo files and
  # what App Store Connect returns.
  def self.normalize(text)
    text.to_s.unicode_normalize(:nfc).gsub("\r\n", "\n").lines.map(&:rstrip).join("\n").strip
  end
end
