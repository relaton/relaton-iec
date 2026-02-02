# frozen_string_literal: true

module Relaton
  module Iec
    # Hit.
    class Hit < Core::Hit
      GHURL = "https://raw.githubusercontent.com/relaton/relaton-data-iec/refs/heads/data-v2/"

      attr_writer :item

      # Parse page.
      # @return [Relaton::Iec::ItemData]
      def item
        @item ||= begin
          url = "#{GHURL}#{hit[:file]}"
          resp = Net::HTTP.get URI(url)
          Item.from_yaml(resp).tap { |it| it.fetched = Date.today.to_s }
        end
      end

      def part
        @part ||= hit[:code].match(/(?<=-)[\w-]+/)&.to_s
      end
    end
  end
end
