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
  class OSGiNature < Buildr::Nature
 
    def initialize()
      super(:osgi)
      eclipse.natures = "org.eclipse.pde.PluginNature" 
      eclipse.builders =  ["org.eclipse.pde.ManifestBuilder", "org.eclipse.pde.SchemaBuilder"]
      eclipse.classpath_containers = "org.eclipse.pde.core.requiredPlugins"
    end
 
    def applies(project)
      ((File.exists? project.path_to("plugin.xml")) || (File.exists? project.path_to("OSGI-INF")))
    end
  end 
 
  NaturesRegistry.instance.add_nature(OSGiNature.new, :java)
end