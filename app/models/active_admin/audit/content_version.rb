module ActiveAdmin
  module Audit
    class ContentVersion < PaperTrail::Version
      serialize :object, VersionSnapshot
      serialize :object_changes, VersionSnapshot

      serialize :additional_objects, VersionSnapshot
      serialize :additional_objects_changes, VersionSnapshot

      def self.ransackable_associations(auth_object = nil)
        []
      end

      def self.ransackable_attributes(auth_object = nil)
        ["additional_objects", "additional_objects_changes", "created_at", "event", "id", "id_value", "object", "object_changes", "whodunnit"]
      end

      ransacker :item_versions do |parent|
        Arel::Nodes::SqlLiteral.new("item_versions")
      end

      def self.ransackable_scopes(auth_object = nil)
        %i[item_versions]
      end

      scope :item_versions, ->(value) {
        item_type, item_id = value.split(':')
        item = item_type.constantize.find_by(id: item_id)
        where(id: item.deep_versions.pluck(:id))
      }


      def object_changes
       ignore = %w(id created_at updated_at)
       super.reject { |k, _| ignore.include?(k) }
      end

      def object_snapshot
        object.materialize(item_class)
      end

      def additional_objects_snapshot
        additional_objects.materialize(item_class)
      end

      def object_snapshot_changes
        object_changes.materialize(item_class)
      end

      def additional_objects_snapshot_changes
        additional_objects_changes.materialize(item_class)
      end

      def who
        Audit.configuration.user_class_name.to_s.classify.constantize.find_by(id: whodunnit)
      end

      def item_class
        item_type.constantize
      rescue NameError
        ActiveRecord::Base
      end

      def item
        super
      rescue NameError
        nil
      end
    end
  end
end
