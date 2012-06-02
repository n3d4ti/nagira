
class Nagira < Sinatra::Base

  disable :protection
  
  if development?
    require 'sinatra/reloader'
    also_reload File.dirname(__FILE__)+'/*.rb'
  end

  ##
  # Development and test environments use local files localted in the
  # development tree: ./test/data.
  configure :development, :test do 
    
    dir = File.expand_path(File.dirname(__FILE__) + '/../test/data/')
    
    set :nagios_cfg => "#{dir}/nagios.cfg",
        :status_cfg => "#{dir}/status.dat",
        :object_cfg => "#{dir}/objects.cache"

  end
  

# configure :production do
#   # If your nagios.cfg file is in 'standard' location (in RH and
#   # Debian it usially installed under /etc/nagios(3)?) you don't need
#   # to define nagios_cfg.
#   set :nagios_cfg, nil
# end

end
