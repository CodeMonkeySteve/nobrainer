module NoBrainer::Document::Attributes
  extend ActiveSupport::Concern

  included do
    include ActiveModel::MassAssignmentSecurity
    attr_accessor :attributes
    field :id
  end

  def initialize(attrs={}, options={})
    super
    assign_attributes(attrs, options.reverse_merge(:prestine => true))
  end

  def assign_attributes(attrs, options={})
    if options[:prestine]
      # XXX Performance optimization: we don't save field that are not
      # explicitly set. The row will therefore not contain nil for
      # unset attributes. This has some implication when using where()
      # see lib/no_brainer/selection/where.rb
      @attributes = {}
      self.id = self.class.generate_id
      clear_internal_cache
    end

    # TODO Should we reject undeclared fields ?
    if options[:from_db]
      @attributes.merge! attrs
    else
      unless options[:without_protection]
        attrs = sanitize_for_mass_assignment(attrs, options[:as])
      end
      attrs.each { |k,v| __send__("#{k}=", v) }
    end
  end
  alias_method :attributes=, :assign_attributes

  # TODO test that thing
  def inspect
    attrs = self.class.fields.keys.map { |f| "#{f}: #{attributes[f.to_s].inspect}" }
    "#<#{self.class} #{attrs.join(', ')}>"
  end

  module ClassMethods
    def new_from_db(attrs, options={})
      new(attrs, options.reverse_merge(:from_db => true)) if attrs
    end

    def inherited(subclass)
      # TODO FIXME when the parent adds new fields, the subclasses
      # will not get them
      parent_fields = @fields.dup
      subclass.class_eval do
        @fields = parent_fields
      end
    end

    def fields
      @fields
    end

    def field(name, options={})
      name = name.to_sym
      @fields ||= {}
      @fields[name] = true

      inject_in_layer :attributes, <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}=(value)
          @attributes['#{name}'] = value
        end

        def #{name}
          @attributes['#{name}']
        end
      RUBY
    end
  end
end