# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'
require_relative '../lib/release_notes_guard'

RSpec.describe ReleaseNotesGuard do
  describe '.problems' do
    it 'accepts notes that differ from every earlier version' do
      local = { 'en-US' => "New stuff\n", 'fi' => "Uutta\n" }
      previous = { 'en-US' => ['Old stuff', 'Older stuff'], 'fi' => ['Vanhaa'] }

      expect(described_class.problems(local: local, previous: previous)).to be_empty
    end

    it 'rejects notes identical to any earlier version, not only the latest' do
      local = { 'en-US' => 'Older stuff', 'fi' => 'Uutta' }
      previous = { 'en-US' => ['Old stuff', 'Older stuff'], 'fi' => ['Vanhaa'] }

      expect(described_class.problems(local: local, previous: previous)).to eq(
        ["en-US: release_notes.txt is identical to an earlier App Store version's \"What's New\""]
      )
    end

    it 'ignores whitespace and line ending differences when comparing' do
      local = { 'en-US' => "Old\r\n\r\n• stuff  \n\n" }
      previous = { 'en-US' => ["Old\n\n• stuff"] }

      expect(described_class.problems(local: local, previous: previous).size).to eq(1)
    end

    it 'treats composed and decomposed umlauts as equal' do
      local = { 'fi' => "Lisää" }
      previous = { 'fi' => ["Lisää"] }

      expect(described_class.problems(local: local, previous: previous).size).to eq(1)
    end

    it 'skips earlier versions that had no notes' do
      expect(described_class.problems(local: { 'fi' => 'Uutta' }, previous: { 'fi' => [nil] })).to be_empty
    end

    it 'rejects empty notes and locales that exist only in App Store Connect' do
      local = { 'en-US' => "  \n" }
      previous = { 'en-US' => ['Old'], 'fi' => ['Vanhaa'] }

      expect(described_class.problems(local: local, previous: previous)).to eq(
        ['en-US: release_notes.txt is missing or empty',
         'fi: release_notes.txt is missing or empty']
      )
    end
  end

  describe '.read_local' do
    it 'reads release_notes.txt from each locale directory' do
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, 'en-US'))
        FileUtils.mkdir_p(File.join(dir, 'screenshots'))
        File.write(File.join(dir, 'en-US', 'release_notes.txt'), "Hello\n")

        expect(described_class.read_local(dir)).to eq('en-US' => "Hello\n")
      end
    end
  end
end
