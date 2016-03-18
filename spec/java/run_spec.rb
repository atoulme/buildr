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


require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helpers'))


describe Run::JavaRunner do

  it 'should fail on error' do
    define 'foo' do
      run.using :java, :main => 'org.example.NonExistentMain' # class doesn't exist
    end
    expect { project('foo').run.invoke }.to raise_error(RuntimeError, /Failed to execute java/)
  end

  it 'should execute main class' do
    write 'src/main/java/org/example/Main.java', <<-JAVA
      package org.example;
      public class Main {
        public static void main(String[] args) {
          System.out.println("Hello, world!");
        }
      }
    JAVA
    define 'foo' do
      run.using :main => 'org.example.Main'
    end
    expect(project('foo').run.prerequisites).to include(task("foo:compile"))
  end

  it 'should accept :main option as an array including parameters for the main class' do
    define 'foo' do
      run.using :java, :main => ['org.example.Main', '-t', 'input.txt']
    end
    expect(Java::Commands).to receive(:java).once do |*args|
      expect(args[0]).to eq(['org.example.Main', '-t', 'input.txt'])
    end
    project('foo').run.invoke
  end

  it 'should accept :java_args and pass them to java' do
    define 'foo' do
      run.using :java, :main => 'foo', :java_args => ['-server']
    end
    expect(Java::Commands).to receive(:java).once do |*args|
      expect(args[0]).to eq('foo')
      expect(args[1][:java_args]).to include('-server')
    end
    project('foo').run.invoke
  end

  it 'should accept :properties and pass them as -Dproperty=value to java' do
    define 'foo' do
      run.using :java, :main => 'foo', :properties => { :foo => 'one', :bar => 'two' }
    end
    expect(Java::Commands).to receive(:java) do |*args|
      expect(args[0]).to eq('foo')
      expect(args[1][:properties][:foo]).to eq('one')
      expect(args[1][:properties][:bar]).to eq('two')
    end
    project('foo').run.invoke
  end

end
