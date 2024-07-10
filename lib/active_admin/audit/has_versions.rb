require 'paper_trail'

module ActiveAdmin
  module Audit
    module HasVersions
      extend ActiveSupport::Concern

      RAILS_GTE_5_1 = ::ActiveRecord.gem_version >= ::Gem::Version.new("5.1.0.beta1")

      module ClassMethods
        def has_versions(options = {})
          options[:also_include] ||= {}
          options[:skip] ||= []
          options[:skip] += options[:also_include].keys
          if respond_to?(:translated_attrs)
            options[:skip] += translated_attrs.map { |attr| "#{attr}_translations" }
          end

          has_paper_trail options.merge( on: [], versions: { class_name: "ActiveAdmin::Audit::ContentVersion" }, meta: {
            additional_objects: ->(record) { record.additional_objects_snapshot.to_json },
            additional_objects_changes: ->(record) { record.additional_objects_snapshot_changes.to_json },
          })

          class_eval do
            define_method(:additional_objects_snapshot) do
              options[:also_include].each_with_object(VersionSnapshot.new) do |(attr, scheme), snapshot|
                snapshot[attr] =
                  if scheme.is_a? Symbol
                    send(scheme)
                  elsif scheme.empty?
                    send(attr)
                  else
                    Array(send(attr)).map do |item|
                      scheme.each_with_object({}) do |item_attr, item_snapshot|
                        item_snapshot[item_attr] = item.send(item_attr)
                      end
                    end
                  end
              end
            end

            # Will save new version of the object
            after_commit do
              if paper_trail.enabled?
                if @event_for_paper_trail
                  generate_version!
                end
              end
            end

            options_on = Array(options.fetch(:on, [:create, :update, :destroy]))

            if options_on.include?(:create)
              after_create do
                if paper_trail.enabled?
                  @event_for_paper_trail = 'create'
                end
              end
            end

            if options_on.include?(:update)
              # Cache object changes to access it from after_commit
              after_update do
                if paper_trail.enabled?
                  @event_for_paper_trail = 'update'
                  cache_version_object_changes
                end
              end
            end

            if options_on.include?(:destroy)
              # Cache all details to access it from after_commit
              before_destroy do
                if paper_trail.enabled?
                  @event_for_paper_trail = 'destroy'
                  cache_version_object
                  cache_version_object_changes
                  cache_version_additional_objects_and_changes
                end
              end
            end
          end
        end
      end

      def latest_versions(count = 5)
        versions.reorder(created_at: :desc).limit(count).rewhere(item_type: self.class.name)
      end

      def additional_objects_snapshot_changes
        prev_version = (versions.size > 0) ? versions.last : latest_versions.first

        old_snapshot = prev_version.try(:additional_objects) || VersionSnapshot.new
        new_snapshot = additional_objects_snapshot

        old_snapshot.diff(new_snapshot)
      end

      private

      def attribute_in_previous_version(record, attr_name, is_touch)
        if !is_touch
          # For most events, we want the original value of the attribute, before
          # the last save.
          record.attribute_before_last_save(attr_name.to_s)
        else
          # We are either performing a `record_destroy` or a
          # `record_update(is_touch: true)`.
          record.attribute_in_database(attr_name.to_s)
        end
      end

      def cache_version_object
        if paper_trail.respond_to?(:object_attrs_for_paper_trail)
          @version_object_cache ||= paper_trail.object_attrs_for_paper_trail(false)
        else
          @record = paper_trail.instance_variable_get(:@record)
          record_attributes = @record.attributes.except(*@record.paper_trail_options[:skip].map(&:to_s))
          record_attributes.each_key do |k|
            if @record.class.column_names.include?(k)
              record_attributes[k] = attribute_in_previous_version(@record, k, false)
            end
          end
          @version_object_cache ||= record_attributes
        end
      end

      def cache_version_object_changes
        record = paper_trail.instance_variable_get(:@record)
        @version_object_changes_cache ||= (RAILS_GTE_5_1 ? record.saved_changes : record.changes).except(*record.paper_trail_options[:skip].map(&:to_s))
      end

      def cache_version_additional_objects_and_changes
        if paper_trail.respond_to?(:merge_metadata_into)
          @version_additional_objects_and_changes_cache ||= paper_trail.merge_metadata_into({})
        else
          data ={}
          @record = paper_trail.instance_variable_get(:@record)
          @record.paper_trail_options[:meta].each do |k, v|
            data[k] = if v.respond_to?(:call)
              v.call(@record)
            elsif v.is_a?(Symbol) && @record.respond_to?(v, true)
              if data[:event] != "create" &&
                  @record.has_attribute?(v) &&
                  (RAILS_GTE_5_1 ? @record.saved_change_to_attribute?(v.to_s) : @record.attribute_changed?(v.to_s))
                if RAILS_GTE_5_1
                  @record.attribute_before_last_save(v.to_s)
                else
                  @record.attribute_in_database(v.to_s)
                end
              else
                @record.send(v)
              end
            else
              v
            end
          end
          data.merge!(PaperTrail.request.controller_info || {})
          @version_additional_objects_and_changes_cache ||= data
        end
      end

      def clear_version_cache
        @version_object_cache = nil
        @version_object_changes_cache = nil
        @version_additional_objects_and_changes_cache = nil
      end

      def generate_version!
        if cache_version_object_changes.size > 0 or cache_version_additional_objects_and_changes.size > 0
          data = {
            event: @event_for_paper_trail,
            object: cache_version_object.to_json,
            object_changes: cache_version_object_changes.to_json,
            whodunnit: PaperTrail.request.whodunnit,
            item_type: self.class.name,
            item_id: id,
          }

          PaperTrail::Version.create! data.merge!(cache_version_additional_objects_and_changes)
        end

        clear_version_cache
      end
    end
  end
end
