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


require 'buildr/core/project'
require 'buildr/packaging'


module Buildr
  module Eclipse #:nodoc:
    include Extension

    class Eclipse
      
      attr_reader :options
       
      def initialize(project)
        @options = Options.new(project)
      end
    end
     
    class Options
      
      attr_writer :m2_repo_var
      
      def initialize(project)
        @project = project
      end
      
      # The classpath variable used to point at the local maven2 repository.
      # Example:
      #   M2_REPO
      def m2_repo_var
        if @m2_repo_var.nil?
          if project.parent
            @m2_repo_var = project.parent.eclipse.options.m2_repo_var
          else
            @m2_repo_var = 'M2_REPO'
          end
        end
        @m2_repo_var
      end
      
      # :call-seq:
      #   natures=(natures)
      # Sets the Eclipse project natures on the project.
      #
      def natures=(var) 
        @natures = arrayfy(var) 
      end
      
      # :call-seq:
      #   natures() => [n1, n2]
      # Returns the Eclipse project natures on the project.
      # They may be derived from the parent project if no specific natures have been set
      # on the project.
      #
      # An Eclipse project nature is used internally by Eclipse to determine the aspects of a project.
      def natures
        if @natures.nil?
          if project.parent
            @natures = project.parent.eclipse.options.natures
          else
            @natures = []
            @natures << 'ch.epfl.lamp.sdt.core.scalanature' if project.compile.language == :scala
            @natures << "org.eclipse.jdt.core.javanature"
          end
        end
        @natures
      end
      
      # :call-seq:
      #   classpath_containers=(cc)
      # Sets the Eclipse project classpath containers on the project.
      #
      def classpath_containers=(var)
        @classpath_containers = arrayfy(var) 
      end
      
      # :call-seq:
      #   classpath_containers() => [con1, con2]
      # Returns the Eclipse project classpath containers on the project.
      # They may be derived from the parent project if no specific classpath containers have been set
      # on the project.
      # 
      # A classpath container is an Eclipse pre-determined ensemble of dependencies made available to
      # the project classpath.
      def classpath_containers
        if @classpath_containers.nil?
          if project.parent
            @classpath_containers = project.parent.eclipse.options.classpath_containers
          else
            @classpath_containers = []
            @classpath_containers << 'ch.epfl.lamp.sdt.launching.SCALA_CONTAINER' if project.compile.language == :scala
            @classpath_containers << "org.eclipse.jdt.launching.JRE_CONTAINER"
          end
        end
        @classpath_containers
      end
      
      # :call-seq:
      #   builders=(builders)
      # Sets the Eclipse project builders on the project.
      #
      def builders=(var)
        @builders = arrayfy(var) 
      end
      
      # :call-seq:
      #   builders() => [b1, b2]
      # Returns the Eclipse project builders on the project.
      # They may be derived from the parent project if no specific builders have been set
      # on the project.
      # 
      # A builder is an Eclipse background job that parses the source code to produce built artifacts.
      def builders
        if @builders.nil?
          if project.parent
            @builders = project.parent.eclipse.options.builders
          else
            @builders = []
            if project.compile.language == :scala
              @builders << 'ch.epfl.lamp.sdt.core.scalabuilder'
            else 
              @builders << "org.eclipse.jdt.core.javabuilder"
            end
          end
        end
        @builders
      end
        
      private
        
      attr_reader :project
      
      def arrayfy(obj)
        obj.is_a?(Array) ? obj : [obj]
      end
    end
    
    def eclipse
      @eclipse ||= Eclipse.new(self)
      @eclipse
    end
    
    first_time do
      # Global task "eclipse" generates artifacts for all projects.
      desc 'Generate Eclipse artifacts for all projects'
      Project.local_task('eclipse'=>'artifacts') { |name|  "Generating Eclipse project for #{name}" }
    end

    before_define do |project|
      project.recursive_task('eclipse')
    end

    after_define do |project|
      eclipse = project.task('eclipse')

      # Check if project has scala facet
      scala = project.compile.language == :scala

      # Only for projects that we support
      supported_languages = [:java, :scala]
      supported_packaging = %w(jar war rar mar aar)
      if (supported_languages.include?(project.compile.language) ||
          supported_languages.include?(project.test.compile.language) ||
          project.packages.detect { |pkg| supported_packaging.include?(pkg.type.to_s) })
        eclipse.enhance [ file(project.path_to('.classpath')), file(project.path_to('.project')) ]

        # The only thing we need to look for is a change in the Buildfile.
        file(project.path_to('.classpath')=>Buildr.application.buildfile) do |task|
          info "Writing #{task.name}"

          m2repo = Buildr::Repositories.instance.local

          File.open(task.name, 'w') do |file|
            classpathentry = ClasspathEntryWriter.new project, file
            classpathentry.write do
              # Note: Use the test classpath since Eclipse compiles both "main" and "test" classes using the same classpath
              cp = project.test.compile.dependencies.map(&:to_s) - [ project.compile.target.to_s, project.resources.target.to_s ]
              cp = cp.uniq

              # Convert classpath elements into applicable Project objects
              cp.collect! { |path| Buildr.projects.detect { |prj| prj.packages.detect { |pkg| pkg.to_s == path } } || path }

              # project_libs: artifacts created by other projects
              project_libs, others = cp.partition { |path| path.is_a?(Project) }

              # Separate artifacts from Maven2 repository
              m2_libs, others = others.partition { |path| path.to_s.index(m2repo) == 0 }

              # Generated: classpath elements in the project are assumed to be generated
              generated, libs = others.partition { |path| path.to_s.index(project.path_to.to_s) == 0 }

              classpathentry.src project.compile.sources + generated
              classpathentry.src project.resources

              if project.test.compile.target
                classpathentry.src project.test.compile
                classpathentry.src project.test.resources
              end

              # Classpath elements from other projects
              classpathentry.src_projects project_libs

              classpathentry.output project.compile.target if project.compile.target
              classpathentry.lib libs
              classpathentry.var m2_libs, project.eclipse.options.m2_repo_var, m2repo
              
              project.eclipse.options.classpath_containers.each {|container|
                classpathentry.con container
              }
            end
          end
        end

        # The only thing we need to look for is a change in the Buildfile.
        file(project.path_to('.project')=>Buildr.application.buildfile) do |task|
          info "Writing #{task.name}"
          File.open(task.name, 'w') do |file|
            xml = Builder::XmlMarkup.new(:target=>file, :indent=>2)
            xml.projectDescription do
              xml.name project.id
              xml.projects
              xml.buildSpec do
                project.eclipse.options.builders.each {|builder|
                  xml.buildCommand do
                    xml.name builder
                  end
                }
              end
              xml.natures do
                project.eclipse.options.natures.each {|nature|
                  xml.nature nature
                }
              end
            end
          end
        end
      end

    end


    # Writes 'classpathentry' tags in an xml file.
    # It converts tasks to paths.
    # It converts absolute paths to relative paths.
    # It ignores duplicate directories.
    class ClasspathEntryWriter #:nodoc:
      def initialize project, target
        @project = project
        @xml = Builder::XmlMarkup.new(:target=>target, :indent=>2)
        @excludes = [ '**/.svn/', '**/CVS/' ].join('|')
        @paths_written = []
      end
      
      def write &block
        @xml.classpath &block
      end
      
      def con path
        @xml.classpathentry :kind=>'con', :path=>path
      end

      def lib libs
        libs.map(&:to_s).sort.uniq.each do |path|
          @xml.classpathentry :kind=>'lib', :path=>path
        end
      end

      # Write a classpathentry of kind 'src'.
      # Accept an array of absolute paths or a task.
      def src arg
        if [:sources, :target].all? { |message| arg.respond_to?(message) }
          src_from_task arg
        else
          src_from_absolute_paths arg
        end
      end

      # Write a classpathentry of kind 'src' for dependent projects.
      # Accept an array of projects.
      def src_projects project_libs
        project_libs.map(&:id).sort.uniq.each do |project_id|
          @xml.classpathentry :kind=>'src', :combineaccessrules=>'false', :path=>"/#{project_id}"
        end
      end
      
      def output target
        @xml.classpathentry :kind=>'output', :path=>relative(target)
      end

      # Write a classpathentry of kind 'var' (variable) for a library in a local repo.
      # * +libs+ is an array of library paths.
      # * +var_name+ is a variable name as defined in Eclipse (e.g., 'M2_REPO').
      # * +var_value+ is the value of this variable (e.g., '/home/me/.m2').
      # E.g., <tt>var([lib1, lib2], 'M2_REPO', '/home/me/.m2/repo')</tt>
      def var libs, var_name, var_value
        libs.each do |lib_path|
          lib_artifact = file(lib_path)
          source_path = lib_artifact.sources_artifact.to_s
          relative_lib_path = lib_path.sub(var_value, var_name)
          relative_source_path = source_path.sub(var_value, var_name)
          @xml.classpathentry :kind=>'var', :path=>relative_lib_path, :sourcepath=>relative_source_path
        end
      end
              
      private

      # Find a path relative to the project's root directory.
      def relative path
        path or raise "Invalid path '#{path.inspect}'"
        msg = [:to_path, :to_str, :to_s].find { |msg| path.respond_to? msg }
        path = path.__send__(msg)
        Util.relative_path(File.expand_path(path), @project.path_to)
      end

      def src_from_task task
        src_from_absolute_paths task.sources, task.target
      end

      def src_from_absolute_paths absolute_paths, output=nil
        relative_paths = absolute_paths.map { |src| relative(src) }
        relative_paths.sort.uniq.each do |path|
          unless @paths_written.include?(path)
            attributes = { :kind=>'src', :path=>path, :excluding=>@excludes }
            attributes[:output] = relative(output) if output
            @xml.classpathentry attributes
            @paths_written << path
          end
        end
      end
    end

  end
  
end # module Buildr


class Buildr::Project
  include Buildr::Eclipse
end
