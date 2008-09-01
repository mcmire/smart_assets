require File.dirname(__FILE__) + '/lib/controller'
require File.dirname(__FILE__) + '/lib/helper'

ActionView::Base.send(:include, Mcmire::SmartAssets::Helper)
ActionController::Base.send(:include, Mcmire::SmartAssets::Controller)
