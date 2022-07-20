namespace :models do
  desc "check dependent"
  task :check_callback => :environment do
    application_tables = ApplicationRecord.connection.tables - ["schema_migrations", "ar_internal_metadata"]

    application_tables.each do |table_name|
      ApplicationRecord.connection.foreign_keys(table_name).each do |fk|
        require_relative "../../app/models/#{fk.to_table.classify.underscore}"
      end
    end

    models = ActiveRecord::Base.descendants.reject(&:abstract_class).index_by(&:table_name)
    check_errors = []

    application_tables.each do |table_name|
      ApplicationRecord.connection.foreign_keys(table_name).each do |fk|
        r = models[fk.to_table].reflections
        association = r[fk.from_table] || r[fk.from_table.singularize] || r.to_a.map(&:second).index_by(&:class_name)[fk.from_table.classify]
        if association.nil?
          next check_errors << { message: "No association corresponding to FK from #{fk.from_table} to #{fk.to_table}" }
        elsif association.options.blank? || [:delete_all, :destroy, :nullify].none?(association.options[:dependent])
          next check_errors << { message: "#{fk.to_table.classify} must be annotated with dependent option for :#{association.name} association." }
        end
      end
    end

    if check_errors.present?
      check_errors.each { |error| $stderr.puts error[:message] }
      exit 1
    end
  end
end
