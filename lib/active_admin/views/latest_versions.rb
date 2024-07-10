module ActiveAdmin
  module Views
    class LatestVersions < ActiveAdmin::Component
      include ActiveAdmin::ViewHelpers

      builder_method :latest_versions

      def build(resource, _attributes = {})
        panel 'Latest versions' do
          table_for resource.latest_versions do
            column :id
            column :event
            column :who
            column :object_changes do |version|
              version_attributes_diff(version.object_changes)
            end
            column :additional_objects_changes do |version|
              version_attributes_diff(version.additional_objects_changes)
            end
            column :created_at
            column :actions do |version|
              div class: 'table_actions' do
                link_to 'View', admin_content_version_path(version)
              end
            end
          end

          div style: 'padding: 8px 16px' do
            link_to 'View all versions', admin_content_versions_path({
              'q[item_type_eq]' => resource.class.name,
              'q[item_id_eq]' => resource.id,
            })
          end
        end
      end
    end
  end
end
