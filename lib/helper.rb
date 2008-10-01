module Mcmire
  module SmartAssets
    module Helper
      # Put this in your layout file to automatically include stylesheets and
      # javascript files based on current controller and action.
      #
      # You can tell smart_assets not to load certain stylesheets or javascripts
      # by passing a hash with an :except key. For instance:
      #
      #  smart_asset_includes :except => 'application'  # both css and js
      #  smart_asset_includes :except => 'lib/prototype.js'
      #  smart_asset_includes :except => 'foo/bar.css'
      def smart_asset_includes(options = {})
        stylesheets_to_try, javascripts_to_try = gather_paths_to_try(options)
        generate_html(stylesheets_to_try, javascripts_to_try)
      end
      
      # Put this in your layout file to include any custom javascripts or stylesheets
      # you've added at runtime. See +add_to_javascripts+ and +add_to_stylesheets+
      # for more.
      def smart_asset_runtime_includes
        generate_html(smart_asset_options[:runtime_stylesheets], smart_asset_options[:runtime_javascripts])
      end
      
      # Put this in your view or a partial to add <script> tags for the specified
      # javascript paths to your <head> when your layout is rendered.
      def add_to_javascripts(*args)
        smart_asset_options[:runtime_javascripts] += args
      end
      # Put this in your view or a partial to add <style> tags for the specified
      # stylesheet paths to your <head> when your layout is rendered.
      def add_to_stylesheets(*args)
        smart_asset_options[:runtime_stylesheets] += args
      end
    
    private
      def smart_asset_options
        @smart_asset_options ||= { :runtime_javascripts => [], :runtime_stylesheets => [] }
      end
      
      def generate_html(stylesheets_to_try, javascripts_to_try)
        out = ""
        # Include stylesheets
        # Note that by default, stylesheets apply to just media=screen
        # You can specify the medium by adding _all or _print to the end of the filename
        for prefix in stylesheets_to_try
          for medium in %w<all screen print>
            path = prefix + (medium == 'screen' ? '' : "_#{medium}")
            # If bareword, assume path is an action in current controller.
            # This lets you just say e.g. add_to_stylesheets('bar') instead of
            #  add_to_stylesheets('foo/bar').
            unless path.include?('/') or stylesheet_exists?(path)
              path = controller.controller_path + '/' + path
            end
            path.gsub! %r{^/}, ''
            unless (code = stylesheet_link_tag_if_exists(path, :media => medium)).empty?
              out << code << "\n"
            end
          end
        end
        # Include javascripts
        for path in javascripts_to_try
          # If bareword, assume path is an action in current controller.
          # This lets you just say e.g. add_to_stylesheets('bar') instead of
          #  add_to_stylesheets('foo/bar').
          unless path.include?('/') or javascript_exists?(path)
            path = controller.controller_path + '/' + path
          end
          path.gsub! %r{^/}, ''
          unless (code = javascript_include_tag_if_exists(path)).empty?
            out << code << "\n"
          end
        end
        return out
      end
    
      def gather_paths_to_try(options)
        global_exceptions = []
        js_exceptions = []
        css_exceptions = []
        if exceptions = options[:except]
          exceptions = [exceptions].flatten
          for path in exceptions
            (case path
              when /\.js$/i then js_exceptions
              when /\.css$/i then css_exceptions
              else global_exceptions
            end) << path.sub(/\.[^.]+$/i, '')
          end
        end
        
        basenames = generate_basenames()
        
        # Remove unwanted stuff
        basenames -= global_exceptions
        
        stylesheet_basenames = basenames.dup
        javascript_basenames = basenames.dup
      
        # Add files that apply to multiple controllers
        stylesheet_basenames += multicontroller_basenames_for(:stylesheets)
        javascript_basenames += multicontroller_basenames_for(:javascripts)
        
        # Remove specified files according to options
        stylesheet_basenames -= css_exceptions
        javascript_basenames -= js_exceptions
        
        # Remove duplicate entries
        stylesheet_basenames.uniq!
        javascript_basenames.uniq!
      
        [stylesheet_basenames, javascript_basenames]
      end
    
      def generate_basenames
        # Include application.css
        basenames = ['application']
      
        # Each layout gets its own file
        layout = response.layout
        basenames << layout if layout
      
        klass = controller.class
      
        # If the controller is namespaced, each namespace gets its own file
        #  (e.g. Blog::Admin::PublicController ==> ['blog', 'blog/admin', 'blog/admin/public'])
        namespaces = controller.controller_path.split('/')
        0.upto(namespaces.size-1) {|i| basenames << namespaces[0..i].join('/') }
      
        # Each supercontroller gets its own file (except for ApplicationController, since we've already done that)
        while (superclass = klass.superclass) != ApplicationController
          basenames << superclass.controller_path
          klass = superclass
        end
      
        # Each controller gets its own file
        basenames << controller.controller_path
      
        # Each action gets its own file
        basenames << (controller.controller_path + '/' + controller.action_name)
      
        basenames
      end
    
      def asset_tag_if_valid_for(type, path)
        out = ""
        # If bareword, assume path is an action in current controller.
        # This lets you just say e.g. add_to_stylesheets('bar') instead of
        #  add_to_stylesheets('foo/bar').
        unless path.include?('/') or stylesheet_exists?(path)
          path = controller.controller_path + '/' + path
        end
        path.gsub! %r{^/}, ''
        unless (code = stylesheet_link_tag_if_exists(path, :media => medium)).empty?
          out << code << "\n"
        end
        out
      end
    
      # More documentation goes here as to what this method does, but here's some examples:
      #  * A stylesheet called 'order--checkout.css' will be included for a template belonging to any
      #    action in OrderController or CheckoutController
      #  * A stylesheet called "admin/order--checkout.css" will be included for a template belonging
      #    to any action in Admin::OrderController or Admin::CheckoutController
      #  * Similarly for javascripts.
      def multicontroller_basenames_for(type)
        ext = 'css' if type == :stylesheets
        ext = 'js'  if type == :javascripts
        ctlr_name = controller.controller_name
        ctlr_path = controller.controller_path
      
        # if controller is a subcontroller, get the parent path
        ctlr_path =~ %r{^(.+)/[^/]+$}
        subdir = $1 ? $1+"/" : ""
      
        dir = "#{RAILS_ROOT}/public/#{type}/#{subdir}"
        return [] unless File.exists?(dir)
      
        basenames = []
        files = Dir.entries(dir)
        files = files.select {|f| File.file?(f) && f.ends_with?(".#{ext}") && f.include?('--') }
        files.map! {|f| "#{dir}/#{f}" }
        for file in files 
          file = file.sub(/\.#{ext}$/, '')
          basenames << subdir+file  if file =~ /(^|--)#{ctlr_name}(--|$)/
        end
        basenames
      end
      
      def stylesheet_exists?(partial_fn)
        real_fn = (RAILS_ROOT + '/public' + stylesheet_path(partial_fn)).sub(/\?.+$/, '')
        File.exists?(real_fn)
      end
      def stylesheet_link_tag_if_exists(partial_fn, options={})
        stylesheet_exists?(partial_fn) ? stylesheet_link_tag(partial_fn, options) : ""
      end
      def javascript_exists?(partial_fn)
        real_fn = (RAILS_ROOT + '/public' + javascript_path(partial_fn)).sub(/\?.+$/, '')
        File.exists?(real_fn)
      end
      def javascript_include_tag_if_exists(partial_fn)
        javascript_exists?(partial_fn) ? javascript_include_tag(partial_fn) : ""
      end
    end # Helper
  end # SmartAssets
end # Mcmire