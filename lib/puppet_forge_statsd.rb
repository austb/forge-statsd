require 'statsd/instrument'
require 'puppet_forge_statsd/version'

module ForgeStatsD
  extend StatsD

  def self.timing(key, ms=0, sample_rate=default_sample_rate)
    collect_metric(:name => key, :value => ms, :type => :ms, :sample_rate => sample_rate)
  end

  def self.queue_time(key, delta=0)
    @time_queue ||= Hash.new(0)
    @time_queue[key] += delta
  end

  def self.flush_times
    @time_queue ||= Hash.new(0)
    @time_queue.each do |key, _|
      self.timing(key, @time_queue.delete(key)) if @time_queue and @time_queue.has_key?(key)
    end
  end

  def self.measure_api(key, value = nil, *metric_options, &block)
    if value.is_a?(Hash) && metric_options.empty?
      metric_options = [value]
      value = nil
    end

    result = nil
    value  = 1000 * StatsD::Instrument.duration { result = block.call } if block_given?

    ForgeStatsD.queue_time('waiting_for_api', value)

    metric = collect_metric(hash_argument(metric_options).merge(type: :ms, name: key, value: value))
    result = metric unless block_given?
    result
  end

  # Patch to accumulate all time spent waiting for API response
  module Instrument
    def self.extended(base)
      base.send :extend, StatsD::Instrument
    end

    def statsd_measure_api(method, name, *metric_options)
      add_to_method(method, name, :measure) do |old_method, new_method, metric_name, *args|
        define_method(new_method) do |*args, &block|
          ForgeStatsD.measure_api(StatsD::Instrument.generate_metric_name(metric_name, self, *args), nil, *metric_options) { send(old_method, *args, &block) }
        end
      end
    end
  end

  # Used by the API to send timing metrics to StatsD
  module SequelLogger
    extend self

    attr_accessor :query_count

    def send(_, msg)
      time, sql = msg.scan(/^\(([\d\.]+)s\) (.*)$/).first
      return unless sql

      table = sql[/(FROM|INTO) "(.*?)"/, 2] || 'unknown'
      op = case sql
        when /^insert/i then 'create'
        when /^select/i then 'read'
        when /^update/i then 'update'
        when /^delete/i then 'delete'
        else return
      end

      self.increment_queries
      StatsD.queue("queries.database_time_per_request", time.to_f * 1000)
      StatsD.timing("queries.#{op}.#{table}.sequel", time.to_f * 1000)
    end

    def increment_queries
      @query_count ||= 0
      @query_count += 1
    end
  end

end

