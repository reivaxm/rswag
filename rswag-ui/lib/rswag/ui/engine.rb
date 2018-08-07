module Rswag
  module Ui
    class Engine < ::Rails::Engine
      isolate_namespace Rswag::Ui

      initializer 'rswag-ui.initialize' do |app|
        if app.config.respond_to?(:assets)
          app.config.assets.precompile += [
            'swagger-ui.css',
            'swagger-ui.css.map',
            'swagger-ui.js',
            'swagger-ui.js.map',
            'swagger-ui-standalone-preset.js',
            'swagger-ui-standalone-preset.js.map',
            'swagger-ui-bundle.js',
            'swagger-ui-bundle.js.map',
            'favicon-16x16.png',
            'favicon-32x32.png'
          ]
        end
      end
    end
  end
end
