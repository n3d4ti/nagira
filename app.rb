#!/usr/bin/env ruby
$: << File.dirname(__FILE__)
require 'sinatra'
require "sinatra/reloader" if development?
require 'lib/ruby-nagios/nagios'
require 'lib/nagira'

require 'active_support' # for Hash.extract!

require 'json'
require 'yaml'
require 'active_model/serialization'
require 'active_model/serializers/xml' # for Hash.to_xml


disable :protection

#  Regex for available formats: xml, json, yaml
FORMAT_EXTENSION = '\.(json|yaml|xml)$'
DEFAULT_FORMAT = :xml


# Parse status file.
# TODO: Add check for file changed? and min parsing interval to avoid
# file paring on each HTTP request.
before do 
  $nagios = { :config => nil, :status => nil, :objects => nil }
  
  $nagios[:status] ||= Nagios::Status.new("/Users/dmytro/Development/nagira/test/data/status.dat")
  $nagios[:objects] ||= Nagios::Objects.new("/Users/dmytro/Development/nagira/test/data/objects.cache")
  $nagios[:status].parse
  $nagios[:objects].parse

  @status   = $nagios[:status].status['hosts']
  @objects   = $nagios[:objects].objects
end

# Strip extension (@format) from HTTP route
before do 
  request.path_info.sub!(/#{FORMAT_EXTENSION}/, '')
  @format = ($1 || DEFAULT_FORMAT).to_sym
  content_type "application/#{@format.to_s}"
end

# Find output type (@output) if provided: :list, :state or :full
before do
  request.path_info.sub!(/\/(list|state)$/, '')
  @output = ($1 || :full).to_sym
end

# Return 404 if data array is empty.
after do
  if response.body.empty?
    halt [404, {:message => "Object not found or bad request", :error => "HTTP::Notfound"}.send("to_#{@format}")]
  end
end

=begin rdoc

== Routes for configured objects in the system

Namespace for object configuration starts from "/objects". Route may
be appended by /list to get short list of objects or object classes.

All routes can be followed by format specifier: .(xml|yaml|json)

Following routes are impplemented:

* /objects - all configured and parsed objects, groupped by class.

* /objects/list - list all configured and parsed object types

* /objects/<object_class> - full configuration of all objects in the
  given class. <object_class> is one of: 'host', 'hostgroup',
  'servicegroup', etc. Any of the acceptable configuration options for
  Nagios. Note, object of the specific class must exist in
  objects.cache file, or it will not appear on the list.

* /objects/<object_class>/list - short list of all names of configured
  objects

* /objects/<object_class>/<object_name>

=end

get "/objects" do
  body (@output == :list ? @objects.keys.send("to_#{@format}") : @objects.send("to_#{@format}")) rescue NoMethodError nil
end

get "/objects/:type" do |type|
  begin
    data = @objects[type.to_sym]
    data = data.keys if @output == :list
    body (  data ? data : nil ).send("to_#{@format}")
  rescue NoMethodError
    nil
  end
end

get "/objects/:type/:name" do |type,name|
  begin
    body @objects[type.to_sym][name].send("to_#{@format}")
  rescue NoMethodError
    nil
  end
end


=begin rdoc

Routes to get service information.
Every route can optionally end with "/list" or "/state" and format specifier <.FORMAT_EXTENSION>

* /list option produces only list of hosts/sevices
* /state - gives short status of host or service
* if none are provided, then will print out full parsed hash 


Following routes are implemented

== Hosts
/status - full list of all hosts with service(s) information
/status.xml
/status/list - list of hosts
/status/list.xml

Service
/status/<hostname>
/status/<hostname>/services(/(list|state).FORMAT_EXTENSION?)?
/status/<hostname>/services/<service name>

=end

# === GET /status/:hostname/services/:service_name
# Full or short status information for particular service on single
# host
# /list option is ignored
get "/status/:hostname/services/:service_name" do |hostname,service|
  body (if @output == :state
          @status[hostname]['servicestatus'][service].extract!("hostname", "service_description", "current_state")
        else
          @status[hostname]['servicestatus'][service]
        end).send("to_#{@format}")
end

# All services for single host: 
# :full, :state or :list
get "/status/:hostname/services" do |hostname|
  data = case @output
         when :list
           @status[hostname]['servicestatus'].keys
         when :state
           @status.each { |k,v| @status[k] = v.extract!("host_name", "service_description", "current_state") }
         else
           @status[hostname]['servicestatus']
         end
  body data.send("to_#{@format}")
end
  
# Hoststatus for single host
# - :state - hostname and current_state
# - :full  - full hoststatus
get "/status/:hostname" do |hostname|
  body (if @output == :state
          @status[hostname]['hoststatus'].extract!("host_name", "current_state")
        else
          @status[hostname]['hoststatus']
        end).send("to_#{@format}")
end

#
# All hosts status
# - :state - only hostname and current_state
# - :list  - list of hostnames
# - :full status of all hosts and services
# 
get "/status" do
  case @output 
  when :state
    @status.each { |k,v| @status[k] = v['hoststatus'].extract!("host_name", "current_state") }
  when :list
    @status = @status.keys
  end
  body @status.send("to_#{@format}")
end


# TODO: provide informatiuon about API routes
get "/api" do 
  [501, "TODO: Not implemented"]
end

# Other resources in parsed status file. Supported are => ["hosts",
# "info", "process", "contacts"]
# get "/:resource" do |resource|
#   respond_with $nagios.status[resource], @format
# end


# # Process informaton, same as get /process above. With default format
# # only.
# get '/' do
#   respond_with $nagios.status['process'], nil
# end


