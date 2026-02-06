# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands

```bash
bundle install           # Install dependencies
rake spec                # Run all tests (or just `rspec`)
rspec spec/relaton_iec_spec.rb           # Run single test file
rspec spec/relaton_iec_spec.rb:69        # Run test at specific line
bin/console              # Interactive Ruby console with gem loaded
```

## Architecture Overview

relaton-iec is a Ruby gem that retrieves IEC (International Electrotechnical Commission) standards metadata. It's part of the Relaton family of bibliographic gems.

### Data Flow

1. **Search/Get requests** go through `IecBibliography.get(code, year, opts)` or `.search(ref, year)`
2. `HitCollection` queries an index file from GitHub (relaton/relaton-data-iec)
3. Individual `Hit` objects fetch full YAML documents from the same GitHub repository
4. Results are parsed into `IecBibliographicItem` objects

### Key Classes

- **IecBibliography** ([lib/relaton_iec/iec_bibliography.rb](lib/relaton_iec/iec_bibliography.rb)) - Main entry point for searching and fetching standards
- **IecBibliographicItem** ([lib/relaton_iec/iec_bibliographic_item.rb](lib/relaton_iec/iec_bibliographic_item.rb)) - Extends `RelatonIsoBib::IsoBibliographicItem` with IEC-specific attributes (function, updates_document_type, accessibility_color_inside, cen_processing, secretary, interest_to_committees)
- **HitCollection** ([lib/relaton_iec/hit_collection.rb](lib/relaton_iec/hit_collection.rb)) - Manages search results from the index
- **Hit** ([lib/relaton_iec/hit.rb](lib/relaton_iec/hit.rb)) - Single search result; fetches full document on demand from GitHub
- **DataFetcher** ([lib/relaton_iec/data_fetcher.rb](lib/relaton_iec/data_fetcher.rb)) - Fetches documents from IEC Harmonized API (requires credentials)
- **Processor** ([lib/relaton_iec/processor.rb](lib/relaton_iec/processor.rb)) - Relaton framework integration
- **DocumentIdentifier** ([lib/relaton_iec/document_identifier.rb](lib/relaton_iec/document_identifier.rb)) - Extends `RelatonBib::DocumentIdentifier` to store `Pubid::Iec::Identifier` objects for proper ID manipulation

### Pubid::Iec Integration

The gem uses [pubid-iec](https://github.com/metanorma/pubid-iec) for parsing and manipulating IEC document identifiers.

**Key usage patterns:**

- `Pubid::Iec::Identifier.parse(ref)` - Parse a reference string into a structured identifier
- Parsed identifiers support manipulation: `.part=`, `.year=`, `.all_parts=`
- `DocumentIdentifier` stores `Pubid::Iec::Identifier` objects in `@id` for primary identifiers
- Falls back to string manipulation for unparseable references

**Example:**

```ruby
pubid = Pubid::Iec::Identifier.parse("IEC 80000-1:2022")
pubid.part = nil      # Remove part
pubid.year = nil      # Remove year
pubid.all_parts = true # Mark as all parts
pubid.to_s            # "IEC 80000 (all parts)"
pubid.urn.to_s        # URN representation
```

### URN Conversion

The module provides `RelatonIec.code_to_urn(code, lang)` and `RelatonIec.urn_to_code(urn)` for converting between document identifiers and URN format.

### Testing

- Uses RSpec with VCR for HTTP interaction recording
- VCR cassettes stored in `spec/vcr_cassettes/`
- Tests use webmock for HTTP stubbing

### DataFetcher Environment Variables

When fetching from IEC Harmonized API directly:

- `IEC_HAPI_PROJ_PUBS_KEY` - API key
- `IEC_HAPI_PROJ_PUBS_SECRET` - API secret
