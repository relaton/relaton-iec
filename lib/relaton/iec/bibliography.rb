# frozen_string_literal: true

require_relative "hit_collection"
require "date"

module Relaton
  module Iec
    # Class methods for search IEC standards.
    class Bibliography
      extend Core::ArrayWrapper

      DOCTYPES = %w[TS TR PAS SRD TEC STTR WP Guide OD CS CA].freeze

      class << self
        ##
        # Search for standards entries.
        #
        # @param pubid [Pubid::Iec::Identifier]
        # @param exclude [Array<Symbol>] keys to exclude from comparison
        # @return [Relaton::Iec::HitCollection]
        def search(pubid, exclude: [:year])
          HitCollection.new(pubid).search(exclude: exclude)
        rescue SocketError, OpenSSL::SSL::SSLError => e
          raise Relaton::RequestError, e.message
        end

        # @param code [String] the IEC standard code to look up (e.g. "IEC 8000")
        # @param year [String] the year the standard was published (optional)
        # @param opts [Hash] options; restricted to :all_parts if all-parts
        #   reference is required
        # @return [Relaton::Iec::ItemData, nil]
        def get(code, year = nil, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
          opts[:all_parts] ||= code.match?(/\s\(all parts\)/)
          ref = code.sub(/\s\(all parts\)/, "")
          return iev if ref.casecmp("IEV").zero?

          pubid = Pubid::Iec::Identifier.parse ref.upcase
          pubid.year = year.to_i if year

          ret = iecbib_get(pubid, opts)
          return nil if ret.nil?

          ret = ret.to_most_recent_reference unless pubid.year || opts[:keep_year] ||
            opts[:publication_date_before] || opts[:publication_date_after]
          ret
        end

        private

        def iev(code = "IEC 60050")
          ItemData.new(
            type: "standard",
            fetched: Date.today,
            title: [Bib::Title.new(
              content: "International Electrotechnical Vocabulary", language: "en", script: "Latn"
            )],
            source: [Bib::Uri.new(content: "http://www.electropedia.org")],
            docidentifier: [Bib::Docidentifier.new(content: "#{code}:2011")],
            date: [Bib::Date.new(type: "published", at: "2011")],
            contributor: [Bib::Contributor.new(
              role: [Bib::Contributor::Role.new(type: "publisher")],
              organization: Bib::Organization.new(
                name: [Bib::TypedLocalizedString.new(
                  content: "International Electrotechnical Commission", language: "en", script: "Latn"
                )],
                abbreviation: Bib::LocalizedString.new(content: "IEC", language: "en", script: "Latn"),
                uri: [Bib::Uri.new(content: "www.iec.ch")]
              )
            )],
            language: %w(en fr),
            script: "Latn",
            status: Bib::Status.new(stage: Bib::Status::Stage.new(content: "60")),
            copyright: Bib::Copyright.new(
              from: "2018",
              owner: [Bib::ContributionInfo.new(
                organization: Bib::Organization.new(
                  name: [Bib::TypedLocalizedString.new(
                    content: "International Electrotechnical Commission", language: "en", script: "Latn"
                  )],
                  abbreviation: Bib::LocalizedString.new(content: "IEC", language: "en", script: "Latn"),
                  uri: [Bib::Uri.new(content: "www.iec.ch")]
                )
              )]
            )
          )
        end

        # @param pubid [Pubid::Iec::Identifier]
        # @param opts [Hash]
        # @return [Relaton::Iec::ItemData, nil]
        def iecbib_get(pubid, opts) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
          Util.info "Fetching from Relaton repository ...", key: pubid.to_s
          exclude = opts[:all_parts] ? %i[year part] : %i[year]
          result = search(pubid, exclude: exclude) || return

          if opts[:all_parts]
            ret = result.to_all_parts(pubid.year&.to_s, opts)
            Util.info "Found: `#{ret&.docidentifier&.first&.content}`", key: pubid.to_s if ret
            return ret
          end

          ret = find_match(result, pubid, opts)
          return ret if ret

          provide_tips(pubid, result)
          nil
        end

        # Find exact match considering year and date filters.
        # @param result [Relaton::Iec::HitCollection]
        # @param pubid [Pubid::Iec::Identifier]
        # @param opts [Hash]
        # @return [Relaton::Iec::ItemData, nil]
        def find_match(result, pubid, opts = {}) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
          if pubid.year
            hit = result.detect { |h| h.hit[:id].year == pubid.year }
            return fetch_and_check_date(hit, pubid, opts) if hit
          elsif opts[:publication_date_before] || opts[:publication_date_after]
            candidates = result.select { |h| year_in_range?(h.hit[:id].year.to_i, opts) }
            candidates = candidates.sort_by { |h| -h.hit[:id].year.to_i }
            candidates.each do |h|
              ret = fetch_and_check_date(h, pubid, opts)
              return ret if ret
            end
            return nil
          else
            hit = result.max_by { |h| h.hit[:id].year.to_i }
            return unless hit

            ret = hit.item
            Util.info "Found: `#{ret.docidentifier.first.content}`", key: pubid.to_s
            return ret
          end
          nil
        end

        # Check if a year falls within the date filter range.
        # @param year [Integer]
        # @param opts [Hash]
        # @return [Boolean]
        def year_in_range?(year, opts)
          return false if year.zero?

          if opts[:publication_date_before]
            return false if year > opts[:publication_date_before].year
          end
          if opts[:publication_date_after]
            return false if year < opts[:publication_date_after].year
          end
          true
        end

        # Check if the item's published date falls within the filter range.
        # @param item [Relaton::Iec::ItemData]
        # @param opts [Hash]
        # @return [Boolean]
        def publication_date_in_range?(item, opts)
          pub_date_entry = item.date.find { |d| d.type == "published" }
          return true unless pub_date_entry&.at

          pub_date = pub_date_entry.at.to_date
          return true unless pub_date

          if opts[:publication_date_before]
            return false if pub_date >= opts[:publication_date_before]
          end
          if opts[:publication_date_after]
            return false if pub_date < opts[:publication_date_after]
          end
          true
        end

        # Fetch the item for a hit and check if its publication date is in range.
        # @param hit [Relaton::Iec::Hit]
        # @param pubid [Pubid::Iec::Identifier]
        # @param opts [Hash]
        # @return [Relaton::Iec::ItemData, nil]
        def fetch_and_check_date(hit, pubid, opts)
          ret = hit.item
          if publication_date_in_range?(ret, opts)
            Util.info "Found: `#{ret.docidentifier.first.content}`", key: pubid.to_s
            ret
          end
        end

        # Analyze why no match was found and give helpful tips.
        # @param pubid [Pubid::Iec::Identifier]
        # @param result [Relaton::Iec::HitCollection]
        def provide_tips(pubid, result) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
          Util.info "Not found.", key: pubid.to_s

          # Year mismatch: hits exist but not for the requested year
          if pubid.year && result.any?
            years = result.map { |h| h.hit[:id].year&.to_s }.compact.uniq.sort
            Util.info "TIP: No match for edition year `#{pubid.year}`, " \
                      "but matches exist for `#{years.join('`, `')}`.", key: pubid.to_s
            return
          end

          # Search broadly (exclude year + part) to check for part/type mismatches
          broad = search(pubid, exclude: %i[year part])

          # Part mismatch: no part given but parts exist
          unless pubid.part
            if broad.any?
              parts = broad.map { |h| h.hit[:id].to_s }.uniq.sort
              Util.info "TIP: If you wish to cite all document parts for " \
                        "the reference, use `#{pubid} (all parts)`. " \
                        "Available: `#{parts.join('`, `')}`.", key: pubid.to_s
              return
            end
          end

          # Doctype mismatch: search excluding type to find entries with same number but different type
          type_broad = search(pubid, exclude: %i[year type])
          if type_broad.any?
            types = type_broad.map { |h| h.hit[:id].to_s }.uniq.sort
            Util.info "TIP: No match for type, but matches exist: " \
                      "`#{types.join('`, `')}`.", key: pubid.to_s
          end
        end
      end
    end
  end
end
