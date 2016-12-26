require 'ddtrace/monkey'
require 'ddtrace/pin'
require 'ddtrace/tracer'

# \Datadog global namespace that includes all tracing functionality for Tracer and Span classes.
module Datadog
  @tracer = Datadog::Tracer.new()

  # Default tracer that can be used as soon as +ddtrace+ is required:
  #
  #   require 'ddtrace'
  #
  #   span = Datadog.tracer.trace('web.request')
  #   span.finish()
  #
  # If you want to override the default tracer, the recommended way
  # is to "pin" your own tracer onto your traced component:
  #
  #   tracer = Datadog::Tracer.new
  #   pin = Datadog::Pin.get_from(mypatchcomponent)
  #   pin.tracer = tracer

  def self.tracer
    @tracer
  end
end

# Datadog auto instrumentation for frameworks
if defined?(Rails::VERSION)
  if Rails::VERSION::MAJOR.to_i >= 3
    begin
      # We include 'redis-rails' here if it's available, doing it later
      # (typically in initialize callback) does not work, it does not
      # get loaded in the right context.
      require 'redis-rails'
      Datadog::Tracer.log.info("'redis-rails' module found, datadog redis integration is available")
    rescue LoadError
      Datadog::Tracer.log.info("no 'redis-rails' module found, datadog redis integration is not available")
    end
    require 'ddtrace/contrib/rails/framework'

    Datadog::Monkey.patch_module(:redis) # does nothing if redis is not loaded
    Datadog::RailsPatcher.patch_renderer()
    Datadog::RailsPatcher.patch_cache_store()

    module Datadog
      # Run the auto instrumentation directly after the initialization of the application and
      # after the application initializers in config/initializers are run
      class Railtie < Rails::Railtie
        config.after_initialize do |app|
          Datadog::Contrib::Rails::Framework.configure(config: app.config)
          Datadog::Contrib::Rails::Framework.auto_instrument()
          Datadog::Contrib::Rails::Framework.auto_instrument_redis()
        end
      end
    end
  else
    logger = Logger.new(STDOUT)
    logger.warn 'Detected a Rails version < 3.x.'\
        'This version is not supported yet and the'\
        'auto-instrumentation for core components will be disabled.'
  end
end
