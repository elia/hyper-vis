module Vis
  module Utilities
    def self.included(klass)
      klass.extend Vis::Utilities::Native
    end

    module Native
      def native_methods_with_options(js_names)
        js_names.each do |js_name|
          native_method_with_options(js_name)
        end
      end

      def native_method_with_options(js_name)
        define_method(js_name.underscore) do |options|
          @native.JS.call(js_name, options_to_native(options))
        end
      end
    end

    def hash_array_to_native(array)
      array.map(&:to_n)
    end

    def native_to_hash_array(array)
      array.map { |i| `Opal.Hash.$new(i)` }
    end

    def lower_camelize(snake_cased_word)
      words = snake_cased_word.split('_')
      result = [words.first]
      result.concat(words[1..-1].map {|word| word[0].upcase + word[1..-1] }).join('')
    end

    def lower_camelize_hash(hash)
      camel_options = {}
      hash.each do |key, value|
        value = lower_camelize_hash(value) if `Opal.is_a(value, Opal.Hash)`
        camel_options[lower_camelize(key)] = value
      end
      camel_options
    end

    def options_to_native(options)
      return unless options
      # options must be duplicated, so callbacks dont get wrapped twice
      new_opts = {}.merge!(options)
      _rubyfy_configure_options(new_opts) if new_opts.has_key?(:configure)
      _rubyfy_edges_options(new_opts) if new_opts.has_key?(:edges)
      _rubyfy_manipulation_options(new_opts) if new_opts.has_key?(:manipulation)
      _rubyfy_nodes_options(new_opts) if new_opts.has_key?(:nodes)

      if new_opts.has_key?(:join_condition)
        block = new_opts[:join_condition]
        if `typeof block === "function"`
          unless new_opts[:join_condition].JS[:hyper_wrapped]
            new_opts[:join_condition] = %x{
              function(node_options, child_options) {
                if (child_options !== undefined && child_options !== null) {
                  return #{block.call(`Opal.Hash.$new(node_options)`, `Opal.Hash.$new(child_options)`)};
                } else {
                  return #{block.call(`Opal.Hash.$new(node_options)`)};
                }
              }
            }
            new_opts[:join_condition].JS[:hyper_wrapped] = true
          end
        end
      end

      if new_opts.has_key?(:process_properties)
        block = new_opts[:process_properties]
        if `typeof block === "function"`
          unless new_opts[:process_properties].JS[:hyper_wrapped]
            new_opts[:process_properties] = %x{
              function(item) {
                var res = #{block.call(`Opal.Hash.$new(item)`)};
                return res.$to_n();
              }
            }
            new_opts[:process_properties].JS[:hyper_wrapped] = true
          end
        end
      end

      if new_opts.has_key?(:filter)
        block = new_opts[:filter]
        if `typeof block === "function"`
          unless new_opts[:filter].JS[:hyper_wrapped]
            new_opts[:filter] = %x{
              function(item) {
                return #{block.call(`Opal.Hash.$new(item)`)};
              }
            }
            new_opts[:filter].JS[:hyper_wrapped] = true
          end
        end
      end

      lower_camelize_hash(new_opts).to_n
    end

    def _rubyfy_configure_options(options)
      if options[:configure].has_key?(:filter)
        block = options[:configure][:filter]
        if `typeof block === "function"`
          unless options[:configure][:filter].JS[:hyper_wrapped]
            options[:configure][:filter] = %x{
              function(option, path) {
                return #{block.call(`Opal.Hash.$new(options)`, `path`)};
              }
            }
            options[:configure][:filter].JS[:hyper_wrapped] = true
          end
        end
      end
    end

    def _rubyfy_edges_options(options)
      if options[:edges].has_key?(:chosen)
        chosen = options[:edges][:chosen]
        [:edge, :label].each do |key|
          if chosen.has_key?(key)
            block = chosen[key]
            if `typeof block === "function"`
              unless options[:edges][:chosen][key].JS[:hyper_wrapped]
                options[:edges][:chosen][key] = %x{
                  function(values, id, selected, hovering) {
                    return #{block.call(`Opal.Hash.$new(values)`, `id`, `selected`, `hovering`)};
                  }
                }
                options[:edges][:chosen][key].JS[:hyper_wrapped] = true
              end
            end
          end
        end
      end
      [:hover_width, :selection_width].each do |key|
        if options[:edges].has_key?(key)
          block = options[:edges][key]
          if `typeof block === "function"`
            unless options[:edges][key].JS[:hyper_wrapped]
              options[:edges][key] = %x{
                function(width) {
                  return #{block.call(`width`)};
                }
              }
              options[:edges][key].JS[:hyper_wrapped] = true
            end
          end
        end
      end
      if options[:edges].has_key?(:scaling)
        if options[:edges][:scaling].has_key?(:custom_scaling_function)
          block = options[:edges][:scaling][:custom_scaling_function]
          if `typeof block === "function"`
            unless options[:edges][:scaling][:custom_scaling_function].JS[:hyper_wrapped]
              options[:edges][:scaling][:custom_scaling_function] = %x{
                function(min, max, total, value) {
                  return #{block.call(`min`, `max`, `total`, `value`)};
                }
              }
              options[:edges][:scaling][:custom_scaling_function].JS[:hyper_wrapped] = true
            end
          end
        end
      end
    end

    def _rubyfy_manipulation_options(options)
      [:add_edge, :add_node, :edit_edge, :edit_node].each do |key|
        next unless options[:manipulation].has_key?(key)
        block = options[:manipulation][key]
        if `typeof block === "function"`
          unless options[:manipulation][key].JS[:hyper_wrapped]
            options[:manipulation][key] = %x{
              function(nodeData, callback) {
                var wrapped_callback = #{ proc { |new_node_data| `callback(new_node_data.$to_n());` }};
                block.$call(Opal.Hash.$new(nodeData), wrapped_callback);
              }
            }
          end
          options[:manipulation][key].JS[:hyper_wrapped] = true
        end
      end
      # for delete the order of args for the callback is not clear
      [:delete_edge, :delete_node].each do |key|
        next unless options[:manipulation].has_key?(key)
        block = options[:manipulation][key]
        if `typeof block === "function"`
          unless options[:manipulation][key].JS[:hyper_wrapped]
            options[:manipulation][key] = %x{
              function(nodeData, callback) {
                var wrapped_callback = #{ proc { |new_node_data| `callback(new_node_data.$to_n());` }};
                block.$call(Opal.Hash.$new(nodeData), wrapped_callback);
              }
            }
            options[:manipulation][key].JS[:hyper_wrapped] = true
          end
        end
      end
    end

    def _rubyfy_nodes_options(options)
      if options[:nodes].has_key?(:chosen)
        chosen = options[:nodes][:chosen]
        [:node, :label].each do |key|
          if chosen.has_key?(key)
            block = chosen[key]
            if `typeof block === "function"`
              unless options[:nodes][:chosen][key].JS[:hyper_wrapped]
                options[:nodes][:chosen][key] = %x{
                  function(values, id, selected, hovering) {
                    return #{block.call(`Opal.Hash.$new(values)`, `id`, `selected`, `hovering`)};
                  }
                }
                options[:nodes][:chosen][key].JS[:hyper_wrapped] = true
              end
            end
          end
        end
      end
      if options[:nodes].has_key?(:scaling)
        if options[:nodes][:scaling].has_key?(:custom_scaling_function)
          block = options[:nodes][:scaling][:custom_scaling_function]
          if `typeof block === "function"`
            unless options[:nodes][:scaling][:custom_scaling_function].JS[:hyper_wrapped]
              options[:nodes][:scaling][:custom_scaling_function] = %x{
                function(min, max, total, value) {
                  return #{block.call(`min`, `max`, `total`, `value`)};
                }
              }
              options[:nodes][:scaling][:custom_scaling_function].JS[:hyper_wrapped] = true
            end
          end
        end
      end
    end
  end
end
