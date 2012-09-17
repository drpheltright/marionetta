require 'marionetta'
require 'rake'

module Marionetta
  class RakeHelper
    include ::Rake::DSL if defined?(::Rake::DSL)

    attr_reader :group

    def initialize(group)
      @group = group
    end

    def install_group_tasks()
      install_group_tasks_for(group)
    end

  private

    def install_group_tasks_for(group)
      Manipulators.all.each do |manipulator_name, manipulator_class|
        manipulator_class.tasks.each do |method_name|
          task(task_name(manipulator_name, method_name)) do
            group.manipulate_each_server(manipulator_name, method_name)
          end
        end
      end
    end

    def task_name(manipulator_name, method_name)
      task_name_parts = [manipulator_name, method_name]

      if group.name
        task_name_parts.unshift(group.name)
      end

      return task_name_parts.join(':')
    end
  end
end