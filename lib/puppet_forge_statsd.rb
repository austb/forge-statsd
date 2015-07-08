require 'statsd/instrument'
require 'puppet_forge_statsd/version'

module ForgeStatsD
  extend StatsD
  extend self

  # Pass variable information through to StatsD
  attr_reader :logger, :default_sample_rate, :prefix

  def logger=(val)
    @logger = val
    StatsD.logger = val
  end

  def default_sample_rate=(val)
    @default_sample_rate = val
    StatsD.default_sample_rate = val
  end

  def prefix=(val)
    @prefix = val
    StatsD.prefix = val
  end

  def backend=(val)
    @backend = val
    StatsD.backend = val
  end

  def timing(key, ms=0, sample_rate=default_sample_rate)
    collect_metric(:name => key, :value => ms, :type => :ms, :sample_rate => sample_rate)
  end

  def queue_time(key, delta=0)
    @time_queue ||= Hash.new(0)
    @time_queue[key] += delta
  end

  def flush_time(key)
    self.timing(key, @time_queue.delete(key)) if @time_queue and @time_queue.has_key?(key)
  end

  def measure_request(key, accumulate_key, value = nil, *metric_options, &block)
    if value.is_a?(Hash) && metric_options.empty?
      metric_options = [value]
      value = nil
    end

    result = nil
    value  = 1000 * StatsD::Instrument.duration { result = block.call } if block_given?

    ForgeStatsD.queue_time(accumulate_key, value)

    metric = collect_metric(hash_argument(metric_options).merge(type: :ms, name: key, value: value))
    result = metric unless block_given?
    result
  end

  # Patch to accumulate all time spent waiting for API response
  module Instrument
    def self.extended(base)
      base.send :extend, StatsD::Instrument
    end

    def statsd_measure_request(method, accumulate_key, name, *metric_options)
      add_to_method(method, name, :measure) do |old_method, new_method, metric_name, *args|
        define_method(new_method) do |*args, &block|
          ForgeStatsD.measure_request(StatsD::Instrument.generate_metric_name(metric_name, self, *args), accumulate_key, nil, *metric_options) { send(old_method, *args, &block) }
        end
      end
    end

    def statsd_queue_time(method, name, *metric_options)
      add_to_method(method, name, :measure) do |old_method, new_method, metric_name, *args|
        define_method(new_method) do |*args, &block|
          start = Time.now
          send(old_method, *args, &block)
          duration = (Time.now - start) * 1000
          ForgeStatsD.queue_time(StatsD::Instrument.generate_metric_name(metric_name, self, *args), duration)

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
      ForgeStatsD.queue_time("queries.database_time_per_request", time.to_f * 1000)
      ForgeStatsD.timing("queries.#{op}.#{table}.sequel", time.to_f * 1000)
    end

    def increment_queries
      @query_count ||= 0
      @query_count += 1
    end
  end

end

