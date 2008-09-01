module Mcmire
  module SmartAssets
    module Controller
      def self.included(klass)
        class_options = { :extra_javascripts => [], :extra_stylesheets => [] }
        klass.write_inheritable_hash :smart_asset_options, class_options
        klass.class_inheritable_reader :smart_asset_options
        klass.helper_method :add_to_javascripts, :add_to_stylesheets
      end
    protected
      def add_to_javascripts(*args)
        self.class.smart_asset_options[:extra_javascripts] += args
      end
      def add_to_stylesheets(*args)
        self.class.smart_asset_options[:extra_stylesheets] += args
      end
    end
  end
end
