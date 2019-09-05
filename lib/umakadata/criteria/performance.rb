require 'umakadata/criteria/base'
require 'umakadata/criteria/helpers/performance_helper'

module Umakadata
  module Criteria
    class Performance < Base
      include Helpers::PerformanceHelper

      MEASUREMENT_NAMES = {
        execution_time: 'performance.execution_time'
      }.freeze

      #
      # @return [Umakadata::Measurement]
      def execution_time
        activities = []

        times = 3.times.map { |t| measure_execution_time(t * 100) }.map do |acts, time|
          activities.push(*acts)
          time
        end

        Umakadata::Measurement.new do |m|
          m.name = MEASUREMENT_NAMES[__method__]
          m.value = times.sum / times.size.to_f
          m.comment = "It takes #{pluralize(m.value.round(3), 'second')} (average) to obtain distinct classes."
          m.activities = activities
        end
      end

      private

      def measure_execution_time(query_offset = 0)
        activities = []

        activities << (t1 = base_query)
        activities << (t2 = heavy_query(query_offset))

        [activities, t2.elapsed_time - t1.elapsed_time]
      end
    end
  end
end