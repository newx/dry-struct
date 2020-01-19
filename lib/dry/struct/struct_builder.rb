# frozen_string_literal: true

require 'dry/types/compiler'

module Dry
  class Struct
    # @private
    class StructBuilder < Types::Compiler
      attr_reader :struct

      def initialize(struct)
        super(Types)
        @struct = struct
      end

      # @param [Symbol|String] attr_name the name of the nested type
      # @param [Dry::Struct,Dry::Types::Type::Array,Undefined] type the superclass of the nested struct
      # @yield the body of the nested struct
      def call(attr_name, type, &block)
        const_name = const_name(type, attr_name)
        check_name(const_name)

        builder = self
        parent = parent(type)

        new_type = ::Class.new(Undefined.default(parent, struct.abstract_class)) do
          if Undefined.equal?(parent)
            schema builder.struct.schema.clear
          end

          class_exec(&block)
        end
        struct.const_set(const_name, new_type)

        if array?(type)
          type.of(new_type)
        else
          new_type
        end
      end

      private

      def array?(type)
        type.is_a?(Types::Type) && type.primitive.equal?(::Array)
      end

      def parent(type)
        if array?(type)
          visit(type.to_ast)
        else
          type
        end
      end

      def const_name(type, attr_name)
        snake_name =
          if array?(type)
            Core::Inflector.singularize(attr_name)
          else
            attr_name
          end

        Core::Inflector.camelize(snake_name)
      end

      def check_name(name)
        raise(
          Error,
          "Can't create nested attribute - `#{struct}::#{name}` already defined"
        ) if struct.const_defined?(name, false)
      end

      def visit_constrained(node)
        definition, * = node
        visit(definition)
      end

      def visit_array(node)
        member, * = node
        member
      end

      def visit_nominal(*)
        Undefined
      end

      def visit_constructor(node)
        definition, * = node
        visit(definition)
      end
    end
  end
end
