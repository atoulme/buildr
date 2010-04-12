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

require File.join(File.dirname(__FILE__), '../spec_helpers')

describe Buildr::Dependencies do
  
  before(:all) {
    class MyResolver < Buildr::Resolver
      def initialize()
        super(:dummy)
      end
      
      def resolve
        artifacts << ["com.example:foo:jar:1.1", "com.example:bar:jar:1.1"]
        artifacts.flatten!
      end
      
      class << self
        def apply?(project)
          project.id.match /foo/
        end
      end
    end
    
    @resolver = MyResolver
    Buildr::Dependencies.registered_resolvers << @resolver
  }
  
  before(:each) {
    Buildr::Dependencies.instance_eval { @deps_yml = nil }
  }
  
  it 'should apply resolvers selectively' do
    foo = define("foo")
    bar = define("bar")
    
    r = @resolver
    
    foo.instance_eval { @dependencies.resolvers.values.first.should be_instance_of r }
    bar.instance_eval { @dependencies.resolvers.values.should == [] }
  end
  
  it 'should read the dependencies.yml file' do
    deps = <<-DEPENDENCIES
foo:
  :dummy:
    artifacts:
    - com.example:art:jar:1.2.3
    - com.example:art2:jar:1.2.3
    projects: []
DEPENDENCIES
    write 'dependencies.yml', deps
    foo = define("foo")
    Buildr::Dependencies.dependencies_yml(foo).should == YAML.load(deps)
  end
  
  it 'should make dependencies available through the dependencies method' do
    deps = <<-DEPENDENCIES
container:foo:
  :dummy:
    artifacts:
    - com.example:art:jar:1.2.3
    - com.example:art2:jar:1.2.3
    projects: 
    - container:foobar
    - container:foobarbar
container:foobar:
  :dummy:
    artifacts:
    - com.example:art3:jar:1.2.4
    projects: 
    - container:foobarbar
container:foobarbar:
  :dummy:
     artifacts:
     - com.example:art4:jar:1.3.2
     projects: []
DEPENDENCIES
    write 'dependencies.yml', deps
    container = define("container") do
      define("foo")
      define("foobar")
      define("foobarbar")
    end
    project("container:foobarbar").dependencies(:dummy).should == ["com.example:art4:jar:1.3.2"]
    project("container:foobar").dependencies(:dummy).should == ["com.example:art3:jar:1.2.4", "com.example:art4:jar:1.3.2", project("container:foobarbar")]
    project("container:foo").dependencies(:dummy).should == ["com.example:art:jar:1.2.3", "com.example:art2:jar:1.2.3", "com.example:art3:jar:1.2.4", "com.example:art4:jar:1.3.2", project("container:foobar"), project("container:foobarbar")]
  end
  
  it 'should present an API for the resolver to resolve dependencies' do
    foo = define('foo')
    foo.instance_eval { @dependencies.resolve }
    foo.dependencies(:dummy).should == ["com.example:foo:jar:1.1", "com.example:bar:jar:1.1"]
  end
  
  it 'should write dependencies to the dependencies.yml file' do
    foo = define('foo')
    foo.send(:_dependencies).resolvers[:dummy].artifacts << "com.example:foo:jar:1.0"
    Dependencies.write([foo])
    YAML.load(File.read('dependencies.yml')).should == {"foo" => {:dummy => {"artifacts" => ["com.example:foo:jar:1.0"], "projects" => []}}}
  end
    
end