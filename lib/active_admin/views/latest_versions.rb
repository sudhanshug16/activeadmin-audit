module ActiveAdmin
  module Views
    class LatestVersions < ActiveAdmin::Component
      include ActiveAdmin::ViewHelpers

      builder_method :latest_versions

      def build(resource, _attributes = {})
        return unless active_admin_authorization.authorized?(:index, ActiveAdmin::Audit::ContentVersion)

        panel 'Latest versions' do
          table_for resource.deep_versions.limit(10) do
            column :actions do |version|
              div class: 'table_actions' do
                link_to 'View', admin_content_version_path(version)
              end
            end
            column :id
            column :item
            column :item_type
            column :event
            column :who
            column :object_changes do |version|
              version_attributes_diff(version.object_changes)
            end
            column :additional_objects_changes do |version|
              version_attributes_diff(version.additional_objects_changes)
            end
            column :created_at
          end

          div style: 'padding: 8px 16px' do
            link_to 'View all versions', admin_content_versions_path({
              'q[item_versions]' => "#{resource.class.name}:#{resource.id}",
            })
          end
        end
      end
    end
  end
end
