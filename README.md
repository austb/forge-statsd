# ForgeStatsD

## Dependencies

* `statsd-instrument ~> 2.0.7`

## Overview

The ForgeStatsD gem extends StatsD and adds functionality needed for monitoring the Forge website.

## Usage

### StatsD Features

All [StatsD](https://github.com/Shopify/statsd-instrument) functionality is still usable. Just use `ForgeStatsD` instead of `StatsD`.
For example,

```ruby
ForgeStatsD.measure('GoogleBase.insert', 2.55)
```

or

```ruby
GoogleBase.extend ForgeStatsD::Instrument

GoogleBase.statsd_measure :insert, 'GoogleBase.insert'
```

### ForgeStatsD.measure_request

ForgeStatsD.measure_request operates in a manner exactly the same as `StatsD.measure`, but it also queue's the time under a given key.
The time can then be flushed after each request.

```ruby
ForgeStatsD.measure_request('external_request', 'time_waiting_for_external_request', 2.55)

ForgeStatsD.measure_request('another_external_request', 'time_waiting_for_external_request', 3.45)
```

This will log three pieces of information,

* external_request:2.55
* another_external_request:3.45
* time_waiting_for_external_request:6.00

ForgeStatsD.measure_request can also take a block of code to measure rather than a time.

After every request, the application needs to call the following method.

```ruby
ForgeStatsD.flush_times
```

## Metaprogramming Methods

All [StatsD::Instrument metaprogramming methods](https://github.com/Shopify/statsd-instrument#metaprogramming-methods) are available under `ForgeStatsD::Intrument`.

ForgeStatsD methods can be added as class names in the same way that [StatsD class methods](https://github.com/Shopify/statsd-instrument#instrumenting-class-methods) are added.
### ForgeStatsD::Intrument.statsd_measure_request

Operates the same as `statsd_measure`, but it calls measure_request and therefore also accumulates the time under a second key.

```ruby
GoogleBase.extend ForgeStatsD::Intrument

GoogleBase.statsd_measure_request(:method_name, key_for_accumulation, key_for_this_measurement)
```

The key for the single measurement can be omitted in favor of a block that returns the key. See [StatsD documentation](https://github.com/Shopify/statsd-instrument#dynamic-metric-names) for details.

