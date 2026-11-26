#!/usr/bin/env ruby
#
# Created by Nicolas Bush on 08/10/2026.
#

# Relevé des traductions d'une branche : clés de localisation ajoutées, modifiées ou supprimées
# depuis son point de départ, et textes sans clé (`L10n.missingTranslation`) ajoutés ou retirés.
# La comparaison part de `git merge-base <branche d'intégration> HEAD` et va jusqu'au working tree,
# modifications non commitées comprises. Avec une ref, elle part de `git merge-base <branche
# d'intégration> <ref>` et va jusqu'à cette ref : relevé d'un ticket déjà fusionné, sans checkout.
#
# Usage : ruby .claude/scripts/ticket-translations.rb [branche d'intégration, `releases.integration_branch` par défaut] [ref]
# Dossier des fichiers de localisation : `translations.localizables` de `.claude/workflow.yml`.

require "open3"
require "yaml"

# Ordre d'affichage : langue de référence d'abord, les autres ensuite par ordre alphabétique.
REFERENCE_LANGUAGE = "fr"
ENTRY = /\A"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";/
MISSING_TRANSLATION = /L10n\.missingTranslation\(\s*"((?:[^"\\]|\\.)*)"/

def git(*arguments)
  output, status = Open3.capture2("git", *arguments)
  abort("git #{arguments.join(' ')} a échoué") unless status.success?
  output
end

# Clé → valeur d'un `Localizable.strings`, une entrée par ligne (format de l'export de l'outil de traduction).
def parse(content)
  content.each_line.each_with_object({}) do |line, entries|
    match = ENTRY.match(line.strip)
    entries[match[1]] = match[2] if match
  end
end

def entries_at(ref, path)
  content, status = Open3.capture2("git", "show", "#{ref}:#{path}", err: File::NULL)
  status.success? ? parse(content) : {}
end

def current_entries(path)
  File.exist?(path) ? parse(File.read(path)) : {}
end

def display(value)
  return "(absente, à traduire)" if value.nil?
  return "(vide, à traduire)" if value.empty?

  "\"#{value}\""
end

root = git("rev-parse", "--show-toplevel").strip
Dir.chdir(root)
# Config du workflow, lue depuis la racine du dépôt.
CONFIG = YAML.load_file(".claude/workflow.yml")
LOCALIZABLES = CONFIG.dig("translations", "localizables") || abort("Clé translations.localizables absente de .claude/workflow.yml")
integration_branch = ARGV.fetch(0) { CONFIG.dig("releases", "integration_branch") || "develop" }
# Ref contrôlée : un commit déjà intégré (ticket-check), sinon le working tree.
target = ARGV[1]
base = git("merge-base", integration_branch, target || "HEAD").strip

languages = Dir.glob("#{LOCALIZABLES}/*.lproj").map { |directory| File.basename(directory, ".lproj") }
languages = languages.sort_by { |language| [language == REFERENCE_LANGUAGE ? 0 : 1, language] }
before = {}
after = {}
languages.each do |language|
  path = "#{LOCALIZABLES}/#{language}.lproj/Localizable.strings"
  before[language] = entries_at(base, path)
  after[language] = target ? entries_at(target, path) : current_entries(path)
end

keys_before = before.values.flat_map(&:keys).uniq
keys_after = after.values.flat_map(&:keys).uniq
added = (keys_after - keys_before).sort
removed = (keys_before - keys_after).sort
modified = (keys_after & keys_before).select do |key|
  languages.any? { |language| before[language][key] != after[language][key] }
end.sort

puts "Relevé des traductions : #{base[0, 9]} (merge-base #{integration_branch}) → #{target || 'working tree'}"

puts "", "Clés ajoutées (#{added.size}) :"
added.each do |key|
  puts "- #{key}"
  languages.each { |language| puts "  #{language} : #{display(after[language][key])}" }
end

puts "", "Clés modifiées (#{modified.size}) :"
modified.each do |key|
  puts "- #{key}"
  languages.each do |language|
    old_value = before[language][key]
    new_value = after[language][key]
    if old_value == new_value
      # Une langue inchangée alors qu'une autre a changé est probablement à retraduire.
      puts "  #{language} : inchangée #{display(new_value)}"
    else
      puts "  #{language} : #{display(old_value)} → #{display(new_value)}"
    end
  end
end

puts "", "Clés supprimées (#{removed.size}) :"
removed.each { |key| puts "- #{key} (#{REFERENCE_LANGUAGE} : #{display(before[REFERENCE_LANGUAGE][key])})" }

# Textes sans clé : lignes ajoutées ou retirées du code Swift, working tree compris sans ref.
diff = git("diff", "--unified=0", base, *target, "--", "*.swift")
missing_added = []
missing_removed = []
diff.each_line do |line|
  next if line.start_with?("+++", "---")

  texts = line.scan(MISSING_TRANSLATION).flatten
  missing_added.concat(texts) if line.start_with?("+")
  missing_removed.concat(texts) if line.start_with?("-")
end
untracked = target ? [] : git("ls-files", "--others", "--exclude-standard", "--", "*.swift").split("\n")
untracked.each { |path| missing_added.concat(File.read(path).scan(MISSING_TRANSLATION).flatten) }

puts "", "Textes sans clé ajoutés, L10n.missingTranslation (#{missing_added.uniq.size}) :"
missing_added.uniq.sort.each { |text| puts "- \"#{text}\"" }
puts "", "Textes sans clé retirés (#{missing_removed.uniq.size}) :"
missing_removed.uniq.sort.each { |text| puts "- \"#{text}\"" }
