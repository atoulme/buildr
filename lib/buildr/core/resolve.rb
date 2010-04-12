# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr

  #
  # A class to read dependencies.yml, and get a flat array of projects and dependencies for a project.
  #
  class Dependencies

    class << self

      # :call-seq:
      #   registered_resolvers => resolvers
      #
      # Returns the list of registered resolvers.
      #
      def registered_resolvers
        @registered_resolvers ||= []
      end

      def dependencies_yml(project)
        unless @deps_yml
          base_dir = find_root(project).base_dir
          @deps_yml = File.exists?(File.join(base_dir, "dependencies.yml")) ? YAML.load(File.read(File.join(base_dir, "dependencies.yml"))) : {}
        end
        @deps_yml
      end
      
      def write(projects)
        base_dir = find_root(projects.first).base_dir
        written_dependencies = YAML.load(File.read(File.join(base_dir, "dependencies.yml"))) if File.exists? File.join(base_dir, "dependencies.yml")
        written_dependencies ||= {}
        written_dependencies.extend SortedHash
        projects.each {|p|
          written_dependencies[p.name] ||= {}
          written_dependencies[p.name].extend SortedHash
          p.send(:_dependencies).resolvers.each_pair do |id, resolver|
            written_dependencies[p.name][id] ||= {}
            written_dependencies[p.name][id].extend SortedHash
            written_dependencies[p.name][id]["artifacts"] ||= resolver.artifacts
            written_dependencies[p.name][id]["projects"] ||= resolver.projects
            written_dependencies[p.name][id]["artifacts"].sort!
            written_dependencies[p.name][id]["projects"].sort!
          end
        }
        Buildr::write File.join(base_dir, "dependencies.yml"), written_dependencies.to_yaml
      end

      private

      def find_root(project)
        project.parent.nil? ? project : find_root(project.parent)
      end

    end

    attr_reader :resolvers

    def initialize(project)
      @project = project
      @resolvers = Dependencies.registered_resolvers.select {|resolver| resolver.apply?(project) }.inject({}) do |map, n|
        res = n.new
        res.send :associate_with, @project
        map.merge({ res.id => res })
      end
      read
    end

    def resolve
      resolvers.values.each {|resolver| resolver.resolve }
    end

    def read
      return if Dependencies.dependencies_yml(@project)[@project.name].nil?
      resolvers.each do |id, resolver|
        _read(resolver, @project, false)
        resolver.artifacts = resolver.artifacts.flatten.compact.uniq
      end
    end

    private

    def _read(resolver, project, add_project = true)
      resolver.projects << project if add_project
      return unless Dependencies.dependencies_yml(@project)[project.name] && Dependencies.dependencies_yml(@project)[project.name][resolver.id]["artifacts"]
      resolver.artifacts |= Dependencies.dependencies_yml(@project)[project.name][resolver.id]["artifacts"]
      Dependencies.dependencies_yml(@project)[project.name][resolver.id]["projects"].each {|p| subp = Buildr::project(p) ; _read(resolver, subp) unless (resolver.projects.include?(subp) || subp == @project)}
    end
  end

  protected
  #
  # Abstract class for Resolvers.
  # Extend it and declare your own resolver by calling:
  # Buildr.registered_resolvers << MyResolvr.new
  #
  class Resolver

    class << self

      # :call-seq:
      #   apply? => Boolean
      #
      # Returns whether this resolving framework
      # applies to the project passed as argument.
      def apply?(project)
        false
      end

    end

    attr_accessor :artifacts, :projects

    attr_reader :id

    def initialize(id)
      @id = id
      @artifacts = []
      @projects = []
    end

    #
    # This method is called to resolve the dependencies of the project.
    # 
    def resolve
      # Default implementation does nothing.
    end

    protected

    attr_reader :project

    private

    def associate_with(project)
      @project = project
    end

  end

  # Copy/pasted from here: http://snippets.dzone.com/posts/show/5811
  # no author information though.
  module SortedHash

    # Replacing the to_yaml function so it'll serialize hashes sorted (by their keys)
    #
    # Original function is in /usr/lib/ruby/1.8/yaml/rubytypes.rb
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.map( taguri, to_yaml_style ) do |map|
          sort.each do |k, v|   # <-- here's my addition (the 'sort')
            map.add( k, v )
          end
        end
      end
    end
  end

  # :nodoc:
  # The hook to add resolving capabilities to
  # the Buildr framework
  module ResolvingExtension
    include Extension

    # :call-seq:
    #   dependencies(:osgi) => resolver
    # Returns the 
    def dependencies(resolver)
      resolver = @dependencies.resolvers[resolver]
      return [] if resolver.nil?
      resolver.artifacts + resolver.projects
    end

    after_define do |project|
      project.instance_eval {
        @dependencies = Dependencies.new(project)           
      }
    end
    
    protected
    
    def _dependencies
      @dependencies
    end
  end

  class Project
    include ResolvingExtension
  end
end